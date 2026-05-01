#!/usr/bin/env python3
"""
Build an HTML email body from Robot Framework's combined output.xml.

Usage (in CI):
    python scripts/build_email_html.py combined/output.xml email_body.html

Optional environment variables (set automatically by GitHub Actions):
    GITHUB_REPOSITORY   e.g. SirAlcan/robotframework
    GITHUB_RUN_ID       e.g. 25207523652
    GITHUB_SERVER_URL   default https://github.com

Output: email-safe HTML using <table> layout + inline styles
(works in Gmail, Outlook desktop/web, Apple Mail, Thunderbird).
"""

from __future__ import annotations

import json
import os
import re
import sys
from collections import Counter
from xml.etree import ElementTree as ET


# ────────────────────────── Palette (email-safe) ──────────────────────────
C = {
    "bg":         "#f5f4ee",
    "card":       "#ffffff",
    "border":     "#e6e4dc",
    "text":       "#1a1a19",
    "muted":      "#6b6b66",
    "ok_bg":      "#eaf3de",
    "ok_text":    "#27500a",
    "ok_dot":     "#3b6d11",
    "warn_dot":   "#ba7517",
    "fail_bg":    "#fcebeb",
    "fail_pill":  "#f7c1c1",
    "fail_text":  "#791f1f",
    "fail_dark":  "#501313",
    "fail_dot":   "#a32d2d",
    "link":       "#185fa5",
}


# ────────────────────────── Parsing helpers ──────────────────────────────
KV_RE      = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$")
BODY_RE    = re.compile(r"(\{.*\})", re.DOTALL)
MESSAGE_RE = re.compile(r'"message"\s*:\s*"([^"]*)"')


def extract_api_message(text: str) -> str:
    if not text:
        return ""
    for body_match in BODY_RE.finditer(text):
        body = body_match.group(1)
        try:
            data = json.loads(body)
            if isinstance(data, dict):
                if data.get("message"):
                    return str(data["message"])
                if data.get("error"):
                    return str(data["error"])
        except Exception:
            m = MESSAGE_RE.search(body)
            if m:
                return m.group(1)
    return ""


def short_message(raw: str, limit: int = 140) -> str:
    """Return the most useful one-line snippet from a Robot failure message."""
    if not raw:
        return ""
    api = extract_api_message(raw)
    if api:
        msg = api
    else:
        # First non-empty line, strip ' | ' separators
        for line in raw.splitlines():
            line = line.strip()
            if line:
                msg = line.split(" | ")[0]
                break
        else:
            msg = raw.strip()
    msg = " ".join(msg.split())  # collapse whitespace
    if len(msg) > limit:
        msg = msg[: limit - 1].rstrip() + "…"
    return msg


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace('"', "&quot;"))


# ────────────────────────── Robot output.xml model ───────────────────────
def collect_leaf_suites(root: ET.Element):
    """Yield (suite_name, [test elements]) for each suite that holds tests."""
    for suite in root.iter("suite"):
        tests = suite.findall("test")
        if tests:
            yield suite.get("name") or "(unnamed)", tests


def test_status(t: ET.Element) -> tuple[str, float, str]:
    st = t.find("status")
    status = st.get("status") if st is not None else ""
    elapsed = float(st.get("elapsed", 0)) if st is not None else 0.0
    raw = (st.text or "").strip() if st is not None else ""
    if not raw and st is not None:
        raw = (st.get("message") or "").strip()
    return status, elapsed, raw


# ────────────────────────── HTML rendering ───────────────────────────────
def kpi(label: str, value: str, bg: str = C["bg"], fg: str = C["text"]) -> str:
    return (
        f'<td width="25%" style="padding:0 6px;">'
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
        f'<tr><td style="background:{bg};border-radius:8px;padding:14px;">'
        f'<div style="font-size:12px;color:{fg};opacity:0.75;margin-bottom:6px;">{label}</div>'
        f'<div style="font-size:22px;font-weight:500;color:{fg};">{value}</div>'
        f"</td></tr></table></td>"
    )


def suite_row(name: str, passed: int, failed: int, skipped: int) -> str:
    if failed > 0:
        dot = C["fail_dot"]
    elif skipped > 0:
        dot = C["warn_dot"]
    else:
        dot = C["ok_dot"]
    total = passed + failed + skipped
    return (
        f'<tr><td style="padding:10px 0;border-bottom:1px solid {C["border"]};">'
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
        f'<td width="20"><div style="width:8px;height:8px;border-radius:50%;background:{dot};"></div></td>'
        f'<td style="font-size:14px;color:{C["text"]};">{esc(name)}</td>'
        f'<td align="right" style="font-size:13px;color:{C["muted"]};">{passed} / {total}</td>'
        f"</tr></table></td></tr>"
    )


def failure_block(suite: str, test_name: str, message: str, count: int = 1) -> str:
    pill = ""
    if count > 1:
        pill = (
            f' <span style="background:{C["fail_pill"]};color:{C["fail_dark"]};'
            f'font-size:11px;padding:2px 6px;border-radius:4px;margin-left:4px;">×{count}</span>'
        )
    return (
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0;">'
        f'<tr><td style="background:{C["fail_bg"]};border-left:3px solid {C["fail_dot"]};'
        f'padding:10px 12px;border-radius:0 8px 8px 0;">'
        f'<div style="font-size:13px;font-weight:500;color:{C["fail_dark"]};margin-bottom:4px;">'
        f'{esc(test_name)}{pill} <span style="color:{C["muted"]};font-weight:400;">· {esc(suite)}</span>'
        f"</div>"
        f'<div style="font-size:12px;color:{C["fail_text"]};font-family:Menlo,Consolas,monospace;'
        f'word-break:break-word;line-height:1.4;">{esc(message)}</div>'
        f"</td></tr></table>"
    )


def group_failures(failures: list[tuple[str, str, str]]) -> list[tuple[str, str, str, int]]:
    """
    Group failures within the same suite that share the same error message.
    Useful for batch-failed cases (e.g. all 7 FNB InternalID share FileNotFoundError).
    Returns list of (suite, displayed_test_name, message, count).
    """
    out = []
    by_suite: dict[str, list[tuple[str, str]]] = {}
    for suite, name, msg in failures:
        by_suite.setdefault(suite, []).append((name, msg))

    for suite, items in by_suite.items():
        # Bucket by short_message signature
        buckets: dict[str, list[str]] = {}
        for name, msg in items:
            key = short_message(msg, limit=60)
            buckets.setdefault(key, []).append(name)

        for key, names in buckets.items():
            full_msg = next(m for n, m in items if n == names[0])
            display_msg = short_message(full_msg, limit=160)
            if len(names) == 1:
                out.append((suite, names[0], display_msg, 1))
            else:
                # Build "TC 01–07" or "TC 01, TC 03, TC 05" depending on contiguity
                tc_nums = []
                for n in names:
                    m = re.match(r"TC\s+0*(\d+)", n)
                    if m:
                        tc_nums.append(int(m.group(1)))
                if tc_nums and len(tc_nums) == max(tc_nums) - min(tc_nums) + 1:
                    label = f"TC {min(tc_nums):02d}–{max(tc_nums):02d}"
                else:
                    label = ", ".join(sorted(names))[:60]
                    if len(", ".join(sorted(names))) > 60:
                        label += "…"
                out.append((suite, label, display_msg, len(names)))
    return out


def render(output_xml_path: str) -> str:
    tree = ET.parse(output_xml_path)
    root = tree.getroot()

    suites = list(collect_leaf_suites(root))

    total_pass = total_fail = total_skip = 0
    suite_summary: list[tuple[str, int, int, int]] = []
    failures: list[tuple[str, str, str]] = []  # (suite, test_name, raw_message)
    total_elapsed_ms = 0

    for suite_name, tests in suites:
        p = f = s = 0
        for t in tests:
            status, elapsed, raw = test_status(t)
            total_elapsed_ms += int(elapsed * 1000)
            if status == "PASS":
                p += 1
            elif status == "FAIL":
                f += 1
                failures.append((suite_name, t.get("name") or "", raw))
            else:
                s += 1
        suite_summary.append((suite_name, p, f, s))
        total_pass += p
        total_fail += f
        total_skip += s

    total = total_pass + total_fail + total_skip
    pass_pct = round(100 * total_pass / total) if total else 0
    duration_s = total_elapsed_ms / 1000.0

    # CI metadata
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    branch = os.environ.get("GITHUB_REF_NAME", "")
    run_url = f"{server}/{repo}/actions/runs/{run_id}" if repo and run_id else ""

    status_label = "All passing" if total_fail == 0 else f"{total_fail} failed"
    status_bg = C["ok_bg"] if total_fail == 0 else C["fail_bg"]
    status_fg = C["ok_text"] if total_fail == 0 else C["fail_text"]

    header_title = f"Run #{run_id}" + (f" · {branch}" if branch else "")
    if not run_id:
        header_title = "Test run summary"

    suite_rows = "".join(suite_row(n, p, f, s) for n, p, f, s in suite_summary)

    grouped = group_failures(failures)
    failure_blocks = "".join(
        failure_block(suite, name, msg, count) for suite, name, msg, count in grouped
    )
    failures_section = ""
    if grouped:
        failures_section = (
            f'<tr><td style="padding:16px 24px 4px;font-size:13px;color:{C["muted"]};'
            f'font-weight:500;border-top:1px solid {C["border"]};">Failures</td></tr>'
            f'<tr><td style="padding:4px 24px 12px;">{failure_blocks}</td></tr>'
        )

    run_link = (
        f'<a href="{run_url}" style="color:{C["link"]};text-decoration:none;font-weight:500;">'
        f"Open run on GitHub →</a>"
    ) if run_url else ""

    duration_str = f"{duration_s:.1f}s" if duration_s < 60 else f"{int(duration_s // 60)}m{int(duration_s % 60):02d}s"

    return f"""\
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>API regression report</title></head>
<body style="margin:0;padding:24px 12px;background:{C['bg']};font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:{C['text']};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td align="center">
<table role="presentation" width="640" cellpadding="0" cellspacing="0" border="0" style="max-width:640px;width:100%;background:{C['card']};border:1px solid {C['border']};border-radius:12px;">

<tr><td style="padding:20px 24px;border-bottom:1px solid {C['border']};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
    <td>
      <div style="font-size:13px;color:{C['muted']};margin-bottom:4px;">API regression report</div>
      <div style="font-size:18px;font-weight:500;">{esc(header_title)}</div>
    </td>
    <td align="right">
      <span style="display:inline-block;background:{status_bg};color:{status_fg};font-size:12px;font-weight:500;padding:6px 12px;border-radius:999px;">{status_label}</span>
    </td>
  </tr></table>
</td></tr>

<tr><td style="padding:20px 24px 8px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
    {kpi("Pass rate", f"{pass_pct}%")}
    {kpi("Total", str(total))}
    {kpi("Passed", str(total_pass), bg=C["ok_bg"], fg=C["ok_text"])}
    {kpi("Failed", str(total_fail), bg=C["fail_bg"], fg=C["fail_dark"])}
  </tr></table>
</td></tr>

<tr><td style="padding:16px 24px 4px;font-size:13px;color:{C['muted']};font-weight:500;">Suites</td></tr>
<tr><td style="padding:0 24px 8px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    {suite_rows}
  </table>
</td></tr>

{failures_section}

<tr><td style="padding:16px 24px;border-top:1px solid {C['border']};background:{C['bg']};border-radius:0 0 12px 12px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
    <td style="font-size:12px;color:{C['muted']};">Duration {duration_str}</td>
    <td align="right" style="font-size:13px;">{run_link}</td>
  </tr></table>
</td></tr>

</table>
</td></tr>
</table>
</body></html>
"""


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: build_email_html.py <combined/output.xml> <email_body.html>", file=sys.stderr)
        return 2
    inp, out = sys.argv[1], sys.argv[2]
    if not os.path.exists(inp):
        # Fallback HTML when no output.xml exists (e.g. all jobs failed before robot ran)
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(
                f"<html><body style='font-family:sans-serif;padding:24px;'>"
                f"<h2>API regression report</h2>"
                f"<p>No combined output.xml produced. All suites probably failed before producing results.</p>"
                f"</body></html>"
            )
        return 0
    html = render(inp)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(html)
    return 0


if __name__ == "__main__":
    sys.exit(main())

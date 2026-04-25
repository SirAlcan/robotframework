"""
Helpers for the einvoice API test suites.

Exposed Robot keywords (snake_case here -> Title Case in .robot):

  HTTP / config
  -------------
  configure_client(base_url, api_key, timeout)
      One-time setup in Suite Setup.

  post_to(path, payload, erp, query) -> dict
      Generic POST. Returns flat dict with status_code, success, message,
      mark, uid, signature, input, summary, raw_text, body_dict.

  post_receipt(payload, erp) -> dict
      Convenience wrapper for /Receipt (used by test_receipt_api.robot).

  Templates / payloads
  --------------------
  load_template(name) -> dict
      Reads templates/<n>.json next to this file and returns a dict.

  deep_merge(base, overrides) -> dict
      Returns a new dict; overrides are deep-merged into a deep copy of base.

  Reporting (shared by both suites)
  ---------------------------------
  format_step_row(...)
  make_row_dict(...)
  render_summary(rows)
  write_results_csv(rows, path)
"""

import copy
import csv
import json
import os
from typing import Any, Dict, List, Optional

import requests


_TEMPLATES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "templates")

_state: Dict[str, Any] = {
    "base_url": None,
    "api_key": None,
    "session": None,
    "timeout": 120,
}


# --------------------------------------------------------------------------- #
# HTTP
# --------------------------------------------------------------------------- #
def configure_client(base_url: str, api_key: str, timeout: int = 120) -> None:
    _state["base_url"] = base_url.rstrip("/")
    _state["api_key"] = api_key
    _state["timeout"] = int(timeout)
    _state["session"] = requests.Session()


def post_to(path: str,
            payload: Dict[str, Any],
            erp: str = "none",
            query: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    """Generic POST to {base_url}{path}. Returns flat result dict."""
    if _state["session"] is None:
        raise RuntimeError("Call 'Configure Client' in Suite Setup first.")

    if not path.startswith("/"):
        path = "/" + path
    while "//" in path:
        path = path.replace("//", "/")
    url = _state["base_url"] + path
    headers = {
        "apikey": _state["api_key"],
        "erp": erp,
        "Content-Type": "application/json",
    }
    try:
        resp = _state["session"].post(
            url, json=payload, headers=headers,
            params=query or None, timeout=_state["timeout"],
        )
        return _parse_response(path, resp, payload)
    except requests.exceptions.Timeout:
        return _network_error_dict(path, payload, "client-side timeout")
    except requests.RequestException as exc:
        return _network_error_dict(path, payload, f"network error: {exc}")


def post_receipt(payload: Dict[str, Any], erp: str = "none") -> Dict[str, Any]:
    """Backwards-compat wrapper used by test_receipt_api.robot."""
    return post_to("/Receipt", payload, erp)


def _network_error_dict(path: str, payload: Dict[str, Any],
                        msg: str) -> Dict[str, Any]:
    return {
        "endpoint": path,
        "status_code": 0,
        "success": None,
        "message": msg,
        "mark": "",
        "uid": "",
        "signature": "",
        "input": "",
        "internal_id": payload.get("internalDocumentId", ""),
        "server_series": payload.get("series", ""),
        "summary": msg,
        "raw_text": "",
        "body_dict": {},
    }


def _parse_response(path: str, response: requests.Response,
                    sent_payload: Dict[str, Any]) -> Dict[str, Any]:
    body: Any = {}
    try:
        body = response.json() if response.text else {}
    except Exception:
        body = {}
    if not isinstance(body, dict):
        body = {"raw": body}

    success = body.get("success")
    message = body.get("message") or ""
    mark = body.get("mark") or ""
    uid = body.get("uid") or body.get("uniqueId") or ""

    signature = (body.get("signature") or body.get("Signature")
                 or _nested(body, ["data", "signature"])
                 or _nested(body, ["result", "signature"]) or "")
    input_field = (body.get("input") or body.get("Input")
                   or _nested(body, ["data", "input"])
                   or _nested(body, ["result", "input"]) or "")

    internal_id_returned = body.get("internalId") or ""
    server_series = body.get("series") or ""

    parts: List[str] = []
    if success is not None:
        parts.append(f"success={success}")
    if message:
        m = message if len(message) <= 120 else message[:117] + "..."
        parts.append(f'msg="{m}"')
    if mark:
        parts.append(f"mark={mark}")
    if uid:
        u = str(uid)
        parts.append(f"uid={u[:24]}{'...' if len(u) > 24 else ''}")
    if signature:
        s = str(signature)
        parts.append(f"sig={s[:18]}{'...' if len(s) > 18 else ''}")

    sent_internal = sent_payload.get("internalDocumentId", "")
    if internal_id_returned and sent_internal and internal_id_returned != sent_internal:
        parts.append(f"server_returned_internalId={internal_id_returned}")

    if not parts:
        if response.text:
            t = response.text.strip().replace("\n", " ")
            parts.append(t[:120] + ("..." if len(t) > 120 else ""))
        else:
            parts.append("(empty body)")

    return {
        "endpoint": path,
        "status_code": response.status_code,
        "success": success,
        "message": message,
        "mark": mark,
        "uid": uid,
        "signature": signature,
        "input": input_field,
        "internal_id": internal_id_returned,
        "server_series": server_series,
        "summary": " | ".join(parts),
        "raw_text": response.text,
        "body_dict": body,
    }


def _nested(d: Any, path: List[str]) -> Any:
    cur = d
    for k in path:
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            return None
    return cur


# --------------------------------------------------------------------------- #
# Templates / payloads
# --------------------------------------------------------------------------- #
def load_template(name: str) -> Dict[str, Any]:
    """Load <name>.json from a few likely locations and return a fresh dict.

    Search order (first match wins):
      0) $EINVOICE_TEMPLATES_DIR/<name>.json   (if env var is set)
      1) the literal `name` if it points to an existing file
      2) <helpers.py dir>/{templates,Data,data,payloads}/<name>.json
      3) <helpers.py dir>/<name>.json
      4) <cwd>/{templates,Data,data,payloads}/<name>.json
      5) <cwd>/<name>.json
      6) one level up from cwd, same subfolders

    This makes the suite work whether the JSON files live in `templates/`,
    `Data/`, the project root, or somewhere reachable from helpers.py.
    Override entirely with the EINVOICE_TEMPLATES_DIR environment variable.
    """
    if name.endswith(".json") and os.path.exists(name):
        with open(name, "r", encoding="utf-8") as f:
            return json.load(f)

    bare = name[:-5] if name.endswith(".json") else name
    helpers_dir = os.path.dirname(os.path.abspath(__file__))
    cwd = os.getcwd()
    parent = os.path.dirname(cwd)
    subfolders = ["templates", "Data", "data", "payloads"]

    candidates: List[str] = []
    env_dir = os.environ.get("EINVOICE_TEMPLATES_DIR")
    if env_dir:
        candidates.append(os.path.join(env_dir, f"{bare}.json"))
    for base in (helpers_dir, cwd, parent):
        for sub in subfolders:
            candidates.append(os.path.join(base, sub, f"{bare}.json"))
        candidates.append(os.path.join(base, f"{bare}.json"))

    for path in candidates:
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)

    tried = "\n   ".join(candidates)
    raise FileNotFoundError(
        f"Template '{bare}.json' not found. Set EINVOICE_TEMPLATES_DIR or "
        f"place the file in one of:\n   {tried}"
    )


def deep_merge(base: Dict[str, Any], overrides: Dict[str, Any]) -> Dict[str, Any]:
    """Deep-merge `overrides` into a deep copy of `base` and return it."""
    out = copy.deepcopy(base)
    _deep_merge_inplace(out, overrides or {})
    return out


def _deep_merge_inplace(dst: Dict[str, Any], src: Dict[str, Any]) -> None:
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            _deep_merge_inplace(dst[k], v)
        else:
            dst[k] = v


# --------------------------------------------------------------------------- #
# Reporting
# --------------------------------------------------------------------------- #
def format_step_row(case_id, step, label, expected, actual, api_msg,
                    endpoint: str = "") -> str:
    expected_i = int(expected)
    actual_i = int(actual)
    verdict = "PASS" if expected_i == actual_i else "FAIL"
    ep = f" [{endpoint}]" if endpoint else ""
    return (
        f"  [{verdict}] {case_id} step {int(step):>2} | {str(label):<60}"
        f"{ep} | exp={expected_i:<3} got={actual_i:<3} | {api_msg}"
    )


def make_row_dict(case_id, step, label, expected, actual, api,
                  endpoint: str = "") -> Dict[str, Any]:
    expected_i = int(expected)
    actual_i = int(actual)
    return {
        "verdict": "PASS" if expected_i == actual_i else "FAIL",
        "case_id": case_id,
        "step": int(step),
        "label": label,
        "endpoint": endpoint or api.get("endpoint", ""),
        "expected": expected_i,
        "actual": actual_i,
        "success": api.get("success"),
        "message": api.get("message", ""),
        "mark": api.get("mark", ""),
        "uid": api.get("uid", ""),
        "signature_short": (str(api.get("signature", "") or "")[:24]),
    }


def render_summary(rows: List[str]) -> str:
    if not rows:
        return "(no test results recorded)"
    total = len(rows)
    passed = sum(1 for r in rows if "[PASS]" in r)
    failed = total - passed
    width = 140
    border = "=" * width
    sub = "-" * width
    lines = [
        "",
        border,
        f"  TEST EXECUTION SUMMARY    total={total}    passed={passed}    failed={failed}",
        border,
    ]
    lines.extend(rows)
    lines.append(sub)
    lines.append(f"  Result: {passed}/{total} steps passed, {failed} failed.")
    if failed:
        lines.append("  Failed steps:")
        for r in rows:
            if "[FAIL]" in r:
                lines.append("   " + r.lstrip())
    lines.append(border)
    return "\n".join(lines)


def write_results_csv(rows: List[Dict[str, Any]], path: str) -> None:
    if not rows:
        return
    fields = [
        "verdict", "case_id", "step", "label", "endpoint",
        "expected", "actual", "success", "message", "mark", "uid",
        "signature_short",
    ]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})

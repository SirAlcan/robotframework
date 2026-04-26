#!/usr/bin/env python3
"""Build the email body from rebot's combined output.xml."""

import os
import xml.etree.ElementTree as ET

OUT_XML = 'combined/output.xml'
EMAIL_FILE = 'email_body.txt'

if not os.path.exists(OUT_XML):
    body = "No combined output.xml produced - all suites failed before reporting."
    with open(EMAIL_FILE, 'w', encoding='utf-8') as f:
        f.write(body)
    raise SystemExit(0)

tree = ET.parse(OUT_XML)
root = tree.getroot()

stats = root.find('.//total/stat')
total_pass = stats.get('pass')
total_fail = stats.get('fail')
total_skip = stats.get('skip')

# Group tests by their parent suite (one section per .robot file).
suites = {}
for suite in root.iter('suite'):
    tests = suite.findall('test')
    if not tests:
        continue
    name = suite.get('name') or '(unnamed)'
    suites[name] = tests

test_blocks = []
for suite_name, tests in suites.items():
    lines = [f"\n  📁 {suite_name}"]
    for test in tests:
        name = test.get('name')
        status = test.find('status')
        result = status.get('status')
        elapsed = float(status.get('elapsed', 0))
        elapsed_str = f"{elapsed:.2f}s"

        if result == 'PASS':
            icon = '✅'
        elif result == 'FAIL':
            icon = '❌'
        else:
            icon = '⏭️'

        message = ''
        if result == 'FAIL':
            msg = (status.get('message') or '').strip()
            if not msg:
                msg = (status.text or 'N/A').strip()
            message = f"\n        Σφάλμα: {msg[:300]}"

        lines.append(f"    {icon} {name} ({elapsed_str}){message}")
    test_blocks.append('\n'.join(lines))

details = '\n'.join(test_blocks) if test_blocks else '  (no tests found)'

repo = os.environ.get('GITHUB_REPOSITORY', '')
run_id = os.environ.get('GITHUB_RUN_ID', '')

body = f"""
╔══════════════════════════════════════╗
     🤖 API Regression Test Report
╚══════════════════════════════════════╝

📊 ΣΥΝΟΛΙΚΑ ΑΠΟΤΕΛΕΣΜΑΤΑ:
✅ Passed : {total_pass}
❌ Failed : {total_fail}
⏭️ Skipped: {total_skip}

📋 ΑΝΑΛΥΤΙΚΑ ΑΝΑ SUITE / TEST CASE:
{details}

🔗 Πλήρες Report (όλα τα artifacts):
https://github.com/{repo}/actions/runs/{run_id}
"""

with open(EMAIL_FILE, 'w', encoding='utf-8') as f:
    f.write(body)
#!/usr/bin/env bash
#
# Discovers which Robot Framework API suites should run in the regression
# workflow. Edit the `suites=(...)` array below to add/remove suites.
#
set -euo pipefail

# --- Edit this list to control which suites run --------------------------- #
suites=(
  "Automation/FNB_case_multiple_11.1.robot"
  "Automation/FNB_InternalID_Cases.robot"
  "Automation/POS_flows.robot"
  "Automation/Receipts_InternalID_Cases.robot"
)
# -------------------------------------------------------------------------- #

# Validate that every listed suite actually exists in the checkout.
missing=0
for f in "${suites[@]}"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: Suite not found in repo: $f" 1>&2
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  exit 1
fi

# Build the JSON matrix and write it to GITHUB_OUTPUT.
json=$(printf '%s\n' "${suites[@]}" \
       | python3 -c 'import json,sys; print(json.dumps({"suite":[l.strip() for l in sys.stdin if l.strip()]}))')

echo "Suites to run:"
printf '  - %s\n' "${suites[@]}"
echo "matrix=$json" >> "$GITHUB_OUTPUT"
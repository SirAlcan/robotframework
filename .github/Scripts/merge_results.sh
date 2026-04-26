#!/usr/bin/env bash
set -euo pipefail

mkdir -p combined

# Collect every per-suite output.xml.
outputs=()
while IFS= read -r line; do
  outputs+=("$line")
done < <(find artifacts -type f -name 'output.xml' | sort)

if [ "${#outputs[@]}" -eq 0 ]; then
  echo "No output.xml files found - all jobs probably failed before producing results."
  exit 0
fi

echo "Merging ${#outputs[@]} suite output(s):"
printf '  - %s\n' "${outputs[@]}"

rebot --name "API Regression Suite" \
      --outputdir combined \
      --output output.xml \
      --log log.html \
      --report report.html \
      "${outputs[@]}"
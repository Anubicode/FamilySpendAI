#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcrun >/dev/null 2>&1; then
  echo "ERROR: xcrun is not installed or not on PATH." >&2
  exit 1
fi

simulator_json="$(xcrun simctl list devices available -j)"

destination="$(
  SIMULATOR_JSON="$simulator_json" python3 - <<'PY'
import json
import os
import re
import sys

raw = os.environ.get("SIMULATOR_JSON", "")
if not raw.strip():
    print("ERROR: xcrun simctl did not return any simulator JSON.", file=sys.stderr)
    sys.exit(1)

try:
    payload = json.loads(raw)
except json.JSONDecodeError as error:
    print(f"ERROR: Failed to parse simulator JSON: {error}", file=sys.stderr)
    sys.exit(1)

devices_by_runtime = payload.get("devices", {})
runtime_pattern = re.compile(r"iOS[- ](\d+)(?:[-.](\d+))?(?:[-.](\d+))?$", re.IGNORECASE)
choices = []

for runtime, devices in devices_by_runtime.items():
    match = runtime_pattern.search(runtime)
    version = tuple(int(part) if part is not None else 0 for part in (match.group(1), match.group(2), match.group(3))) if match else (0, 0, 0)
    for device in devices:
        if not device.get("isAvailable", False):
            continue
        name = device.get("name", "")
        if not name.startswith("iPhone"):
            continue
        udid = device.get("udid")
        if not udid:
            continue
        choices.append((version, name, udid, runtime))

if not choices:
    print("ERROR: No available iPhone simulator was found on this runner.", file=sys.stderr)
    print("Available simulator payload:", file=sys.stderr)
    print(raw, file=sys.stderr)
    sys.exit(1)

choices.sort(key=lambda item: (item[0], item[1]), reverse=True)
version, name, udid, runtime = choices[0]
print(f"Selected simulator: {name} ({runtime}) [{udid}]", file=sys.stderr)
print(f"platform=iOS Simulator,id={udid}")
PY
)"

if [[ -z "$destination" ]]; then
  echo "ERROR: Simulator selection produced an empty xcodebuild destination." >&2
  exit 1
fi

echo "$destination"

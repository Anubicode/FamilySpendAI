#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcrun >/dev/null 2>&1; then
  echo "ERROR: xcrun is not installed or not on PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is not installed or not on PATH." >&2
  exit 1
fi

SIMULATOR_JSON="$(xcrun simctl list -j devices available)"
RUNTIMES_JSON="$(xcrun simctl list -j runtimes available)"
DEVICE_TYPES_JSON="$(xcrun simctl list -j devicetypes)"

parse_result="$(
  SIMULATOR_JSON="$SIMULATOR_JSON" \
  RUNTIMES_JSON="$RUNTIMES_JSON" \
  DEVICE_TYPES_JSON="$DEVICE_TYPES_JSON" \
  python3 - <<'PY'
import json
import os
import re
import sys

def load_env_json(name: str):
    raw = os.environ.get(name, "")
    if not raw.strip():
        print(f"ERROR: {name} was empty.", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(raw)
    except json.JSONDecodeError as error:
        print(f"ERROR: Failed to parse {name}: {error}", file=sys.stderr)
        sys.exit(1)

devices_payload = load_env_json("SIMULATOR_JSON")
runtimes_payload = load_env_json("RUNTIMES_JSON")
device_types_payload = load_env_json("DEVICE_TYPES_JSON")

runtime_pattern = re.compile(r"(?:^|[.])iOS[- ](\d+)(?:[-.](\d+))?(?:[-.](\d+))?$", re.IGNORECASE)

def parse_version(runtime_identifier: str):
    match = runtime_pattern.search(runtime_identifier)
    if not match:
        return (0, 0, 0)
    return tuple(int(part) if part is not None else 0 for part in match.groups())

choices = []
for runtime, devices in devices_payload.get("devices", {}).items():
    version = parse_version(runtime)
    if version == (0, 0, 0):
        continue
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

if choices:
    choices.sort(key=lambda item: (item[0], item[1]), reverse=True)
    version, name, udid, runtime = choices[0]
    print(f"EXISTING|Selected simulator: {name} ({runtime}) [{udid}]")
    print(f"platform=iOS Simulator,id={udid}")
    sys.exit(0)

available_runtimes = []
for runtime in runtimes_payload.get("runtimes", []):
    if not runtime.get("isAvailable", False):
        continue
    identifier = runtime.get("identifier", "")
    version = parse_version(identifier)
    if version == (0, 0, 0):
        continue
    available_runtimes.append((version, runtime.get("name", identifier), identifier))

if not available_runtimes:
    print("ERROR|No available iOS runtime was found on this runner.")
    sys.exit(1)

preferred_iphone_names = [
    "iPhone 16 Pro",
    "iPhone 16",
    "iPhone 15 Pro",
    "iPhone 15",
    "iPhone 14 Pro",
    "iPhone 14"
]

device_types = device_types_payload.get("devicetypes", [])
device_type_lookup = {item.get("name", ""): item.get("identifier", "") for item in device_types}

selected_device_type_name = None
selected_device_type_identifier = None
for preferred_name in preferred_iphone_names:
    identifier = device_type_lookup.get(preferred_name)
    if identifier:
        selected_device_type_name = preferred_name
        selected_device_type_identifier = identifier
        break

if not selected_device_type_identifier:
    iphone_types = [
        (item.get("name", ""), item.get("identifier", ""))
        for item in device_types
        if item.get("name", "").startswith("iPhone")
    ]
    if iphone_types:
        iphone_types.sort(reverse=True)
        selected_device_type_name, selected_device_type_identifier = iphone_types[0]

if not selected_device_type_identifier:
    print("ERROR|No iPhone device type was found on this runner.")
    sys.exit(1)

available_runtimes.sort(key=lambda item: item[0], reverse=True)
runtime_version, runtime_name, runtime_identifier = available_runtimes[0]
simulator_name = "FamilySpendAI CI iPhone"

print(
    "CREATE|"
    f"{simulator_name}|"
    f"{selected_device_type_name}|"
    f"{selected_device_type_identifier}|"
    f"{runtime_name}|"
    f"{runtime_identifier}"
)
PY
)"

IFS='|' read -r mode arg1 arg2 arg3 arg4 arg5 <<<"$parse_result"

case "$mode" in
  EXISTING)
    echo "$arg1" >&2
    echo "$arg2"
    ;;
  CREATE)
    simulator_name="$arg1"
    device_type_name="$arg2"
    device_type_identifier="$arg3"
    runtime_name="$arg4"
    runtime_identifier="$arg5"

    echo "No existing iPhone simulator was available. Creating one." >&2
    echo "Using device type: $device_type_name ($device_type_identifier)" >&2
    echo "Using runtime: $runtime_name ($runtime_identifier)" >&2

    created_udid="$(
      xcrun simctl create "$simulator_name" "$device_type_identifier" "$runtime_identifier"
    )"

    if [[ -z "$created_udid" ]]; then
      echo "ERROR: xcrun simctl create did not return a simulator UDID." >&2
      exit 1
    fi

    echo "Created simulator: $simulator_name [$created_udid]" >&2
    echo "platform=iOS Simulator,id=$created_udid"
    ;;
  ERROR)
    echo "$arg1" >&2
    echo "---- Available runtimes ----" >&2
    xcrun simctl list runtimes available >&2 || true
    echo "---- Available device types ----" >&2
    xcrun simctl list devicetypes >&2 || true
    echo "---- Available devices ----" >&2
    xcrun simctl list devices available >&2 || true
    exit 1
    ;;
  *)
    echo "ERROR: Unexpected selector output: $parse_result" >&2
    exit 1
    ;;
esac

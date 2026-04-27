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

simulator_json="$(xcrun simctl list -j devices available)"
runtimes_json="$(xcrun simctl list -j runtimes available)"
device_types_json="$(xcrun simctl list -j devicetypes)"

selection_json="$(
  SIMULATOR_JSON="$simulator_json" \
  RUNTIMES_JSON="$runtimes_json" \
  DEVICE_TYPES_JSON="$device_types_json" \
  python3 - <<'PY'
import json
import os
import re
import sys

def fail(message: str) -> None:
    print(json.dumps({"status": "error", "message": message}))
    sys.exit(0)

def load_env_json(name: str):
    raw = os.environ.get(name, "")
    if not raw.strip():
        fail(f"{name} was empty.")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as error:
        fail(f"Failed to parse {name}: {error}")

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
    print(json.dumps({
        "status": "existing",
        "message": f"Selected existing simulator: {name} ({runtime}) [{udid}]",
        "destination": f"platform=iOS Simulator,id={udid}"
    }))
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
    fail("No available iOS runtime was found on this runner.")

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
    fail("No iPhone device type was found on this runner.")

available_runtimes.sort(key=lambda item: item[0], reverse=True)
runtime_version, runtime_name, runtime_identifier = available_runtimes[0]
simulator_name = "FamilySpendAI CI iPhone"

print(json.dumps({
    "status": "create",
    "message": (
        f"No existing iPhone simulator was available. Create one using "
        f"{selected_device_type_name} on {runtime_name}."
    ),
    "simulator_name": simulator_name,
    "device_type_name": selected_device_type_name,
    "device_type_identifier": selected_device_type_identifier,
    "runtime_name": runtime_name,
    "runtime_identifier": runtime_identifier
}))
PY
)"

selection_destination="$(
  SELECTION_JSON="$selection_json" python3 - <<'PY'
import json
import os
import sys

payload = json.loads(os.environ["SELECTION_JSON"])
status = payload.get("status")

if status == "existing":
    print(payload["message"], file=sys.stderr)
    print(payload["destination"])
    sys.exit(0)

if status == "create":
    print(payload["message"], file=sys.stderr)
    sys.exit(10)

if status == "error":
    print(f"ERROR: {payload.get('message', 'Unknown selector error.')}", file=sys.stderr)
    sys.exit(20)

print(f"ERROR: Unexpected selector payload: {payload}", file=sys.stderr)
sys.exit(30)
PY
)"
selection_status=$?

if [[ $selection_status -eq 0 ]]; then
  if [[ -z "$selection_destination" ]]; then
    echo "ERROR: Simulator selection produced an empty xcodebuild destination." >&2
    exit 1
  fi
  echo "Using destination: $selection_destination" >&2
  echo "$selection_destination"
  exit 0
fi

if [[ $selection_status -eq 10 ]]; then
  create_values="$(
    SELECTION_JSON="$selection_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["SELECTION_JSON"])
print(payload["simulator_name"])
print(payload["device_type_name"])
print(payload["device_type_identifier"])
print(payload["runtime_name"])
print(payload["runtime_identifier"])
PY
  )"

  mapfile -t create_parts <<<"$create_values"
  simulator_name="${create_parts[0]}"
  device_type_name="${create_parts[1]}"
  device_type_identifier="${create_parts[2]}"
  runtime_name="${create_parts[3]}"
  runtime_identifier="${create_parts[4]}"

  echo "Creating simulator: $simulator_name" >&2
  echo "Device type: $device_type_name ($device_type_identifier)" >&2
  echo "Runtime: $runtime_name ($runtime_identifier)" >&2

  created_udid="$(xcrun simctl create "$simulator_name" "$device_type_identifier" "$runtime_identifier")"
  if [[ -z "$created_udid" ]]; then
    echo "ERROR: xcrun simctl create did not return a simulator UDID." >&2
    exit 1
  fi

  destination="platform=iOS Simulator,id=$created_udid"
  echo "Created simulator UDID: $created_udid" >&2
  echo "Using destination: $destination" >&2
  echo "$destination"
  exit 0
fi

echo "---- Available runtimes ----" >&2
xcrun simctl list runtimes available >&2 || true
echo "---- Available device types ----" >&2
xcrun simctl list devicetypes >&2 || true
echo "---- Available devices ----" >&2
xcrun simctl list devices available >&2 || true
exit 1

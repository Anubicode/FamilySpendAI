#!/usr/bin/env bash
set -euo pipefail

RESULT_BUNDLE="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$RESULT_BUNDLE" || -z "$OUTPUT_DIR" ]]; then
  echo "Usage: $0 <ui-tests.xcresult> <output-dir>"
  exit 0
fi

mkdir -p "$OUTPUT_DIR"

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "Warning: UI test result bundle not found at $RESULT_BUNDLE"
  exit 0
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Exporting UI test attachments from $RESULT_BUNDLE"
if ! xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$TEMP_DIR" | tee "$TEMP_DIR/export.log"; then
  echo "Warning: Failed to export attachments from $RESULT_BUNDLE"
  exit 0
fi

copy_attachment() {
  local attachment_name="$1"
  local required="${2:-true}"
  local match

  match="$(find "$TEMP_DIR" -type f -iname "*${attachment_name}*" | head -n 1 || true)"

  if [[ -z "$match" ]]; then
    if [[ "$required" == "true" ]]; then
      echo "Warning: Screenshot attachment '${attachment_name}' was not found."
    else
      echo "Warning: Optional screenshot attachment '${attachment_name}' was not found."
    fi
    return 0
  fi

  local destination="$OUTPUT_DIR/${attachment_name}.png"
  local extension="${match##*.}"

  if [[ "${extension,,}" == "png" ]]; then
    cp "$match" "$destination"
  else
    sips -s format png "$match" --out "$destination" >/dev/null
  fi

  echo "Saved screenshot: $destination"
}

copy_attachment "scan-screen-sample-buttons" true
copy_attachment "receipt-review-walmart" true
copy_attachment "receipt-review-messy" false
copy_attachment "transactions-after-receipt-save" true

copy_from_export_log() {
  local export_log="$TEMP_DIR/export.log"
  if [[ ! -f "$export_log" ]]; then
    echo "Warning: xcresult export log was not captured."
    return 0
  fi

  python - "$TEMP_DIR" "$OUTPUT_DIR" "$export_log" <<'PY'
import os
import re
import shutil
import sys

temp_dir, output_dir, export_log = sys.argv[1:4]
wanted = {
    "scan-screen-sample-buttons",
    "receipt-review-walmart",
    "receipt-review-messy",
    "transactions-after-receipt-save",
}

pattern = re.compile(r'File:\s*([^,]+), suggested name:\s*"([^"]+)"')
found_any = False

with open(export_log, "r", encoding="utf-8", errors="ignore") as handle:
    for line in handle:
        match = pattern.search(line)
        if not match:
            continue

        filename = match.group(1).strip()
        suggested_name = match.group(2).strip()
        base_name = suggested_name.split("_0_", 1)[0]
        if base_name not in wanted:
            continue

        source = os.path.join(temp_dir, filename)
        destination = os.path.join(output_dir, f"{base_name}.png")
        if not os.path.exists(source) or os.path.exists(destination):
            continue

        shutil.copyfile(source, destination)
        print(f"Saved screenshot from export log: {destination}")
        found_any = True

if not found_any:
    print("Warning: No screenshot files were matched from xcresult export output.")
PY
}

copy_from_export_log

png_count="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
if [[ "$png_count" == "0" ]]; then
  echo "Warning: No UI test screenshots were exported to $OUTPUT_DIR"
else
  echo "Exported $png_count UI test screenshot(s) to $OUTPUT_DIR"
fi

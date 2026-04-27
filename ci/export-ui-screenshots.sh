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
if ! xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$TEMP_DIR"; then
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

png_count="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
if [[ "$png_count" == "0" ]]; then
  echo "Warning: No UI test screenshots were exported to $OUTPUT_DIR"
else
  echo "Exported $png_count UI test screenshot(s) to $OUTPUT_DIR"
fi

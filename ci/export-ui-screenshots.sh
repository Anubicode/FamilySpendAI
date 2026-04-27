#!/usr/bin/env bash
set -euo pipefail

RESULT_BUNDLE="${1:-}"
OUTPUT_DIR="${2:-}"
UI_TEST_LOG="${3:-}"

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

map_by_log_order() {
  local log_path="$1"
  if [[ -z "$log_path" || ! -f "$log_path" ]]; then
    echo "Warning: UI test log not found for fallback screenshot naming."
    return 0
  fi

  mapfile -t attachment_names < <(
    python - "$log_path" <<'PY'
import re
import sys

wanted = {
    "scan-screen-sample-buttons",
    "receipt-review-walmart",
    "receipt-review-messy",
    "transactions-after-receipt-save",
}

seen = []
with open(sys.argv[1], "r", encoding="utf-8", errors="ignore") as handle:
    for line in handle:
        match = re.search(r"Added attachment named '([^']+)'", line)
        if not match:
            continue
        name = match.group(1)
        if name in wanted:
            seen.append(name)

for name in seen:
    print(name)
PY
  )

  if [[ "${#attachment_names[@]}" -eq 0 ]]; then
    echo "Warning: No screenshot attachment names were found in $log_path"
    return 0
  fi

  mapfile -t exported_images < <(
    find "$TEMP_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \) | sort
  )

  if [[ "${#exported_images[@]}" -eq 0 ]]; then
    echo "Warning: No exported image attachments were found in $TEMP_DIR"
    return 0
  fi

  local count="${#attachment_names[@]}"
  if [[ "${#exported_images[@]}" -lt "$count" ]]; then
    count="${#exported_images[@]}"
    echo "Warning: Found fewer exported images than named attachments; exporting the first $count file(s)."
  fi

  local index
  for ((index=0; index<count; index++)); do
    local name="${attachment_names[$index]}"
    local source="${exported_images[$index]}"
    local destination="$OUTPUT_DIR/${name}.png"

    if [[ -f "$destination" ]]; then
      continue
    fi

    local extension="${source##*.}"
    if [[ "${extension,,}" == "png" ]]; then
      cp "$source" "$destination"
    else
      sips -s format png "$source" --out "$destination" >/dev/null
    fi

    echo "Saved screenshot by log order: $destination"
  done
}

map_by_log_order "$UI_TEST_LOG"

png_count="$(find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
if [[ "$png_count" == "0" ]]; then
  echo "Warning: No UI test screenshots were exported to $OUTPUT_DIR"
else
  echo "Exported $png_count UI test screenshot(s) to $OUTPUT_DIR"
fi

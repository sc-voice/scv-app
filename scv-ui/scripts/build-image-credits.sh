#!/bin/bash
# Generate ImageCreditsData.swift from Media.xcassets/*/Contents.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XCASSETS_DIR="$PROJECT_DIR/Sources/scvUI/Resources/Media.xcassets"
OUTPUT_FILE="$PROJECT_DIR/Sources/scvUI/ImageCreditsData.swift"

if [ ! -d "$XCASSETS_DIR" ]; then
  echo "Error: Media.xcassets not found at $XCASSETS_DIR"
  exit 1
fi

# Create output directory if needed
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Start Swift file with header
{
  echo "// Generated from Media.xcassets/*/Contents.json - DO NOT EDIT MANUALLY"
  echo "// Run: scv-ui/scripts/build-image-credits.sh"
  echo ""
  echo "let imageCreditsData: [String: (credit: String, license: String, url: String)] = ["
} > "$OUTPUT_FILE"

# Process each imageset directory
FIRST=true
for imageset_dir in "$XCASSETS_DIR"/*-background.imageset "$XCASSETS_DIR"/palm-leaf.imageset; do
  if [ ! -d "$imageset_dir" ]; then
    continue
  fi

  imageset_name=$(basename "$imageset_dir" .imageset)
  contents_file="$imageset_dir/Contents.json"

  if [ ! -f "$contents_file" ]; then
    continue
  fi

  # Extract credit, license, and url from Contents.json
  credit=$(grep -o '"credit"[[:space:]]*:[[:space:]]*"[^"]*"' "$contents_file" | sed 's/"credit"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
  license=$(grep -o '"license"[[:space:]]*:[[:space:]]*"[^"]*"' "$contents_file" | sed 's/"license"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
  url=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "$contents_file" | sed 's/"url"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

  if [ -z "$credit" ] || [ -z "$license" ] || [ -z "$url" ]; then
    echo "Warning: Missing credit, license, or url in $imageset_name"
    continue
  fi

  # Escape quotes in values
  credit=$(echo "$credit" | sed 's/"/\\"/g')
  license=$(echo "$license" | sed 's/"/\\"/g')
  url=$(echo "$url" | sed 's/"/\\"/g')

  # Add comma before entries (except first)
  if [ "$FIRST" = false ]; then
    echo "," >> "$OUTPUT_FILE"
  fi
  FIRST=false

  # Append to Swift file
  {
    echo -n "  \"$imageset_name\": ("
    echo -n "credit: \"$credit\", "
    echo -n "license: \"$license\", "
    echo -n "url: \"$url\""
    echo -n ")"
  } >> "$OUTPUT_FILE"
done

# Add final newline and close the dictionary
{
  echo ""
  echo "]"
} >> "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE with image credits"

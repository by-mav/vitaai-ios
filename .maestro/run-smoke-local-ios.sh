#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW_DIR="$SCRIPT_DIR/smoke-local"
OUTPUT_DIR="$SCRIPT_DIR/artifacts/smoke-local"

mkdir -p "$OUTPUT_DIR"

if ! command -v maestro >/dev/null 2>&1; then
  echo "ERROR: maestro CLI not found."
  exit 1
fi

if ! xcrun simctl list devices booted | grep -q "Booted"; then
  echo "ERROR: no booted iOS Simulator found."
  exit 1
fi

maestro test "$FLOW_DIR" --test-output-dir "$OUTPUT_DIR"

echo "Smoke-local artifacts saved to: $OUTPUT_DIR"

#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMOKE_DIR="$SCRIPT_DIR/smoke"
OUTPUT_DIR="$SCRIPT_DIR/screenshots"

echo "=== VitaAI Smoke Tests ==="
echo "Smoke dir: $SMOKE_DIR"
echo ""

# Create screenshots output directory
mkdir -p "$OUTPUT_DIR"

# Check maestro is installed
if ! command -v maestro &> /dev/null; then
    echo "ERROR: maestro CLI not found. Install: curl -Ls 'https://get.maestro.mobile.dev' | bash"
    exit 1
fi

# Check for connected device/emulator
if ! adb devices | grep -q "device$"; then
    echo "ERROR: No Android device/emulator connected. Start an emulator or connect a device."
    exit 1
fi

# Check app is installed
if ! adb shell pm list packages | grep -q "com.bymav.vitaai"; then
    echo "WARNING: com.bymav.vitaai not installed on device. Tests will fail at launchApp."
fi

echo "Running all smoke tests..."
echo ""

# Run all smoke tests
maestro test "$SMOKE_DIR/" --output "$OUTPUT_DIR"

echo ""
echo "=== All smoke tests passed ==="
echo "Screenshots saved to: $OUTPUT_DIR"

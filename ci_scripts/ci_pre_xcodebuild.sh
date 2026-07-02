#!/bin/sh
# Xcode Cloud — roda ANTES do xcodebuild
# Instala XcodeGen e gera o .xcodeproj

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Running PT-BR accent gate ==="
python3 "$ROOT/scripts/lint-ptbr-strings.py"

echo "=== Installing XcodeGen ==="
brew install xcodegen

echo "=== Generating Xcode project ==="
xcodegen generate --spec "$ROOT/project.yml"

echo "=== Done ==="

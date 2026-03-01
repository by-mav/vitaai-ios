#!/bin/sh
# Xcode Cloud — roda ANTES do xcodebuild
# Instala XcodeGen e gera o .xcodeproj

set -e

echo "=== Installing XcodeGen ==="
brew install xcodegen

echo "=== Generating Xcode project ==="
xcodegen generate --spec project.yml

echo "=== Done ==="

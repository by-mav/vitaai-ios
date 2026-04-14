#!/bin/bash
# deploy-testflight.sh — One-command TestFlight deploy
# Usage: ./scripts/deploy-testflight.sh [version]
# Example: ./scripts/deploy-testflight.sh 1.2.0
#
# Archive → Export → Upload → Auto-compliance → LIVE in TestFlight
# ~3-5 min on Mac Mini. Zero manual steps.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SCHEME="VitaAI"
PROJECT="VitaAI.xcodeproj"
ARCHIVE_PATH="/tmp/VitaAI.xcarchive"
EXPORT_PATH="/tmp/VitaAI-export"
EXPORT_PLIST="$PROJECT_DIR/scripts/ExportOptions.plist"

# ASC API config
ASC_KEY_ID="4KYZTCFPWX"
ASC_KEY_FILE="$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8"
ASC_ISSUER_ID="6fc1df15-2bd3-4fcf-8251-0a12be7d26d3"
ASC_APP_ID="6759848167"

echo "=============================="
echo "  VitaAI TestFlight Deploy"
echo "=============================="

# 0. Unlock keychain (avoids errSecInternalComponent)
security unlock-keychain -p "" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

# 1. Version + build number
# Fetch highest build number from ASC to avoid conflicts
echo ""
echo "[1/4] Resolving version..."
HIGHEST_ASC_BUILD=$(python3 -c "
import jwt, time, json, urllib.request, ssl
with open('${ASC_KEY_FILE}', 'r') as f: pk = f.read()
token = jwt.encode({'iss': '${ASC_ISSUER_ID}', 'iat': int(time.time()), 'exp': int(time.time()) + 600, 'aud': 'appstoreconnect-v1'}, pk, algorithm='ES256', headers={'kid': '${ASC_KEY_ID}'})
ctx = ssl.create_default_context()
req = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/builds?filter[app]=${ASC_APP_ID}&sort=-version&limit=1', headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'})
resp = urllib.request.urlopen(req, context=ctx)
data = json.loads(resp.read())
print(data['data'][0]['attributes']['version'] if data['data'] else '0')
" 2>/dev/null || echo "0")

LOCAL_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")
MAX_BUILD=$((HIGHEST_ASC_BUILD > LOCAL_BUILD ? HIGHEST_ASC_BUILD : LOCAL_BUILD))
NEW_BUILD=$((MAX_BUILD + 1))
agvtool new-version -all "$NEW_BUILD" > /dev/null 2>&1

# Set marketing version if provided
if [[ -n "${1:-}" ]]; then
    agvtool new-marketing-version "$1" > /dev/null 2>&1
fi
VERSION=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "1.0.0")

echo "       v$VERSION ($NEW_BUILD)"
echo ""

# 2. Clean DerivedData + Archive
echo "[2/4] Archiving... (60-90s)"
rm -rf "$ARCHIVE_PATH"
rm -rf ~/Library/Developer/Xcode/DerivedData/VitaAI-*
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    -allowProvisioningUpdates \
    -quiet 2>&1 | grep -E "error:|ARCHIVE" || true

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "       FAILED - check xcodebuild output"
    exit 1
fi
echo "       Archive OK"
echo ""

# 3. Export + Upload
echo "[3/4] Uploading... (30-60s)"
rm -rf "$EXPORT_PATH"
OUTPUT=$(xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates 2>&1)

if ! echo "$OUTPUT" | grep -q "Upload succeeded"; then
    echo "$OUTPUT" | grep -E "error:|Upload|DUPLICATE" || true
    echo "       FAILED"
    exit 1
fi
echo "       Upload OK"
echo ""

# 4. Auto-resolve export compliance via ASC API (poll up to 2min)
echo "[4/4] Setting compliance... (30-120s)"
python3 << PYEOF
import jwt, time, json, urllib.request, ssl, sys

with open("${ASC_KEY_FILE}", "r") as f:
    pk = f.read()

token = jwt.encode(
    {"iss": "${ASC_ISSUER_ID}", "iat": int(time.time()), "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"},
    pk, algorithm="ES256", headers={"kid": "${ASC_KEY_ID}"}
)

ctx = ssl.create_default_context()
url = "https://api.appstoreconnect.apple.com/v1/builds?filter[app]=${ASC_APP_ID}&filter[version]=${NEW_BUILD}&filter[preReleaseVersion.platform]=IOS"

for i in range(24):
    try:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
        resp = urllib.request.urlopen(req, context=ctx)
        data = json.loads(resp.read())
        if data["data"]:
            build_id = data["data"][0]["id"]
            state = data["data"][0]["attributes"]["processingState"]
            if state == "VALID":
                body = json.dumps({"data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}}).encode()
                req2 = urllib.request.Request(f"https://api.appstoreconnect.apple.com/v1/builds/{build_id}", data=body, method="PATCH",
                    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
                urllib.request.urlopen(req2, context=ctx)
                print("       Compliance OK")
                sys.exit(0)
        print(f"       Processing... ({(i+1)*5}s)", flush=True)
    except Exception as e:
        print(f"       Waiting... ({(i+1)*5}s)", flush=True)
    time.sleep(5)

print("       Compliance pending - approve manually in ASC")
PYEOF

echo ""
echo "=============================="
echo "  DONE: v$VERSION ($NEW_BUILD)"
echo "  Open TestFlight on iPhone"
echo "=============================="

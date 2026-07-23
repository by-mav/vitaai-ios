#!/bin/bash
# deploy-testflight.sh — One-command TestFlight deploy (revamped 2026-04-18)
# Usage: ./scripts/deploy-testflight.sh [marketing_version]
# Example: ./scripts/deploy-testflight.sh 1.2.0
#
# Fixes encoded from incidents 2026-04-18_testflight-build-number-creep.md and
# today's HealthKit purpose-string rejection:
#
#   1. PRE-FLIGHT validation: check Info.plist for every purpose-string Apple
#      requires for our current SDKs (Sentry, HealthKit, etc). If any
#      is missing, FAIL BEFORE touching build number — no wasted uploads.
#
#   2. Build number: query ASC API for the last uploaded build and set
#      CURRENT_PROJECT_VERSION to (asc_max + 1). No local-vs-ASC drift; no
#      creep from aborted deploys. Called ONLY after pre-flight passes.
#
#   3. CANONICAL housekeeping keeps one release DerivedData, preserves its SPM
#      SourcePackages cache, and removes only regenerable Build/Index/Logs data.
#      This avoids both disk exhaustion and slow binary-target redownloads.
#
#   4. Rollback on failure: if archive OR export fails, restore the
#      pre-deploy build number so we don't burn slots.
#
#   5. Final output reports the actual uploaded build number + links to the
#      TestFlight processing page.
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SCHEME="VitaAI"
PROJECT="VitaAI.xcodeproj"
WORKSPACE="VitaAI.xcworkspace"
INFO_PLIST="VitaAI/Info.plist"
ARCHIVE_PATH="/tmp/VitaAI.xcarchive"
EXPORT_PATH="/tmp/VitaAI-export"
EXPORT_PLIST="$PROJECT_DIR/scripts/ExportOptions.plist"
LOCAL_EXPORT_PLIST="/tmp/VitaAI-ExportOptions-local.plist"
IPA_VALIDATION_PATH="/tmp/VitaAI-ipa-validation"

# ASC API config
ASC_KEY_ID="4KYZTCFPWX"
ASC_KEY_FILE="$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8"
ASC_ISSUER_ID="6fc1df15-2bd3-4fcf-8251-0a12be7d26d3"
ASC_APP_ID="6759848167"

# One canonical cache for release builds. SourcePackages is intentionally kept:
# Sentry/GLTFKit2 binary targets are large and re-downloading them is both slow
# and likely to fail when the Mac is close to full.
DERIVED_DATA_PATH="${VITA_DERIVED_DATA_PATH:-$PROJECT_DIR/build/DerivedData}"
LEGACY_DERIVED_DATA_PATH="$HOME/vita-dd"
MIN_RELEASE_FREE_GB="${VITA_MIN_RELEASE_FREE_GB:-6}"
ARCHIVE_LOG="${VITA_ARCHIVE_LOG:-/tmp/VitaAI-archive.log}"

safe_delete_tree() {
  local target="$1"
  case "$target" in
    "$PROJECT_DIR/build/"*|"$HOME/vita-dd/"*) ;;
    *)
      echo "       FAIL — refused to clean unexpected path: $target"
      exit 1
      ;;
  esac
  if [[ -e "$target" ]]; then
    find "$target" -depth -delete
  fi
}

prune_derived_data_keep_packages() {
  local root="$1"
  [[ -d "$root" ]] || return 0
  for child in \
    Build \
    Index.noindex \
    Logs \
    ModuleCache.noindex \
    CompilationCache.noindex \
    SDKStatCaches.noindex \
    TestResults
  do
    safe_delete_tree "$root/$child"
  done
}

purge_legacy_derived_data() {
  if [[ "$LEGACY_DERIVED_DATA_PATH" == "$DERIVED_DATA_PATH" || ! -d "$LEGACY_DERIVED_DATA_PATH" ]]; then
    return 0
  fi
  if [[ ! -d "$DERIVED_DATA_PATH/SourcePackages" && -d "$LEGACY_DERIVED_DATA_PATH/SourcePackages" ]]; then
    mv "$LEGACY_DERIVED_DATA_PATH/SourcePackages" "$DERIVED_DATA_PATH/SourcePackages"
    echo "       migrated legacy SourcePackages into the canonical cache"
  fi
  while IFS= read -r legacy_entry; do
    safe_delete_tree "$legacy_entry"
  done < <(find "$LEGACY_DERIVED_DATA_PATH" -mindepth 1 -maxdepth 1 -print)
  rmdir "$LEGACY_DERIVED_DATA_PATH" 2>/dev/null || true
}

echo "[space] Canonical release housekeeping..."
SPACE_BEFORE_KB=$(df -k /System/Volumes/Data | awk 'NR == 2 { print $4 }')

# Remove task-specific DerivedData duplicates left by prior agents. These paths
# are ignored build products; the canonical SourcePackages cache remains below.
if [[ -d "$PROJECT_DIR/build" ]]; then
  while IFS= read -r stale_cache; do
    safe_delete_tree "$stale_cache"
  done < <(find "$PROJECT_DIR/build" -mindepth 1 -maxdepth 1 -type d -name 'codex-*' -print)
fi

mkdir -p "$DERIVED_DATA_PATH"

# The old release path duplicated the same multi-gigabyte SPM cache. Migrate it
# only when the canonical cache does not exist, then remove the legacy tree so
# every future release converges on one cache instead of growing two forever.
purge_legacy_derived_data

prune_derived_data_keep_packages "$DERIVED_DATA_PATH"
find "$ARCHIVE_PATH" -depth -delete 2>/dev/null || true
find "$EXPORT_PATH" -depth -delete 2>/dev/null || true
find "$IPA_VALIDATION_PATH" -depth -delete 2>/dev/null || true
find "$LOCAL_EXPORT_PLIST" -delete 2>/dev/null || true
mkdir -p "$DERIVED_DATA_PATH/SourcePackages"

SPACE_AFTER_KB=$(df -k /System/Volumes/Data | awk 'NR == 2 { print $4 }')
SPACE_FREED_KB=$((SPACE_AFTER_KB - SPACE_BEFORE_KB))
REQUIRED_KB=$((MIN_RELEASE_FREE_GB * 1024 * 1024))
printf "       freed %.1f GB; %.1f GB available\n" \
  "$(awk -v kb="$SPACE_FREED_KB" 'BEGIN { print kb / 1024 / 1024 }')" \
  "$(awk -v kb="$SPACE_AFTER_KB" 'BEGIN { print kb / 1024 / 1024 }')"
if (( SPACE_AFTER_KB < REQUIRED_KB )); then
  echo "       FAIL — release needs at least ${MIN_RELEASE_FREE_GB} GB free after safe cleanup"
  echo "       SourcePackages was preserved; inspect non-build storage before retrying."
  exit 1
fi
echo "       Canonical cache: $DERIVED_DATA_PATH (SourcePackages preserved)"
echo ""

# XcodeGen rewrites VitaAI.xcodeproj and removes CocoaPods integration. Always
# restore the workspace/project wiring before archive so device-only modules
# such as MLKitDigitalInkRecognition are visible to the VitaAI target.
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

echo "[deps] Synchronizing CocoaPods workspace..."
if ! command -v pod >/dev/null 2>&1; then
  echo "       FAIL — CocoaPods is not installed"
  exit 1
fi
pod install --deployment --no-ansi
echo "       CocoaPods workspace synchronized"
echo ""

echo "=============================="
echo "  VitaAI TestFlight Deploy"
echo "=============================="
echo ""
echo "Pre-flight validation (Info.plist purpose strings, build compile) is"
echo "enforced by .git/hooks/pre-commit. Any code that gets this far ALREADY"
echo "passed those gates. If deploy fails, it's a packaging/signing issue,"
echo "not missing keys."
echo ""

# 0. Unlock keychain (avoids errSecInternalComponent)
security unlock-keychain -p "" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

# -------------------------------------------------------------------------
# PRE-FLIGHT GATES — gotchas que bloqueiam silenciosamente no TestFlight
# -------------------------------------------------------------------------
# Cada gate é um "NUNCA MAIS" incident-encoded. Adicione aqui TODO bloqueio
# novo que levou manual intervention no App Store Connect.
#
# Current gates:
#  G1. ITSAppUsesNonExemptEncryption=false  → se ausente, Apple retém build
#      aguardando resposta manual de "export compliance" no ASC.
#      Incident: 2026-04-24 build #91 ficou invisível no TestFlight por 30min
#      até PATCH manual via API.
#  G2. Purpose strings: Health, Microphone, Speech. Se faltar, upload rejeita.
#  G3. CFBundleShortVersionString set. Sem, cai pra 1.0 silencioso.
# -------------------------------------------------------------------------
echo ""
echo "[0/4] PRE-FLIGHT gates..."

python3 "$PROJECT_DIR/scripts/lint-ptbr-strings.py"
echo "       ✅ G0: PT-BR accents in visible strings"

# G1 — Export compliance
if ! /usr/libexec/PlistBuddy -c "Print :ITSAppUsesNonExemptEncryption" "$INFO_PLIST" 2>/dev/null | grep -qE "^(false|0)$"; then
  echo "       ❌ G1: ITSAppUsesNonExemptEncryption missing or true in $INFO_PLIST"
  echo "       → Apple irá RETER o build em TestFlight aguardando export compliance manual."
  echo "       Adicione ao Info.plist (dentro do <dict> raiz):"
  echo "         <key>ITSAppUsesNonExemptEncryption</key>"
  echo "         <false/>"
  echo "       Abortando deploy."
  exit 1
fi
echo "       ✅ G1: export compliance (ITSAppUsesNonExemptEncryption=false)"

# G2 — Purpose strings (pre-commit já checa, mas paranoia)
for key in NSMicrophoneUsageDescription NSSpeechRecognitionUsageDescription; do
  if ! /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" >/dev/null 2>&1; then
    echo "       ❌ G2: purpose string $key missing"
    exit 1
  fi
done
echo "       ✅ G2: purpose strings (Mic, Speech, Health)"

# G3 — Version string
if ! /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" >/dev/null 2>&1; then
  echo "       ❌ G3: CFBundleShortVersionString missing"
  exit 1
fi
echo "       ✅ G3: version string set"
echo "       All pre-flight gates passed."

# -------------------------------------------------------------------------
# STEP 1: Build number — ASC-as-source-of-truth, rollback on failure
# -------------------------------------------------------------------------
echo ""
echo "[1/4] Resolving build number from ASC..."
ORIGINAL_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")

HIGHEST_ASC_BUILD=$(python3 - <<PYEOF 2>/dev/null || echo "0"
import jwt, time, json, urllib.request, ssl
with open("${ASC_KEY_FILE}", "r") as f: pk = f.read()
token = jwt.encode({"iss": "${ASC_ISSUER_ID}", "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"}, pk, algorithm="ES256", headers={"kid": "${ASC_KEY_ID}"})
ctx = ssl.create_default_context()
url = "https://api.appstoreconnect.apple.com/v1/builds?filter%5Bapp%5D=${ASC_APP_ID}&sort=-uploadedDate&limit=10"
req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
resp = urllib.request.urlopen(req, context=ctx)
data = json.loads(resp.read())
nums = [int(b["attributes"]["version"]) for b in data.get("data", []) if (b.get("attributes") or {}).get("version", "").isdigit()]
print(max(nums) if nums else 0)
PYEOF
)

MAX_BUILD=$((HIGHEST_ASC_BUILD > ORIGINAL_BUILD ? HIGHEST_ASC_BUILD : ORIGINAL_BUILD))
NEW_BUILD=$((MAX_BUILD + 1))
agvtool new-version -all "$NEW_BUILD" > /dev/null 2>&1

# Rollback on failure — restore original build number so aborted deploys don't
# permanently burn slots and create gaps in git history.
rollback_build() {
    if [[ "${DEPLOY_SUCCESS:-0}" != "1" ]]; then
        echo ""
        echo "       Rolling back build number $NEW_BUILD -> $ORIGINAL_BUILD (deploy aborted)"
        agvtool new-version -all "$ORIGINAL_BUILD" > /dev/null 2>&1 || true
    fi
}
trap rollback_build EXIT

if [[ -n "${1:-}" ]]; then
    agvtool new-marketing-version "$1" > /dev/null 2>&1
fi
VERSION=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "1.0.0")

echo "       ASC highest: $HIGHEST_ASC_BUILD  |  local: $ORIGINAL_BUILD  ->  new: $NEW_BUILD"
echo "       v$VERSION ($NEW_BUILD)"

# -------------------------------------------------------------------------
# STEP 2: Archive (no DerivedData wipe — xcodebuild manages cache)
# -------------------------------------------------------------------------
echo ""
echo "[2/4] Archiving... (60-90s)"
find "$ARCHIVE_PATH" -delete 2>/dev/null || true
find "$ARCHIVE_LOG" -delete 2>/dev/null || true
set +e
xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    -allowProvisioningUpdates \
    > "$ARCHIVE_LOG" 2>&1
ARCHIVE_RC=$?
set -e

if [[ $ARCHIVE_RC -ne 0 || ! -d "$ARCHIVE_PATH" ]]; then
    echo "       FAIL — archive exit=$ARCHIVE_RC"
    echo "       Relevant diagnostics:"
    grep -nE '(^|: )(error:|fatal error:)|No space left|Command SwiftCompile failed|Failed frontend command' "$ARCHIVE_LOG" | tail -60 || true
    echo "       Full archive log: $ARCHIVE_LOG"
    exit 1
fi
tail -10 "$ARCHIVE_LOG" || true
echo "       Archive OK"

# -------------------------------------------------------------------------
# STEP 3: Export a local IPA, validate it, then upload via altool
# -------------------------------------------------------------------------
echo ""
echo "[3/4] Exporting and validating IPA..."
find "$EXPORT_PATH" -delete 2>/dev/null || true
find "$IPA_VALIDATION_PATH" -delete 2>/dev/null || true

# Xcode 26 may silently choose the next ASC build number during export. Force
# the signed IPA to keep the exact version already archived and selected above.
cp "$EXPORT_PLIST" "$LOCAL_EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Set :destination export" "$LOCAL_EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Delete :manageAppVersionAndBuildNumber" "$LOCAL_EXPORT_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :manageAppVersionAndBuildNumber bool false" "$LOCAL_EXPORT_PLIST"

set +e
OUTPUT=$(xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$LOCAL_EXPORT_PLIST" \
    -exportPath "$EXPORT_PATH" \
    -authenticationKeyPath "$ASC_KEY_FILE" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    -allowProvisioningUpdates 2>&1)
EXPORT_RC=$?
set -e

if [[ $EXPORT_RC -ne 0 ]]; then
    echo "       FAIL — export exit=$EXPORT_RC"
    echo "$OUTPUT" | grep -iE "error:|failed|missing.*purpose|code = 90" | head -5 || true
    echo "       Tip: if Apple complains of a missing purpose string, add the key to"
    echo "       VitaAI/Info.plist + project.yml + .git/hooks/pre-commit REQUIRED_PURPOSE_KEYS."
    exit 1
fi

IPA_PATH=$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit)
if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
    echo "       FAIL — export succeeded but no IPA was produced in $EXPORT_PATH"
    exit 1
fi

ditto -x -k "$IPA_PATH" "$IPA_VALIDATION_PATH"
IPA_APP="$IPA_VALIDATION_PATH/Payload/VitaAI.app"
IPA_INFO_PLIST="$IPA_APP/Info.plist"
IPA_BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$IPA_INFO_PLIST")
IPA_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$IPA_INFO_PLIST")
IPA_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$IPA_INFO_PLIST")

if [[ "$IPA_BUNDLE" != "com.bymav.vitaai" || "$IPA_VERSION" != "$VERSION" || "$IPA_BUILD" != "$NEW_BUILD" ]]; then
    echo "       FAIL — IPA metadata mismatch"
    echo "       expected com.bymav.vitaai v$VERSION ($NEW_BUILD)"
    echo "       actual   $IPA_BUNDLE v$IPA_VERSION ($IPA_BUILD)"
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$IPA_APP"
IPA_BYTES=$(stat -f '%z' "$IPA_PATH")
IPA_SHA256=$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')
find "$IPA_VALIDATION_PATH" -depth -delete
echo "       IPA OK — $IPA_BUNDLE v$IPA_VERSION ($IPA_BUILD)"
echo "       IPA: $IPA_PATH ($IPA_BYTES bytes, sha256=$IPA_SHA256)"

echo "       Uploading validated IPA to ASC..."
set +e
UPLOAD_OUTPUT=$(xcrun altool \
    --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID" 2>&1)
UPLOAD_RC=$?
set -e
if [[ $UPLOAD_RC -ne 0 ]]; then
    echo "       FAIL — altool upload exit=$UPLOAD_RC"
    echo "$UPLOAD_OUTPUT" | tail -20
    exit 1
fi
echo "       Upload succeeded"

# Mark deploy successful — prevents rollback trap from restoring build number
DEPLOY_SUCCESS=1

# -------------------------------------------------------------------------
# STEP 4: Auto-resolve export compliance + report final state
# -------------------------------------------------------------------------
echo ""
echo "[4/4] Waiting for ASC to process build $NEW_BUILD (up to 10min)..."
python3 - <<PYEOF
import jwt, time, json, urllib.request, ssl, sys
with open("${ASC_KEY_FILE}", "r") as f: pk = f.read()

def fresh_token():
    """Recria JWT a cada chamada — evita 401 quando polling passa de 20min cumulative."""
    return jwt.encode(
        {"iss": "${ASC_ISSUER_ID}", "iat": int(time.time()), "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
        pk, algorithm="ES256", headers={"kid": "${ASC_KEY_ID}"}
    )

def patch_compliance(build_id):
    """Seta usesNonExemptEncryption=false. Idempotente."""
    body = json.dumps({"data": {"type": "builds", "id": build_id, "attributes": {"usesNonExemptEncryption": False}}}).encode()
    req = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com/v1/builds/{build_id}",
        data=body, method="PATCH",
        headers={"Authorization": f"Bearer {fresh_token()}", "Content-Type": "application/json"}
    )
    urllib.request.urlopen(req, context=ctx)

ctx = ssl.create_default_context()
url = "https://api.appstoreconnect.apple.com/v1/builds?filter%5Bapp%5D=${ASC_APP_ID}&filter%5Bversion%5D=${NEW_BUILD}&filter%5BpreReleaseVersion.platform%5D=IOS"

# 10min total — Apple às vezes demora 5+ min mesmo com VALID
for i in range(120):
    try:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {fresh_token()}", "Content-Type": "application/json"})
        resp = urllib.request.urlopen(req, context=ctx)
        data = json.loads(resp.read())
        if data.get("data"):
            b = data["data"][0]
            state = b["attributes"]["processingState"]
            if state == "VALID":
                # O ASC responde 409 ao tentar regravar compliance já resolvido.
                # Evite o PATCH quando o próprio GET confirma false; assim o
                # polling termina imediatamente e continua idempotente.
                compliance = b["attributes"].get("usesNonExemptEncryption")
                if compliance is not False:
                    patch_compliance(b["id"])
                detail = "already set" if compliance is False else "set automatically"
                print(f"       ✅ VALID — export compliance {detail}, build #{b['attributes']['version']} LIVE in TestFlight")
                sys.exit(0)
            elif state in ("FAILED", "INVALID"):
                print(f"       ❌ ASC rejected build: state={state}")
                sys.exit(1)
            if i % 6 == 0:  # log a cada 30s pra não spammar
                print(f"       ASC state: {state} ({(i+1)*5}s elapsed)", flush=True)
        else:
            if i % 6 == 0:
                print(f"       Build not indexed yet ({(i+1)*5}s)", flush=True)
    except Exception as e:
        if i % 6 == 0:
            print(f"       Poll error ({(i+1)*5}s): {str(e)[:80]}", flush=True)
    time.sleep(5)

# Fallback: se polling timeouts mas build subiu, tentar PATCH blind via filter
print("       ⚠️  Polling timeout 10min. Tentando PATCH blind pela API...")
try:
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {fresh_token()}", "Content-Type": "application/json"})
    resp = urllib.request.urlopen(req, context=ctx)
    data = json.loads(resp.read())
    if data.get("data"):
        b = data["data"][0]
        patch_compliance(b["id"])
        print(f"       ✅ Blind PATCH ok — build {b['attributes']['version']} state={b['attributes']['processingState']}")
    else:
        print(f"       ❌ Build #${NEW_BUILD} não apareceu na API. Deploy real subiu ok? Verificar manualmente no ASC.")
except Exception as e:
    print(f"       ❌ Blind PATCH falhou: {e}")
    print(f"       → Setar compliance manual no https://appstoreconnect.apple.com/apps/${ASC_APP_ID}/testflight/ios")
PYEOF

# A misconfigured or older concurrent tool can recreate ~/vita-dd while the
# release is running. Reclaim it again after Xcode/altool have exited. Never
# remove it while another real xcodebuild process is still active.
if pgrep -x xcodebuild >/dev/null 2>&1; then
  echo "       WARN: legacy cache cleanup deferred because another xcodebuild is active"
else
  purge_legacy_derived_data
fi

echo ""
echo "=============================="
echo "  DONE: v$VERSION ($NEW_BUILD)"
echo "  - TestFlight: open on iPhone and wait for push"
echo "  - ASC: https://appstoreconnect.apple.com/apps/${ASC_APP_ID}/testflight/ios"
echo "=============================="

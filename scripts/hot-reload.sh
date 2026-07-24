#!/usr/bin/env bash
set -euo pipefail

# Hot reload do Vita via InjectionNext — portado do Pixio (2026-07-24).
# Build 1× pela CLI (Xcode fechado) → daí salvar .swift injeta ao vivo (body/função).
# Mudança ESTRUTURAL (nova @State/stored prop, novo tipo, assinatura) → build normal.

ROOT="$(git rev-parse --show-toplevel)"
WORKSPACE="$ROOT/VitaAI.xcworkspace"
PROJECT="$ROOT/VitaAI.xcodeproj"
SCHEME="VitaAI"
BUNDLE_ID="com.bymav.vitaai"
INJECTION_APP="/Applications/InjectionNext.app"
TOOLCHAIN_PROXY="$HOME/.cache/vita-injection-toolchain/usr"
DERIVED_DATA="${VITA_HOT_RELOAD_DERIVED_DATA:-$HOME/.codex/derived-data/vita-hot-reload}"
LOCK_TOOL="/Users/mav/agent-brain/infra/scripts/bymav-lock.sh"
SIMULATOR_UDID="${VITA_SIMULATOR_UDID:-}"

if [ ! -d "$INJECTION_APP" ]; then
  echo "InjectionNext não está instalado em /Applications."; exit 1
fi

defaults write com.johnholdsworth.InjectionNext projectPath -string "$PROJECT"
defaults write com.johnholdsworth.InjectionNext autoLaunchXcode -bool false
defaults write com.johnholdsworth.InjectionNext autoRestartXcode -bool false
defaults write com.johnholdsworth.InjectionNext mcpServer -bool true

# Toolchain proxy: intercepta swift-frontend e alimenta os comandos ao InjectionNext.
mkdir -p "$TOOLCHAIN_PROXY/bin"
ln -sfn /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib \
  "$TOOLCHAIN_PROXY/lib"
ln -sfn "$ROOT/scripts/injection-swift-frontend.sh" \
  "$TOOLCHAIN_PROXY/bin/swift-frontend"
ln -sfn "$(xcrun --find swift-frontend)" \
  "$TOOLCHAIN_PROXY/bin/swift-frontend.save"

echo "Iniciando InjectionNext em segundo plano para observar $ROOT"
open -gj -a InjectionNext

for _ in {1..20}; do
  [ -S /tmp/InjectionNext-control.sock ] && break
  sleep 0.25
done

# ADITIVO (multi-projeto, Rafael 2026-07-24): NÃO faz stop_watching — apenas
# ADICIONA o watch do Vita. Se o Pixio já estava sendo observado, continua.
if [ -S /tmp/InjectionNext-control.sock ]; then
  printf '%s\n' "{\"action\":\"watch_project\",\"path\":\"$ROOT\"}" \
    | nc -U /tmp/InjectionNext-control.sock >/dev/null
fi

# Resolve o sim do Vita POR NOME (há vários sims bootados → não pegar "o primeiro").
if [ -z "$SIMULATOR_UDID" ]; then
  SIMULATOR_UDID="$(xcrun simctl list devices -j | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin).get("devices", {})
for devs in d.values():
    for dev in devs:
        if dev.get("name") == "Vita-IOS26" and dev.get("state") == "Booted":
            print(dev["udid"]); raise SystemExit
')"
fi
if [ -z "$SIMULATOR_UDID" ]; then
  echo "Sim Vita-IOS26 não está bootado. Inicie-o e rode de novo."; exit 1
fi

# Cliente conectado faz o InjectionNext preservar o cache antigo → desconecta antes.
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true

build_command=(
  env
  INJECTION_PROJECT_ROOT="$ROOT"
  xcodebuild
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -configuration Debug
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID,arch=arm64"
  -derivedDataPath "$DERIVED_DATA"
  -skipPackageUpdates
  ARCHS=arm64
  ONLY_ACTIVE_ARCH=YES
  COMPILER_INDEX_STORE_ENABLE=NO
  # -interposable: sem isto o InjectionNext conecta mas NÃO replaça os símbolos
  # ("No symbols replaced"). $(inherited) preserva os OTHER_LDFLAGS dos Pods.
  'OTHER_LDFLAGS=$(inherited) -Xlinker -interposable'
  build
  -quiet
)

echo "Compilando pela CLI (Xcode fechado)..."
if [ -x "$LOCK_TOOL" ]; then
  "$LOCK_TOOL" run --scope vita:ios:hot-reload --app vita --repo "$ROOT" -- "${build_command[@]}"
else
  "${build_command[@]}"
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/VitaAI.app"
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
SIMCTL_CHILD_INJECTION_PROJECT_ROOT="$ROOT" \
  SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$INJECTION_APP/Contents/Resources/iOSInjection.bundle/iOSInjection" \
  xcrun simctl launch --terminate-running-process "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null

echo ""
echo "Pronto: Vita compilado, instalado e aberto pela CLI."
echo "  • Mantenha InjectionNext aberto (ícone laranja = app conectado)."
echo "  • Salve um .swift → a implementação (body/função) injeta sem relaunch."
echo "  • Mudança estrutural (nova @State/stored prop, novo tipo) → build normal."

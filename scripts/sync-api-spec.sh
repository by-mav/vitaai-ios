#!/bin/bash
# sync-api-spec.sh — Syncs OpenAPI spec from GitHub and regenerates Swift models
# Usage: ./scripts/sync-api-spec.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GENERATED_API="$REPO_ROOT/Generated/API"
GENERATED_MODELS="$REPO_ROOT/VitaAI/Generated/Models"
GENERATED_INFRA="$REPO_ROOT/VitaAI/Generated/Infrastructure"

# O openapi.yaml canonico VIVE NO REPO WEB (vitaai-web) — quem edita o contrato edita
# la. A copia daqui eh so insumo do generator e drifta sozinha (2026-07-16: estava 11
# dias atras do web, e o Generated/ 39 dias — o script puxava `origin/main` DESTE repo,
# entao nunca via o contrato novo).
WEB_REPO="${VITA_WEB_REPO:-/Users/mav/vitaai-web}"

echo "[1/4] Pulling canonical openapi.yaml from the web repo..."
cd "$REPO_ROOT"
if [ -d "$WEB_REPO/.git" ]; then
    git -C "$WEB_REPO" fetch origin main --quiet
    # origin/main, nao o working tree do web: o canonico eh o que foi pushado.
    git -C "$WEB_REPO" show origin/main:openapi.yaml > "$REPO_ROOT/openapi.yaml"
    echo "  From $WEB_REPO (origin/main)"
else
    echo "  Web repo not found at $WEB_REPO. Copying from monstro via Tailscale..."
    scp monstro:openapi.yaml "$REPO_ROOT/openapi.yaml"
fi

echo "[2/4] Generating Swift models from OpenAPI..."
# `... | grep -c` mascarava falha do generator: spec invalida saia como "Generated 0
# files" e o script seguia feliz (foi assim que o Generated/ ficou 39 dias atras — o
# spec tinha um `get:` faltando em /api/dashboard e ninguem viu). Falha agora eh alta.
gen_log="$(mktemp)"
if ! openapi-generator generate     -i openapi.yaml     -g swift6     -o "$GENERATED_API"     --global-property models,supportingFiles     --additional-properties projectName=VitaAPI,useSPMFileStructure=true,library=urlsession     > "$gen_log" 2>&1; then
    echo "  FALHOU. openapi-generator disse:"
    grep -viE '^\[main\] INFO|^WARNING' "$gen_log" | head -20
    rm -f "$gen_log"
    exit 1
fi
grep -c 'writing file' "$gen_log" | xargs -I{} echo "  Generated {} files"
rm -f "$gen_log"

echo "[3/4] Copying models to project..."
mkdir -p "$GENERATED_MODELS" "$GENERATED_INFRA"

# Infra que os MODELS referenciam — nao o cliente HTTP gerado (o app tem o VitaAPI.swift
# proprio). Validation.swift entrou em 2026-07-16: os models passaram a declarar
# `NumericRule`/`StringRule` pros campos com min/max do spec.
cp "$GENERATED_API/Sources/VitaAPI/Infrastructure/JSONValue.swift" "$GENERATED_INFRA/"
cp "$GENERATED_API/Sources/VitaAPI/Infrastructure/Validation.swift" "$GENERATED_INFRA/"

# So os models EM USO — copiar os ~centenas do spec incharia o projeto com model morto.
for f in "$GENERATED_MODELS"/*.swift; do
    basename="$(basename "$f")"
    src="$GENERATED_API/Sources/VitaAPI/Models/$basename"
    if [ -f "$src" ]; then
        cp "$src" "$f"
    fi
done

# ...mas o filtro acima eh silencioso: model NOVO que o app precisa nunca aparece e
# ninguem percebe. Lista o que o contrato tem e o projeto nao — copiar eh decisao humana.
new_models=""
for src in "$GENERATED_API/Sources/VitaAPI/Models"/*.swift; do
    basename="$(basename "$src")"
    [ -f "$GENERATED_MODELS/$basename" ] || new_models="$new_models  $basename\n"
done
if [ -n "$new_models" ]; then
    echo "  Models no contrato que o projeto NAO tem (copie os que precisar):"
    printf "$new_models" | head -20
fi

echo "[4/4] Regenerating Xcode project..."
cd "$REPO_ROOT"
xcodegen generate 2>&1 | tail -1

echo ""
echo "Done! Run a build to verify:"
echo "  xcodebuild -project VitaAI.xcodeproj -scheme VitaAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build"

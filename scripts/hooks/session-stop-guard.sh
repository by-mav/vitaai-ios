#!/usr/bin/env bash
# session-stop-guard.sh — roda no SessionEnd (fim de sessão). NÃO bloqueia.
#
# Causa raiz (2026-07-24): 55 arquivos / 2750 linhas de WIP acumulado no working
# tree sem commit, de várias sessões. Um `git reset --hard` de outra sessão
# apagaria tudo que é rastreado. A LEI 2 exige tree limpo no fim da sessão.
#
# O que faz quando o tree do Vita está sujo ao encerrar:
#   1. salva um patch timestamped em agent-brain/wip-snapshots/ (rede de
#      segurança — nada rastreado se perde, mesmo com reset --hard depois);
#   2. imprime um lembrete gritado pra COMMITAR + pushar.
# Retém só os 20 snapshots mais novos (não vira cemitério).
set -uo pipefail

REPO="/Users/mav/vitaai-ios"
SNAP_DIR="/Users/mav/agent-brain/wip-snapshots"

cd "$REPO" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

DIRTY="$(git status --porcelain 2>/dev/null)"
[ -z "$DIRTY" ] && exit 0   # tree limpo → nada a fazer, silencioso

N=$(printf '%s\n' "$DIRTY" | grep -c .)
mkdir -p "$SNAP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
PATCH="$SNAP_DIR/vitaai-autosnap-$STAMP.patch"
git diff HEAD > "$PATCH" 2>/dev/null || true

# retenção: mantém os 20 mais recentes
ls -1t "$SNAP_DIR"/vitaai-autosnap-*.patch 2>/dev/null | tail -n +21 | xargs -r rm -f

cat >&2 <<EOF
⚠️  [vita hygiene] Working tree SUJO no fim da sessão: $N arquivo(s) não-commitados.
    Backup de segurança salvo: $PATCH
    LEI 2 exige tree limpo. Commite antes de encerrar:
      cd $REPO && git add -A && git commit -m "feat(...): <objetivo real>" && git push
    (recuperar o backup, se preciso: git apply "$PATCH")
EOF
exit 0

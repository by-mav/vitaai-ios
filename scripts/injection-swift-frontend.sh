#!/usr/bin/env bash
set -u

# Frontend proxy local, usado somente pelo target Pixio em Debug.
# Mantém o build totalmente via CLI e envia ao InjectionNext os comandos
# necessários para recompilar um único arquivo salvo, sem abrir o Xcode.
REAL_FRONTEND="$0.save"
if [ ! -x "$REAL_FRONTEND" ]; then
  REAL_FRONTEND="$(xcrun --find swift-frontend)"
fi
FEED_COMMANDS="/Applications/InjectionNext.app/Contents/Resources/feedcommands"

# Xcode asks a custom frontend to create an empty ABI descriptor for apps that
# do not publish library evolution metadata. The stock driver normally creates
# this tiny JSON itself, so reproduce that behavior when the custom frontend is
# in use. Without it, the link step can fail even though compilation succeeded.
empty_abi=false
abi_path=""
module_output=""
is_compile=false
for ((index = 1; index <= $#; index++)); do
  argument="${!index}"
  if [ "$argument" = "-c" ]; then
    is_compile=true
  elif [ "$argument" = "-empty-abi-descriptor" ]; then
    empty_abi=true
  elif [ "$argument" = "-emit-abi-descriptor-path" ]; then
    next_index=$((index + 1))
    abi_path="${!next_index:-}"
  elif [ "$argument" = "-o" ]; then
    next_index=$((index + 1))
    candidate="${!next_index:-}"
    if [[ "$candidate" = *.swiftmodule ]]; then
      module_output="$candidate"
    fi
  fi
done

# Com `-driver-use-frontend-path`, o Xcode 26 pode omitir
# `-emit-abi-descriptor-path` e passar somente `-o <module>.swiftmodule`, embora
# a etapa seguinte ainda copie `<module>.abi.json`. Inferimos o sibling esperado.
if [ -z "$abi_path" ] && [ -n "$module_output" ]; then
  abi_path="${module_output%.swiftmodule}.abi.json"
fi

# Dependency scans and target-info must otherwise behave exactly like the
# original frontend.
if [ "$is_compile" = false ]; then
  "$REAL_FRONTEND" "$@"
  status=$?

  if [ "$status" -eq 0 ] && [ "$empty_abi" = true ] && [ -n "$abi_path" ] && [ ! -e "$abi_path" ]; then
    mkdir -p "$(dirname "$abi_path")"
    printf '%s\n' \
      '{' \
      '  "ABIRoot": {' \
      '    "kind": "Root",' \
      '    "name": "NO_MODULE",' \
      '    "printedName": "NO_MODULE",' \
      '    "json_format_version": 8' \
      '  },' \
      '  "ConstValues": []' \
      '}' >"$abi_path"
  fi

  exit "$status"
fi

"$REAL_FRONTEND" "$@"
status=$?

if [ "$status" -eq 0 ] && [ -x "$FEED_COMMANDS" ]; then
  "$FEED_COMMANDS" "2.0" "$(/usr/bin/env)" "$REAL_FRONTEND" "$@" \
    >>/tmp/vita-injection-feedcommands.log 2>&1 &
fi

exit "$status"

#!/bin/bash
# Lê os pedidos do DevInspector do simulador Vita (aponta-e-fala).
UDID="${1:-160D5B0D-706E-4FD2-9D68-F230E2E7B250}"
C=$(xcrun simctl get_app_container "$UDID" com.bymav.vitaai data 2>/dev/null)
cat "$C/Documents/dev-inspect.jsonl" 2>/dev/null || echo "(nenhum pedido ainda)"

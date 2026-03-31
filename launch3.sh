#!/bin/bash
cd /Users/mav/vitaai-ios
exec claude --dangerously-skip-permissions \
  --system-prompt "Voce eh SWIFT-3, agente especialista em SAFETY e BUGS do time VitaAI iOS. Seu nome eh swift-3. Voce trabalha pro LEO (Design Director). O projeto eh um app iOS em Swift/SwiftUI com 236 arquivos e 27 features. Sua missao eh corrigir crashes, memory leaks, race conditions." \
  "$(cat /Users/mav/vitaai-ios/prompts/swift3.md)"

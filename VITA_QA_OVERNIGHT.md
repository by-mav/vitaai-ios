# VitaAI iOS — QA Overnight Task

## Contexto
O app VitaAI iOS está rodando no simulador iPhone 17 Pro (C3217422-5F88-4E1F-9C8D-E44CABC317E2).
Usuário logado: Rafael Freitas Loureiro (Google login, conta ULBRA).
Dashboard funciona com disciplinas reais, agenda com provas, ferramentas de estudo.

## O que fazer

Use o computer-use pra controlar o Simulator e testar CADA tela do app. Pra cada tela:
1. Screenshot
2. Anotar o que funciona
3. Anotar o que NÃO funciona (botão morto, tela vazia, crash, layout quebrado)
4. Anotar o que está feio ou errado visualmente

## Telas pra testar (em ordem)

### Tab 1: Home (Dashboard)
- Hero carousel: swipe lateral funciona?
- "Estudar agora" abre algo?
- Ferramentas (Questões, Flashcards, Simulados, Transcrição): cada uma abre?
- Disciplinas: clicar numa disciplina abre detalhe?
- Atlas 3D: abre?
- Agenda: mostra provas corretas?
- Hamburger (≡): abre configurações?
- Sino (🔔): abre notificações?

### Tab 2: Estudos
- Lista de ferramentas carrega?
- Cada ferramenta abre a tela certa?
- Canvas connect funciona?
- Notebooks, MindMaps, PDFs

### Tab 3: Chat Vita (botão central)
- Abre o chat?
- Teclado aparece?
- Mandar mensagem funciona?
- Resposta streaming aparece?

### Tab 4: Faculdade (Agenda)
- Calendário carrega?
- Eventos aparecem?
- Provas futuras mostram?

### Tab 5: Progresso (Profile)
- Perfil carrega com nome e foto?
- Nível e XP mostram?
- Configurações abre?
- Aparência abre?
- Notificações abre?
- Conexões abre?
- Sobre abre?
- Logout funciona?

### Fluxos E2E
- Flashcard: abrir deck → iniciar sessão → flip card → avaliar → summary
- Simulado: configurar → iniciar → responder → resultado
- QBank: abrir → filtrar → iniciar sessão → responder
- Transcrição: abrir tela (mic pode não funcionar no simulador)

### Dark Mode
- Trocar pra dark mode: Settings do simulador → Appearance → Dark
- Verificar TODAS as telas acima: texto legível? Cores ok? Nada invisível?

### Verificações visuais
- Touch targets >= 44pt
- Todos os botões têm ação (nenhum botão morto)
- Todos os textos legíveis em ambos os modos
- Nenhuma tela vazia sem mensagem de erro/empty state
- Tab bar visível em todas as telas

## Como reportar

Crie o arquivo /Users/mav/vitaai-ios/QA_REPORT.md com:

```
# QA Report — VitaAI iOS
Data: [data]

## Resumo
- X telas testadas
- X bugs encontrados
- X telas perfeitas

## Bugs encontrados
### BUG-001: [severidade] [descrição]
- Tela: [nome]
- Repro: [passos]
- Esperado: [o que deveria acontecer]
- Atual: [o que acontece]
- Screenshot: [path]

## Telas aprovadas
- [lista de telas que funcionam perfeitamente]
```

## Simulador
- ID: C3217422-5F88-4E1F-9C8D-E44CABC317E2
- Screenshot: xcrun simctl io C3217422-5F88-4E1F-9C8D-E44CABC317E2 screenshot /tmp/qa-[nome].png
- O app já está instalado e logado. Só abrir e navegar.

## IMPORTANTE
- NÃO edite código. Só teste e reporte.
- Se o app crashar, relance: xcrun simctl launch C3217422-5F88-4E1F-9C8D-E44CABC317E2 com.bymav.vitaai
- Teste TUDO. Cada botão, cada link, cada tela.
- Seja detalhista. O Rafael vai ler o relatório amanhã de manhã.

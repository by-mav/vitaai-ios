# vitaai-ios — AGENTS.md

> Repo iOS Swift native do app VitaAI. Roda no macmini (macOS + Xcode + iPhone simulator).
> Entrypoint hierárquico — root: `agent-brain/AGENTS.md` (no monstro, sincronizado via Tailscale).

## Identidade do app

- **Nome**: VITA (assistente de estudos médicos)
- **Bundle ID**: `com.bymav.vitaai`
- **Plataforma**: iOS Swift native (SwiftUI + Liquid Glass iOS 26)
- **Status**: visual + behavior **canonical reference** pra Android e Web

## Stack

- **Linguagem**: Swift 5.10+, iOS 17+
- **UI**: SwiftUI (iOS 26 Liquid Glass)
- **HTTP**: URLSession + custom HTTPClient com retry/refresh
- **Auth**: Keychain via `TokenStore.swift`
- **Codegen**: OpenAPI Generator (Swift Combine) → `Generated/API/Sources/VitaAPI/`
- **Tests**: XCUITest (`VitaAIUITests/`)

## API contract — HARD ENFORCE

`vitaai-web/openapi.yaml` é SOT (no monstro). Tipos são GERADOS:

```
vitaai-web/openapi.yaml (monstro WSL)
  ↓ ./scripts/sync-api-spec.sh (puxa via SSH/curl)
  ↓ xcodegen generate (regenera Generated/)
  ↓ Generated/API/Sources/VitaAPI/Models/*.swift (300+ files)
```

**NUNCA editar** `Generated/API/`. Header literal: "auto-generated, do not edit".

## Comportamento cross-platform

iOS é a **REFERÊNCIA CANÔNICA**. Quando criar feature comportamental nova, **implementar no iOS primeiro** + atualizar `agent-brain/behavior/<feature>/`. Android e Web depois replicam.

| Feature | Spec | Status iOS |
|---|---|---|
| Auth lifecycle | `agent-brain/behavior/auth-lifecycle/` | canonical (HTTPClient.swift, AuthManager.swift, AppRouter.swift, AppContainer.swift) |
| Onboarding gating | TBD | canonical (AppRouter.swift) |
| Deep links | TBD | DeepLinkHandler.swift |
| Push notifications (APNs) | TBD | VitaAppDelegate.swift |
| SSE lifecycle | TBD | HTTPClient + chatClient + osceSseClient |

Se você mudou comportamento no iOS sem atualizar `agent-brain/behavior/<feature>/`: **comportamento agora é folclore** até alguém destilar.

## Workflows comuns

### Build + install + launch no sim (canônico)

```bash
ssh mav@100.115.244.90 'cd /Users/mav/vitaai-ios && ./scripts/dev-sim.sh'
# build + uninstall + install + launch + valida mtime do .app
```

NUNCA `xcodebuild build` sozinho — não reinstala no sim, .app fica velho.

### Regenerar tipos da API

```bash
./scripts/sync-api-spec.sh
# puxa openapi.yaml do monstro, regen, xcodegen generate
```

NUNCA editar manualmente `Generated/API/Sources/VitaAPI/Models/*.swift`.

### Deploy TestFlight

```bash
./scripts/deploy-testflight.sh
# ~2-3min, auto-incrementa build number
```

NUNCA `xcodebuild archive` manual.

### Screenshot do sim

XCUITest tem `ScreenshotAllTabs.swift` (tabs principais) + `OnboardingE2ETest.swift`. Pra screenshot ad-hoc:

```bash
xcrun simctl io booted screenshot /tmp/sim.png
```

### Ver logs

```bash
xcrun simctl spawn booted log stream --predicate 'processImagePath CONTAINS "VitaAI"'
```

## Estrutura

```
VitaAI/
  Core/
    Auth/                 # AuthManager.swift, TokenStore.swift
    Network/              # HTTPClient.swift (retry + refresh + 401 dispatch)
    DI/AppContainer.swift # 401 wiring pra HTTP + 3 SSE clients
  Features/
    Auth/LoginScreen.swift
    Auth/AuthViewModel.swift
    Onboarding/VitaOnboarding.swift
    Onboarding/Steps/{SleepStep,WelcomeStep,...}.swift
    [outras features]
  Navigation/AppRouter.swift  # gating central (loading/login/onboarding/main)
  DesignSystem/
  Generated/API/           # OpenAPI codegen (NAO EDITAR)

VitaAIUITests/             # XCUITest
```

## Quality gates

`./scripts/quality-gate-modals.js` valida modais. Mais checks em pre-commit hooks.

## Liquid Glass iOS 26

App usa Liquid Glass v19 (capturado em `agent-brain/notes/2026-04-28_pixio-liquid-glass-v19-from-conversation.md`). Visual baseline em `agent-brain/ios-gold/INVENTORY.md`.

## Workflow padrão

1. **Antes de criar feature comportamental nova**: pensar se vai virar `behavior/<feature>/` (provável).
2. Implementar em SwiftUI.
3. `./scripts/dev-sim.sh` — build + install + launch.
4. Validar visual + behavior no sim.
5. **Se comportamento novo é cross-platform**: criar `agent-brain/behavior/<feature>/{README,machine.json,parity.md,golden/}` no MESMO commit.
6. `git commit + push` direto em `main`.

## Referências

- Identidade ATLAS: `~/.claude/agents/atlas.md`
- Brain canônico: `agent-brain/AGENTS.md`
- Vita architectural law: `~/.claude/CLAUDE.md`
- Memory iOS deploy: `feedback_ios_sim_deploy.md`
- Memory deploy TestFlight: `reference_testflight_deploy.md`

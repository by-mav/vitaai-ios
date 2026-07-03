# VitaAI — Design System (fonte única)

> **LEIA ANTES de mexer em QUALQUER UI.** Este é o contrato visual do Vita.
> Regra-mãe: **muda o token → muda o app todo.** Se você está escrevendo um valor
> de cor/fonte/espaço/raio **dentro de uma tela**, está errado — vem de token.
> Gate: `scripts/hooks/pre-commit` barra dívida nova (ative com
> `git config core.hooksPath scripts/hooks`).

Última atualização: 2026-07-02.

---

## 1. Onde os valores moram (cadeia SOT → código)

```
agent-brain/design-tokens.json      ← SOT dos VALORES (cor/fonte/espaço/raio/elevação)
        │  generate-tokens.mjs (codegen multi-plataforma)
        ├──▶ VitaAI/DesignSystem/Tokens.swift   (iOS — "// DO NOT EDIT")
        ├──▶ Android Tokens.kt
        └──▶ web tokens.css
```

- **`VitaTokens`** (`Tokens.swift`, auto-gerado): camada **primitiva**. `PrimitiveColors.gold300…gold700`, `glowA/B/C`, `green500/red500/amber500/blue400/indigo400/teal400`; `Spacing` (`xxs/xs/sm/md/lg/xl/_2xl/_3xl/_4xl`); `Radius` (`sm=8 / md=12 / lg=16 / xl / full`); `Elevation`; `Typography`. **Nunca editar à mão** — muda o JSON e regenera.
- **`VitaColors`** (`Theme/VitaColors.swift`, hand-written): camada **semântica** — é daqui que a UI consome. Mapeia primitivos em papéis: `accent`, `surface*`, `glass*`, `text*`, `data*`, semânticos (`success/danger/warning/recording`), `tool*`, e a rampa `emblem*`.
- **`PixioTypo`** (`Theme/PixioCompat.swift`): text styles semânticos — `.screenTitle / .title / .body / .caption / .micro`. Tipografia sai daqui, **nunca** de `.font(.system(size:))`.

---

## 2. Preciso de X → use Y (componentes canônicos VIVOS)

| Preciso de… | Use | Onde |
|---|---|---|
| Ícone de ferramenta/feature | **`VitaEmblem(symbol:size:)`** (64 hero · 54 tool · 40 row · 30 chip) | `Components/VitaEmblem.swift` |
| Card / superfície de vidro | **`VitaGlassCard`** ou o modifier **`.glassCard()`** | `Components/VitaGlassCard.swift` |
| Botão | **`VitaButton`** | `Components/VitaButton.swift` |
| Chip / pílula | **`VitaChip`** / `GlassChip` | `Components/` |
| Campo de texto | **`VitaInput`** / `GlassTextField` | `Components/` |
| Card-herói de topo | **`VitaHeroCard`** | `Components/VitaHeroCard.swift` |
| Linha de lista | **`VitaCardRow`** | `Components/VitaCardRow.swift` |
| Estado vazio / erro / carregando | **`VitaEmptyState`** / `VitaErrorState` / `VitaScreenSkeleton` + `VitaShimmer` | `Components/` |
| Anel de progresso / barra de XP | **`ProgressRingView`** / `VitaXpBar` | `Components/` |
| Top bar / sub-abas | **`VitaTopBar`** / `VitaSubTabBar` | `Components/` |
| Fundo da tela | **`VitaAmbientBackground`** / `PixioAuroraBackground` | `Components/` · `PixioPort/` |
| Toast | **`VitaToast`** / `VitaXpToast` | `Components/` |

**Existe componente → USE.** Bespoke (montar do zero o que já existe) é proibido — foi o que gerou a colcha de retalhos.

---

## 3. Regras de arte (o que o gate NÃO pega, mas manda)

- **Paleta = ouro monocromático.** Rafael rejeita múltiplas cores de accent. `data*` (verde/vermelho/âmbar) só pra **semântica de dado** (acerto/erro/alerta), nunca decoração.
- **Cor** → `VitaColors.<token>`. **Nunca** `Color(red:)`, `Color(.sRGB)`, `#hex`, `.foregroundColor(.red)` numa tela.
- **Fonte** → `PixioTypo.*` / `VitaTypography`. **Nunca** `.font(.system(size:))`. E lembre: passar no gate ≠ hierarquia correta — secundário é menor/mais mudo que primário (Apple HIG).
- **Espaço/raio** → `VitaTokens.Spacing.*` / `VitaTokens.Radius.*`. **Nunca** `padding(26)` / `cornerRadius: 14` mágicos.
- **Rampa de ouro do emblema/medalhão** = `VitaColors.emblem{Bright,Mid,Deep,Dark,Engrave}` — **fonte única**. Não redeclarar RGB dentro de componente (foi a dívida do próprio VitaEmblem, paga em 2026-07-02).
- **Ícone** = `VitaEmblem`. **PNG gerado por IA pra ícone = PROIBIDO** (cada imagem nasce com estética própria).
- **Shell**: toda tela tem `VitaTopBar` + bottom nav + fundo. Sub-tela de detalhe = `.sheet()`, não `NavigationLink` standalone.

---

## 4. Estado real (honesto) e migração

A fundação (tokens + codegen + componentes) é sólida, mas a **aderência é parcial** — auditoria 2026-07-02 mediu, no legado: ~1.031 cores cruas, ~1.820 fontes hardcoded, ~1.247 espaços/raios fora da escala. Não é big-bang:

1. **Gate ligado** (feito) — nenhuma dívida NOVA entra em `Features/`.
2. **Componentes consomem token** — ex. `VitaEmblem` (feito). Migrar os que ainda hardcodam por dentro.
3. **Telas migram por fase** — 1 tela = 1 commit = 1 screenshot. Piores primeiro: `ProgressoScreen`, `SimuladoResultScreen`.

Enquanto uma linha legada não migrou, ela fica — o gate só olha o que você **adiciona**. Precisa de um caso legítimo fora do token? Justifique na linha com `// ds-allow: <motivo>`.

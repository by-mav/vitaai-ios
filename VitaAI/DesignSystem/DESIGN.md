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
| **Peça do MUNDO da trilha** (placa, quadro, medalha, NPC) | **estética "Quadro de Mundo"** (§5) — cores de `TrailWorld`, não glass gold | `Features/Missions/`, `Features/Progresso/` |

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

---

## 5. Estética "Quadro de Mundo" (trilha gamificada)

> **O que é.** A Home (trilha de níveis) NÃO é glass-gold: é um **mundo físico** — campo noturno, estrada de ouro, casas de pedra, placas de madeira. Toda peça que vive DENTRO desse mundo (placa de missões, quadro de missões, medalhas, baús, o Vita de NPC) segue esta linguagem, não a §2/§3. É a exceção deliberada ao glass gold. Referências VIVAS: `Features/Missions/TrailMissionSign.swift` (placa) + `DailyMissionsPopout.swift` (quadro) + `Features/Progresso/Semi3DHouse.swift` (casa).

**Regras (siga ao criar QUALQUER peça de mundo — placa, quadro, baú, banner):**

1. **Cor = `TrailWorld` (`DesignSystem/Theme/TrailWorldPalette.swift`), não `VitaColors`.** É a paleta do mundo: `wood`, `roofTop/Bottom`, `stoneTop/Bottom`, `fireflyGold/Warm` (luz), `fieldTop/Bottom`, `windowGlow`. Mudar o clima do mundo = mudar esse arquivo. Fora do mundo (o resto do app) continua `VitaColors`. *(Cores cruas de mundo passam pelo gate com `// ds-allow: arte gamificada (mundo da trilha)`.)*
2. **Desenho em `Canvas`, vista 3/4.** Peça sólida (placa/casa/baú) é desenhada em `Canvas` em coords lógicas e escalada pro frame — face frontal + face lateral (profundidade) + espessura de topo. Estática: `.transaction { $0.animation = nil }` (não re-avalia por frame, mata o "bob" do ScrollView).
3. **Luz vem de CIMA-ESQUERDA, sempre (lei §2.12 — luz e matéria).** Todo elemento TÁTIL ocupa espaço sob essa luz: **gradiente** na superfície (pega luz de uma direção, nunca fill chapado) · **highlight especular** no topo (fio de luz = peça sólida) · **rim light** na quina viva · **sombra no chão** (ancora) · **recesso** (inner shadow) pra trilhos/afundados · **elevação** (drop shadow) pra botões/flutuantes. Texto e fundo ficam planos DE PROPÓSITO; só o tátil ganha matéria.
4. **Medalha bronze/prata/ouro = tier por posição.** As 3 missões do dia vêm ordenadas por recompensa (bronze→prata→ouro); o cliente pinta pela posição (`missionTier(index)`). Ouro = `fireflyGold`; prata/bronze = ds-allow (não são tokens do app).
5. **NPC + balão.** O Vita "atende" a peça (loja, missões): `VitaMascotEquipped` ao lado/na frente, com balão de fala em `fireflyWarm→fireflyGold`. Estado `.awake` na fase atual, `.sleeping` (apagado, opacity ~0.42) nas outras.
6. **Interação.** Peça posicionada (`.position`) que abre algo = **`Button` + `.contentShape(Rectangle())`** (NÃO `onTapGesture` — não pega confiável em `.position` dentro do ScrollView) + `.accessibilityIdentifier` (pra QA tocar por id). E fique **por cima** das camadas da trilha (o `VStack` das linhas come o toque de quem estiver atrás).
7. **Recompensa é SENTIDA.** Resgate = moeda voando pro saldo (`CoinBurst`) + `HapticManager.fire(.success)` + `contentTransition(.numericText())` no saldo. Botão de ação pulsa (respiração lenta, `repeatForever`), nunca pisca.

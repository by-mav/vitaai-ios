# VitaAI App — Comportamento Completo (Source of Truth: 3111)

## Estrutura de Navegação

### Bottom Nav (4 tabs + Vita center)
| Índice | Tab | Ícone | Página |
|--------|-----|-------|--------|
| 0 | Home | house | dashboard-mobile-v2.html |
| 1 | Estudos | book | estudos-mobile-v1.html |
| 2 | Faculdade | graduationcap | faculdade-mobile-v1.html |
| 3 | Progresso | chart.bar | progresso-mobile-v1.html |
| center | Vita | cobra img | Abre chat |

### Hierarquia de Páginas (depth)
```
Depth 0: Dashboard (home)
Depth 1: Estudos, Faculdade, Progresso, Perfil, Configurações, Assinatura
Depth 2: QBank, Flashcards, Simulados, Transcrição, Disciplina Detalhe, Atlas3D, Aparência
Depth 3: Flashcard Session, Simulado Config, Simulado Quiz, Simulado Result
```

### Parentesco (back navigation)
```
QBank ← Estudos
Flashcards ← Estudos
  Flashcard Session ← Flashcards
Simulados ← Estudos
  Simulado Config ← Simulados
  Simulado Quiz ← Simulados
  Simulado Result ← Simulados
Transcrição ← Estudos
Atlas3D ← Estudos
Disciplina Detalhe ← Dashboard
Perfil ← Dashboard
Configurações ← Dashboard
  Aparência ← Configurações
Assinatura ← Dashboard
Conectores ← Faculdade
```

### Tab Map (qual tab fica ativo em cada página)
```
Tab 0 (Home): Dashboard
Tab 1 (Estudos): Estudos, QBank, Flashcards, Flashcard Session, Simulados, Simulado Config/Quiz/Result, Transcrição, Atlas3D
Tab 2 (Faculdade): Faculdade, Conectores, Disciplina Detalhe
Tab 3 (Progresso): Progresso
Nenhum tab: Perfil, Configurações, Aparência, Assinatura
```

### Transições
- Tab para tab: sem animação (swap instantâneo)
- Push para sub-página: slide da direita pra esquerda (300ms cubic-bezier)
- Back: slide da esquerda pra direita
- Swipe back: arrastar da borda esquerda

### Top Nav (SEMPRE visível, NUNCA muda)
- Avatar com XP ring (40x40px)
- Greeting dinâmico ("Boa noite, Rafael")
- Subtitle ("3º período · ULBRA Porto Alegre")
- Bell icon (notificações) → abre sheet de notificações
- Hamburger icon (menu) → abre sheet de menu
- Level badge no avatar (ex: "7")

### Bottom Nav (SEMPRE visível em TODAS as páginas)
- Glassmorphism pill (blur 50px)
- 4 circles + vita-btn center
- Tab ativo tem cor dourada e glow
- Fixed no bottom, z-index 9999

## 19 Páginas — Comportamento Detalhado

### 1. DASHBOARD (depth 0, tab 0)
- **Background**: fundo-dashboard.webp + ambient gold glows
- **Hero Carousel**: slides com provas próximas (G1 Farmacologia 8d, AP1 Med Legal 9d, AP1 Patologia 11d)
  - Cada slide: bg image, título da prova, pills (temas, dias), CTA "Estudo agora"
  - Dots de navegação, setas left/right
  - Auto-rotate a cada 6s
- **"Ferramentas de Estudo"**: label 11px uppercase gold
  - Grid 2x2 de imagens: Questões, Flashcards, Simulados, Transcrição
  - Cada imagem clicável → navega pra respectiva tool screen
- **"Minhas Disciplinas"**: horizontal scroll com cards de disciplinas
  - Cada card clicável → navega pra Disciplina Detalhe
- **"Dica do Dia"**: card com lightbulb icon + dica científica + fonte PubMed
- **Atlas3D + Agenda**: side by side no bottom
  - Atlas3D: imagem clicável
  - Agenda: lista de próximos compromissos
- **Dados**: `/api/mockup/dashboard`

### 2. ESTUDOS (depth 1, tab 1)
- **Continue Studying Card**: hero com bg image da disciplina, título do deck, progress bar, CTA "Continuar"
- **3 Module Cards**: horizontal (Questões, Flashcards, Simulados) — imagens clicáveis
- **"Suas Disciplinas"**: horizontal scroll com discipline thumbnails
- **"Vita Sugere"**: horizontal scroll com material cards (vídeo, PDF)
- **"Trabalhos Pendentes"**: lista vertical com due dates
- **"Sessões Recentes"**: lista vertical com stats
- **Dados**: `/api/mockup/dashboard` + disciplinas do aluno

### 3. FACULDADE (depth 1, tab 2)
- **Hero Card**: glass com nome do curso, período, universidade
- **Stats Row**: 4 stats (Disciplinas, Média, Frequência, Cursando) com cores verde
- **Semester Tabs**: pills selecionáveis (2026/1, etc.)
- **Agenda Semanal**: week strip (Seg-Sex) com schedule items
- **Discipline Table**: lista de disciplinas cursando com:
  - Glass icon (glassv2-disc-*.webp)
  - Nome, professor
  - Difficulty badge (Fácil/Médio/Difícil)
  - Frequency pill
  - Score Vita badge (circular)
- **Aprovadas**: toggle expandível com disciplinas já aprovadas
- **Dados**: WebAluno grades + schedule

### 4. PROGRESSO (depth 1, tab 3)
- **Hero Card**: XP ring (level N), nome, XP bar, streak row (S T Q Q S S D)
- **Stats Grid 2x2**: streak, horas estudo, accuracy %, flashcards
- **Weekly Chart**: 7 barras (S-D), hoje highlighted, meta semanal
- **"Onde Melhorar"**: 3 disciplinas fracas com mini progress bars
- **Leaderboard**: 3 tabs (Semanal/Mensal/Total), top 5 users, "Sua posição"
- **Heatmap**: 13x7 grid (91 dias), 5 níveis de intensidade
- **Dados**: `/api/activity/stats` + `/api/progress`

### 5. FLASHCARDS (depth 2, tab 1)
- **Background**: flashcard-bg-new.png (fullscreen, partículas)
- **Hero Image**: flashcard-hero-clean.webp (full width, rounded 18)
- **"Continuar"**: card com book icon + deck title + "X pendentes" + chevron
- **"Recomendados"**: horizontal scroll com cards (image + title + stats)
  - Ordenados por Score Vita (prova próxima = prioridade)
- **"Disciplinas / decks"**: grid 2x2 com icon + deck name
- **Empty State**: "Sem flashcards ainda" + "Peça pra Vita gerar"
- **Dados**: `/api/mockup/flashcards` + `/api/mockup/flashcards/recommended`

### 6. FLASHCARD SESSION (depth 3, tab 1)
- **Background**: #100818 (purple-tinted dark)
- **Card**: 3D flip animation (front → back)
- **Rating Buttons**: 4 botões (Errei/Difícil/Bom/Fácil) com cores diferentes
  - Errei: vermelho, Difícil: amber, Bom: verde claro, Fácil: verde
- **Stars**: indicador de dificuldade
- **Progress**: barra no top
- **Sessão Completa**: overlay com stats
- **Dados**: `/api/mockup/flashcards/[id]/review`

### 7. SIMULADOS HOME (depth 2, tab 1)
- **Background**: bg-simulados fullscreen, teal/cyan theme (#060a0e)
- **Accent**: rgba(120,220,240) — TEAL, não gold
- **Hero Stats Card**: score ring, total/completed, avg score
- **CTA**: "Novo Simulado" button (teal glow)
- **"Sessões Recentes"**: attempt cards com score badges
- **Diagnostics Link**: link pra diagnóstico por área
- **Dados**: `/api/simulados`

### 8. SIMULADO CONFIG (depth 3, tab 1)
- **Templates**: horizontal scroll com template cards
- **Discipline Grid**: 2x2 selectable com disc-dot indicators
- **Count Pills**: seletor de quantidade (5, 10, 15, 20)
- **Timer Toggle**
- **Gold CTA Button**: "Iniciar Simulado"

### 9. SIMULADO QUIZ (depth 3, tab 1)
- **Header**: progress bar + timer
- **Question Card**: glass card com enunciado
- **Options**: A-B-C-D-E com letter squares
- **Feedback**: correct/wrong com explicação
- **Question Grid**: overlay pra navegar entre questões

### 10. SIMULADO RESULT (depth 3, tab 1)
- **Score Hero**: ring SVG com percentual
- **Stats Cards**: acertos, erros, tempo
- **Gold Button**: "Novo Simulado"
- **Ghost Button**: "Revisar Questões"
- **Subject Breakdown**: expandível por área

### 11. QBANK (depth 2, tab 1)
- **Background**: bg-qbank fullscreen, gold/amber theme
- **Progress Hero**: "234/1248" com progress bar
- **CTA**: "Nova Sessão"
- **Filter Chips**: disciplinas, anos, dificuldade
- **"Sessões Recentes"**: cards com accuracy
- **"Desempenho por Tópico"**: bars com percentual
- **Dados**: `/api/qbank/progress`

### 12. TRANSCRIÇÃO (depth 2, tab 1)
- **Accent**: teal-green rgba(120,220,200)
- **Recorder Hero**: botão grande de gravação com timer
- **Mode Toggle**: Offline / Ao Vivo
- **Recording List**: cards por disciplina com status badges
- **Actions Menu**: opções após gravação
- **Atlas3D Card**: card lateral
- **Dados**: `/api/study/transcricao`

### 13. PERFIL (depth 1, nenhum tab)
- **Avatar Ring**: grande com XP progress
- **Level Badge**
- **Nome + Email + Universidade**
- **XP Bar**: progress bar com meta
- **"Conquistas"**: horizontal scroll de badges (earned vs locked)
- **Stats Grid 2x2**: questões, flashcards, horas, streak
- **"Editar Perfil" Button**

### 14. CONFIGURAÇÕES (depth 1, nenhum tab)
- **User Card**: avatar + nome + email
- **Sections**: Conta, Preferências, Segurança, Privacidade
- **Setting Rows**: icon + label + chevron
- **AI Consent Toggle**: green
- **Logout Button**: red

### 15. APARÊNCIA (depth 2, nenhum tab)
- **Preview Frame**: mini app preview
- **Theme Cards**: Sistema / Escuro / Claro (3 cards)
- **Color Accent**: 4 swatches (Gold #c8a046, Purple #8b5cf6, Teal #14b8a6, Blue #3b82f6)
- **Font Size Slider**: draggable thumb com preview text

### 16. CONECTORES (depth 2, tab 2)
- **"Portais Conectados X/4"**: summary card
- **Portal Cards**: WebAluno, Canvas, Moodle (coming soon), SIGAA (coming soon)
  - Cada card: icon + nome + status dot (verde/cinza) + botão Conectar/Desconectar
  - Stats por serviço quando conectado
- **"Como Funciona"**: explainer section

### 17. ASSINATURA (depth 1, nenhum tab)
- **Current Plan Badge**
- **Plan Cards**: horizontal scroll snap (Free / Premium / Pro)
  - Premium: badge "POPULAR", gold CTA
  - Pro: purple accent
- **Comparison Table**: features com check/x marks

### 18. DISCIPLINA DETALHE (depth 2, tab 2)
- **Hero**: discipline image + overlay gradient + back arrow
- **Period Badge**
- **Prova Alert**: countdown (dias) + topic pills
- **"O que Estudar"**: 2x2 grid
- **"Conteúdo da Prova"**: topics com % badges
- **"Materiais"**: PDFs section
- **"Vídeos"**: horizontal scroll
- **"Vita Sugere"**: recommendation card

### 19. ATLAS 3D (depth 2, tab 1)
- **Accent**: teal rgba(20,184,166)
- **3D Viewer**: WebView
- **System Tabs**: Esqueleto, Muscular, Nervoso, etc.
- **Search Field**
- **Structures List**: rows clicáveis

## Componentes Globais

### Notification Sheet (bell icon)
- Slide up sheet
- Lista de notificações (badges, reminders, insights, grades, streak)
- Unread count badge no bell icon

### Menu Sheet (hamburger icon)
- Slide up sheet
- Links: Perfil, Configurações, Conectores, Assinatura, Sobre
- Logout

### Vita Chat (center button)
- Full screen overlay ou sheet
- Chat com a Vita IA
- Streaming responses

## Dados por Página

| Página | API Endpoint |
|--------|-------------|
| Dashboard | `/api/mockup/dashboard` |
| Estudos | `/api/mockup/dashboard` (reusa) |
| Faculdade | `/api/webaluno/grades` + `/api/webaluno/schedule` |
| Progresso | `/api/activity/stats` + `/api/progress` |
| Flashcards | `/api/mockup/flashcards` + `/api/mockup/flashcards/recommended` |
| Flashcard Session | `/api/mockup/flashcards/[id]/review` |
| Simulados | `/api/simulados` |
| Simulado Config | (local state) |
| Simulado Quiz | `/api/simulados/[id]/answer` |
| Simulado Result | `/api/simulados/[id]/result` |
| QBank | `/api/qbank/progress` + `/api/qbank/sessions` |
| Transcrição | `/api/study/transcricao` |
| Perfil | `/api/profile` + `/api/activity/stats` |
| Configurações | `/api/settings` |
| Aparência | (local state) |
| Conectores | `/api/canvas/status` + `/api/webaluno/status` |
| Assinatura | `/api/billing/status` |
| Disciplina Detalhe | `/api/mockup/dashboard` (filtra por disciplina) |
| Atlas 3D | `/api/anatomy` |

# VITA — Source of Truth

> **O que é este documento:** O contrato do produto. Cada dado que existe no Vita, onde mora, como entra, como sai.
> Se não está aqui, não existe. Qualquer feature nova começa aqui.
>
> **Última atualização:** 2026-03-29
> **Plataformas:** iOS, Android, Web — MESMA API, MESMOS dados.

---

## 1. MODELO DE DADOS CANÔNICO

Independente de onde veio (Canvas, SIGAA, Moodle, vita-crawl, chat do aluno, upload manual), os dados caem nestas entidades normalizadas:

### 1.1 Entidades Acadêmicas (source of truth do aluno)

| Entidade | Tabela DB | Descrição | Campos Canônicos |
|----------|-----------|-----------|-----------------|
| **Matrícula** | `academic_subjects` | Disciplinas do semestre | userId, name, code, professor, credits, semester, schedule, sourceType, sourceId |
| **Notas** | `academic_evaluations` | Avaliações e notas | userId, subjectId, title, type (prova/trabalho/participação), grade, maxGrade, weight, date, source |
| **Horários** | `academic_schedule` | Grade horária | userId, subjectId, dayOfWeek, startTime, endTime, room, building |
| **Calendário** | `academic_calendar` | Eventos acadêmicos | userId, title, date, endDate, type (prova/deadline/evento), subjectId, source |
| **Frequência** | `academic_attendance` ⚠️ NÃO EXISTE | Faltas/presenças | userId, subjectId, date, status (presente/falta/justificada), totalClasses, absences |
| **Financeiro** | `academic_financial` ⚠️ NÃO EXISTE | Mensalidades | userId, description, amount, dueDate, status (pago/pendente/atrasado), source |

> ⚠️ Tabelas marcadas "NÃO EXISTE" precisam ser criadas antes do lançamento.

### 1.2 Entidades de Estudo

| Entidade | Tabela DB | Descrição |
|----------|-----------|-----------|
| **Flashcards** | `flashcard_decks` + `flash_cards` | Decks com SRS (SM-2/FSRS-5) |
| **Questões** | `qbank_questions` + `qbank_alternatives` | 120k+ questões de residência |
| **Simulados** | `simulado_attempts` + `simulado_questions` | Simulados gerados por IA |
| **OSCE** | `osce_attempts` | Casos clínicos simulados |
| **Notas/Anotações** | `notes` | Markdown do aluno |
| **Documentos** | `documents` | PDFs, slides, materiais |
| **Anotações PDF** | `page_annotations` | Highlights e desenhos em PDFs |
| **Plano de Estudos** | `study_plans` + `study_plan_items` | Planejador diário/semanal |

### 1.3 Entidades de IA/Studio

| Entidade | Tabela DB | Descrição |
|----------|-----------|-----------|
| **Conversas** | `chat_conversations` + `chat_messages` | Chat com Vita |
| **Fontes Studio** | `studio_sources` + `studio_source_chunks` | PDFs, áudios, URLs processados |
| **Outputs Studio** | `studio_outputs` | Resumos, mindmaps, quizzes gerados |
| **Extrações** | `document_extractions` | Dados extraídos de PDFs por LLM |
| **Jobs** | `extraction_jobs` | Tracking de extrações em andamento |

### 1.4 Entidades de Gamificação

| Entidade | Tabela DB | Descrição |
|----------|-----------|-----------|
| **Atividade/XP** | `activity_logs` | Cada ação = XP |
| **Badges** | `user_badges` | Conquistas desbloqueadas |
| **Perfil** | `user_profiles` | Level, XP total, streak, plano billing |

### 1.5 Taxonomia (hierarquia de conhecimento)

```
qbank_disciplines (1041 nós — NÃO está no Drizzle schema, só no Postgres!)
  Level 1: 6 grandes áreas       (Ciclo Básico, Cirurgia, Clínica, GO, Pediatria, Saúde Coletiva)
  Level 2: 91 disciplinas         (Farmacologia, Patologia, Cardiologia...)
  Level 3: 830 temas              (Farmacocinética, SNA, Anti-hipertensivos...)
  Level 4: 111 sub-temas

qbank_topics (1622 tópicos granulares)
  → qbank_topics.disciplineId → qbank_disciplines.id

REGRA: Todo conteúdo acadêmico referencia esta hierarquia. Nunca texto livre.
```

### 1.6 Conexões & Universidades

| Entidade | Tabela DB | Descrição |
|----------|-----------|-----------|
| **Conexões** | `webaluno_connections` | Todas as conexões de portais (portalType, instanceUrl, credentials) |
| **Universidades** | ⚠️ HARDCODED em `universities.ts` | 128 faculdades de medicina — PRECISA virar tabela |
| **Portais por universidade** | ⚠️ NÃO EXISTE | Mapeamento universidade → portais — PRECISA ser criado |

### 1.7 Tabelas LEGADO (para eliminar)

| Tabela | Problema | Substituída por |
|--------|----------|----------------|
| `grades` | Notas manuais, não integrada com conectores | `academic_evaluations` |
| `webaluno_grades` | Notas específicas do conector | `academic_evaluations` |
| `webaluno_schedule` | Horários específicos do conector | `academic_schedule` |
| `exams` | Provas manuais | `academic_evaluations` (type='prova') + `academic_calendar` |
| `user_subjects` | Matérias do onboarding (texto livre) | `academic_subjects` mapeado pra taxonomia |

---

## 2. CONECTORES — Como os dados ENTRAM

### 2.1 Mapa de Conectores

```
CONECTOR                    STRATEGY           DADOS QUE FORNECE
─────────────────────────────────────────────────────────────────
Canvas LMS                  native_api         courses, grades, assignments, files, calendar, quizzes, modules, announcements, discussions, submissions
Moodle                      native_api         courses, grades, assignments, files, calendar, quizzes, forums, attendance, badges, competencies
SIGAA (UFRN)                native_api         enrollment, grades, schedule, history, attendance, library, internships, calendar, curriculum
SIGAA (outras 24)           vita_crawl         enrollment, grades, schedule, history, attendance, materials, assignments
WebAluno (Mannesoft)        vita_crawl         grades, schedule, history
TOTVS RM                    vita_crawl         grades, absences, schedule, financial, enrollment, materials, TCC, library
Sagres                      vita_crawl*        grades, absences, schedule (*tem REST API própria)
Lyceum                      vita_crawl*        grades, absences, financial, enrollment, schedule, materials (*tem REST API própria)
Phidelis                    vita_crawl         grades, absences, schedule, financial
Ulife                       vita_crawl         grades, schedule (Microsoft SSO — complexo)
Custom/Próprio (~30)        vita_crawl         varia por faculdade — LLM descobre na hora
Google Calendar             google_oauth       calendar events, class schedule
Google Drive                google_oauth       files (PDFs, slides, docs)
Google Classroom            google_oauth       courses, assignments, grades, materials, announcements
Microsoft Teams             ms_oauth           classes, assignments, files, calendar (futuro)
Vita Chat (LLM)             llm_extract        QUALQUER dado que o aluno falar (nota, compromisso, etc.)
Upload Manual               user_upload        PDFs, fotos de provas, áudios de aulas
Browser Extension           extension          resumos de páginas web
```

### 2.2 Fluxo Unificado de Dados

```
┌──────────────────────────────────────────────────────────────┐
│                     CONECTORES (entrada)                      │
│                                                              │
│  Canvas ──┐                                                  │
│  Moodle ──┤                                                  │
│  SIGAA  ──┤    ┌─────────────┐    ┌──────────────────────┐   │
│  TOTVS  ──┼───▶│  Normalizer │───▶│  Tabelas academic_*  │   │
│  WebAluno─┤    │  (por tipo) │    │  (source of truth)   │   │
│  Lyceum ──┤    └─────────────┘    └──────────┬───────────┘   │
│  Sagres ──┤                                  │               │
│  Custom ──┘                                  ▼               │
│                                    ┌─────────────────┐       │
│  Google ──────────────────────────▶│  Taxonomia map  │       │
│  Vita Chat ──────────────────────▶│  (qbank_disc.)  │       │
│  Upload ─────────────────────────▶│                 │       │
│  Extension ──────────────────────▶└─────────────────┘       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    API UNIFICADA (saída)                      │
│                                                              │
│  GET /api/grades          ← academic_evaluations             │
│  GET /api/schedule        ← academic_schedule                │
│  GET /api/enrollments     ← academic_subjects                │
│  GET /api/calendar        ← academic_calendar                │
│  GET /api/documents       ← documents                        │
│  GET /api/progress        ← aggregação de tudo               │
│                                                              │
│  O cliente NUNCA sabe de onde veio. Tudo é "dados do aluno". │
└──────────────────────────────────────────────────────────────┘
```

### 2.3 Capabilities por Tipo de Portal

| Capability | Canvas | Moodle | SIGAA | TOTVS | Sagres | Lyceum | WebAluno | Custom |
|------------|--------|--------|-------|-------|--------|--------|----------|--------|
| **enrollment** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ? |
| **grades** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ? |
| **schedule** | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ? |
| **assignments** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ? |
| **files** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ? |
| **calendar** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ? |
| **attendance** | ❌* | ✅* | ✅ | ✅ | ✅ | ✅ | ❌ | ? |
| **quizzes** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ? |
| **forums** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ? |
| **financial** | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ? |
| **library** | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ? |

> `*` = plugin/módulo que pode ou não estar habilitado
> `?` = descoberto pelo vita-crawl na hora da conexão

---

## 3. API — Endpoints Canônicos (sem duplicidade)

### 3.1 API Ideal (objetivo)

#### Auth & Usuário
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/auth/[...all]` | ALL | Better Auth | auth DB |
| `/api/auth/mobile-apple` | POST | Apple Sign-In | auth DB |
| `/api/profile` | GET, PATCH | Perfil completo | user_profiles |
| `/api/onboarding` | POST | Salvar onboarding | user_profiles, user_subjects |
| `/api/user/ai-consent` | POST | Consentimento IA | user_profiles |
| `/api/user/delete-data` | DELETE | LGPD | todas |

#### Conectores (entrada unificada)
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/connectors` | GET | Lista conexões do aluno com status | webaluno_connections |
| `/api/connectors/connect` | POST | Conectar qualquer portal | webaluno_connections |
| `/api/connectors/disconnect` | DELETE | Desconectar | webaluno_connections |
| `/api/connectors/sync` | POST | Forçar sync | academic_*, documents |
| `/api/connectors/sync-status` | GET | Status do sync | extraction_jobs |

> Internamente: `portalType=canvas` → Canvas API nativa. `portalType=moodle` → Moodle API. `portalType=*` → vita-crawl.

#### Dados Acadêmicos (saída unificada)
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/enrollments` | GET | Matrícula/disciplinas | academic_subjects |
| `/api/grades` | GET | Notas | academic_evaluations |
| `/api/schedule` | GET | Horários | academic_schedule |
| `/api/calendar` | GET, POST | Agenda unificada | academic_calendar |
| `/api/attendance` | GET | Frequência | academic_attendance (nova) |
| `/api/exams` | GET, POST | Provas | academic_evaluations (type=prova) + academic_calendar |
| `/api/assignments` | GET | Trabalhos/tarefas | academic_evaluations (type=trabalho) |

#### Universidades
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/universities` | GET | Lista completa com portais | universities (nova) |
| `/api/universities/[id]/portals` | GET | Portais de uma universidade | university_portals (nova) |

#### Estudo
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/study/flashcards` | GET, POST | Decks e cards | flashcard_decks, flash_cards |
| `/api/study/flashcards/[id]/review` | POST | Revisar card | flash_cards |
| `/api/study/flashcards/stats` | GET | Stats SRS | flash_cards |
| `/api/study/flashcards/recommended` | GET | Recomendados por Score Vita | flash_cards, academic_evaluations |
| `/api/study/flashcards/generate` | POST | Gerar via IA | flash_cards, studio_sources |
| `/api/planner` | GET, POST, PATCH | Plano de estudos | study_plans, study_plan_items |
| `/api/estudos/plan` | GET | Plano gerado por IA | academic_subjects, academic_evaluations, qbank_disciplines |

#### QBank
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/qbank/progress` | GET | Progresso geral | qbank_user_answers, qbank_questions |
| `/api/qbank/filters` | GET | Filtros disponíveis | qbank_institutions, qbank_topics |
| `/api/qbank/questions` | GET | Questões filtradas | qbank_questions |
| `/api/qbank/questions/[id]` | GET | Questão + alternativas | qbank_questions, qbank_alternatives, qbank_images |
| `/api/qbank/questions/[id]/answer` | POST | Responder | qbank_user_answers |
| `/api/qbank/questions/[id]/stats` | GET | Stats globais | qbank_statistics |
| `/api/qbank/sessions` | GET, POST | Sessões | qbank_sessions |
| `/api/qbank/sessions/[id]` | GET | Sessão específica | qbank_sessions |
| `/api/qbank/sessions/[id]/finish` | POST | Finalizar | qbank_sessions |
| `/api/qbank/lists` | GET, POST | Listas custom | qbank_user_lists |
| `/api/qbank/lists/[id]/questions` | GET, POST | Questões da lista | qbank_user_list_questions |

#### Simulados
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/simulados` | GET | Listar tentativas | simulado_attempts |
| `/api/simulados/generate` | POST | Gerar simulado | simulado_attempts, simulado_questions |
| `/api/simulados/[id]` | GET, DELETE | Tentativa | simulado_attempts, simulado_questions |
| `/api/simulados/[id]/answer` | POST | Responder | simulado_questions |
| `/api/simulados/[id]/finish` | POST | Finalizar | simulado_attempts |
| `/api/simulados/[id]/review` | GET | Revisão | simulado_attempts, simulado_questions |
| `/api/simulados/diagnostics` | GET | Diagnóstico por área | simulado_attempts, simulado_questions |

#### IA & Chat
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/vita/chat` | POST | Chat streaming | chat_conversations, chat_messages |
| `/api/vita/memory` | GET, POST | Memória sobre o aluno | (redis/vector store) |
| `/api/vita/student-context` | GET | AGGREGATOR — tudo do aluno | todas |
| `/api/ai/osce` | POST | Iniciar caso OSCE | osce_attempts |
| `/api/ai/osce/[id]/respond` | POST | Responder OSCE | osce_attempts |
| `/api/osce/stats` | GET | Stats OSCE | osce_attempts |
| `/api/ai/transcribe` | POST | Transcrever áudio | studio_sources |

#### Studio
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/studio/sources` | GET, POST | Fontes | studio_sources |
| `/api/studio/sources/[id]` | GET, DELETE | Fonte específica | studio_sources, studio_source_chunks |
| `/api/studio/upload` | POST | Upload arquivo | studio_sources |
| `/api/studio/generate` | POST | Gerar conteúdo | studio_outputs |
| `/api/studio/outputs` | GET | Outputs | studio_outputs |
| `/api/studio/outputs/[id]` | GET, DELETE | Output específico | studio_outputs |
| `/api/studio/outputs/add-to-deck` | POST | Output → flashcards | studio_outputs, flashcard_decks, flash_cards |

#### Documentos & Notas
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/documents` | GET, POST, DELETE | Documentos | documents |
| `/api/documents/upload` | POST | Upload | documents |
| `/api/documents/[id]/file` | GET | Download | documents |
| `/api/documents/[id]/favorite` | POST | Favoritar | documents |
| `/api/documents/[id]/extractions` | GET | Extrações IA | document_extractions |
| `/api/notes` | GET, POST, PATCH, DELETE | Notas | notes |
| `/api/annotations/[id]` | GET, POST | Anotações PDF | page_annotations |

#### Progresso & Gamificação
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/progress` | GET | Progresso unificado | user_profiles, academic_*, flash_cards, qbank_user_answers |
| `/api/activity` | GET, POST | Log XP | activity_logs |
| `/api/activity/stats` | GET | Level, XP, streak | activity_logs, user_profiles |
| `/api/leaderboard` | GET | Ranking | activity_logs, user_profiles |
| `/api/achievements` | GET | Badges | user_badges |

#### Notificações & Push
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/notifications` | GET | Listar | notifications |
| `/api/notifications/briefing` | GET | Briefing diário | notifications, academic_*, flash_cards |
| `/api/notifications/preferences` | GET, POST | Preferências | user_profiles |
| `/api/push/register` | POST | Registrar device | push_subscriptions |
| `/api/push/unregister` | DELETE | Desregistrar | push_subscriptions |

#### Billing
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/billing/status` | GET | Plano atual | user_profiles |
| `/api/billing/checkout` | POST | Iniciar checkout | user_profiles |
| `/api/billing/verify/apple` | POST | Verificar Apple IAP | user_profiles |
| `/api/billing/verify/google` | POST | Verificar Google Play | user_profiles |
| `/api/stripe/webhook` | POST | Webhook Stripe | user_profiles |

#### Taxonomia & Config
| Endpoint | Método | Descrição | Tabelas |
|----------|--------|-----------|---------|
| `/api/taxonomy` | GET | Hierarquia completa | qbank_disciplines, qbank_topics |
| `/api/config/app` | GET | Feature flags, gamification config | (remote config) |
| `/api/search` | GET | Busca global | múltiplas |

#### Outros
| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/api/health` | GET | Health check |
| `/api/errors` | POST | Log erros frontend |
| `/api/anatomy` | GET | Atlas 3D |
| `/api/extension/token` | GET | Token browser extension |
| `/api/extension/summary` | POST | Resumo de página |

### 3.2 Endpoints a ELIMINAR

| Endpoint atual | Motivo | Substituído por |
|---------------|--------|----------------|
| `/api/mockup/dashboard` | Era placeholder, dados devem vir de endpoints reais | `/api/progress` + `/api/enrollments` + `/api/calendar` |
| `/api/mockup/flashcards` | Duplica `/api/study/flashcards` | `/api/study/flashcards` |
| `/api/mockup/flashcards/[id]/review` | Duplica | `/api/study/flashcards/[id]/review` |
| `/api/mockup/flashcards/generate` | Mover | `/api/study/flashcards/generate` |
| `/api/mockup/flashcards/recommended` | Mover | `/api/study/flashcards/recommended` |
| `/api/mockup/flashcards/session-complete` | Mover | `/api/study/flashcards/session-complete` |
| `/api/mockup/notifications` | Duplica `/api/notifications` | `/api/notifications` |
| `/api/mockup/simulados/generate` | Mover | `/api/simulados/generate` |
| `/api/mockup/taxonomy` | Mover | `/api/taxonomy` |
| `/api/activity/leaderboard` | Duplica `/api/leaderboard` | `/api/leaderboard` |
| `/api/activity/gamification-config` | Mover | `/api/config/app` |
| `/api/materiais` | Duplica `/api/documents` (read-only view) | `/api/documents?type=material` |
| `/api/study/trabalhos` | Duplica `/api/planner` (mesmas tabelas) | `/api/planner?type=trabalho` ou `/api/assignments` |
| `/api/study/transcricao` GET | Duplica studio_sources filtered | `/api/studio/sources?type=audio` |
| `/api/study/transcricao` POST | Forward pra ai/transcribe | `/api/ai/transcribe` |
| `/api/study/mindmaps` | Duplica studio_outputs filtered | `/api/studio/outputs?type=mindmap` |
| `/api/study/clinical-cases` | Duplica osce_attempts | `/api/osce/stats` |
| `/api/study/voice/sessions` | Duplica osce_attempts | `/api/osce/stats` |
| `/api/study/osce` | Retorna `[]` — dead shim | Deletar |
| `/api/study/sessions` | Agrega qbank+simulados | `/api/activity?type=study_session` |
| `/api/ai/conversations` | Legado | `/api/ai/coach/conversations` |
| `/api/stats` | Dados já em `/api/progress` | `/api/progress` |
| `/api/canvas/status` | Mover pra unificado | `/api/connectors` |
| `/api/canvas/connect` | Mover | `/api/connectors/connect` |
| `/api/canvas/disconnect` | Mover | `/api/connectors/disconnect` |
| `/api/canvas/courses` | Dados já em enrollments | `/api/enrollments` |
| `/api/canvas/assignments` | Dados já em evaluations | `/api/assignments` |
| `/api/canvas/files` | Dados já em documents | `/api/documents` |
| `/api/webaluno/status` | Mover | `/api/connectors` |
| `/api/webaluno/connect` | Mover | `/api/connectors/connect` |
| `/api/webaluno/grades` | Legado | `/api/grades` |
| `/api/webaluno/schedule` | Legado | `/api/schedule` |
| `/api/portal/extract` | Unificar | `/api/connectors/sync` |
| `/api/portal/data` | Unificar | endpoints acadêmicos normalizados |

---

## 4. BUGS CRÍTICOS NO FLUXO DE DADOS

### Bug 1: `/api/portal/extract` não escreve nas tabelas normalizadas
- **Problema:** Canvas ingest → `academic_*` ✅. WebAluno ingest → `academic_*` ✅. Portal extract → `webaluno_*` SOMENTE ❌
- **Impacto:** Dados do vita-crawl (Moodle, SIGAA, TOTVS, etc.) não aparecem nos endpoints normalizados
- **Fix:** Portal extract deve gravar em `academic_*` como os outros

### Bug 2: `/api/progress` lê da tabela `grades` legado
- **Problema:** Progress lê de `grades` (manual), ignora `academic_evaluations` (conectores)
- **Impacto:** Aluno conecta Canvas/WebAluno, notas importadas, mas progress não mostra
- **Fix:** Progress deve ler de `academic_evaluations`

### Bug 3: `qbank_disciplines` não está no Drizzle schema
- **Problema:** Tabela existe no Postgres mas não no schema.ts, acessada via raw SQL
- **Impacto:** Migrations podem quebrar, sem type safety, sem relações Drizzle
- **Fix:** Adicionar ao schema.ts

### Bug 4: Universidades hardcoded sem tabela
- **Problema:** 128 faculdades em arquivo .ts, sem API real, sem portais mapeados
- **Impacto:** Não dá pra mostrar conectores por faculdade no onboarding
- **Fix:** Criar tabela `universities` + `university_portals`, popular com dados mapeados

---

## 5. TABELAS NOVAS NECESSÁRIAS

### 5.1 `universities`
```sql
universities (
  id            text PRIMARY KEY,
  name          text NOT NULL,        -- "ULBRA Porto Alegre"
  fullName      text,                 -- "Universidade Luterana do Brasil"
  shortName     text,                 -- "ULBRA"
  city          text,
  state         text,                 -- "RS"
  type          text,                 -- "publica_federal" | "publica_estadual" | "privada"
  enameConcept  integer,
  createdAt     timestamp DEFAULT now()
)
```

### 5.2 `university_portals`
```sql
university_portals (
  id                text PRIMARY KEY,
  universityId      text REFERENCES universities(id),
  portalType        text NOT NULL,     -- "canvas" | "moodle" | "sigaa" | "totvs" | "sagres" | "lyceum" | "webaluno" | "phidelis" | "ulife" | "custom"
  connectorStrategy text NOT NULL,     -- "native_api" | "vita_crawl" | "hybrid"
  url               text NOT NULL,     -- "ulbra.instructure.com"
  authMethod        text NOT NULL,     -- "oauth" | "credentials" | "webview_cookies"
  capabilities      jsonb,             -- ["grades","schedule","files","assignments","attendance","financial"]
  isPrimary         boolean DEFAULT false,
  displayName       text,              -- "Canvas LMS" (o que o aluno vê)
  displayIcon       text,              -- nome do asset/ícone
  metadata          jsonb,             -- {version: "4.5", mobileApiEnabled: true, ...}
  confidence        text DEFAULT 'high', -- "high" | "medium" | "low"
  createdAt         timestamp DEFAULT now(),
  updatedAt         timestamp DEFAULT now()
)
```

### 5.3 `academic_attendance` (nova)
```sql
academic_attendance (
  id          text PRIMARY KEY,
  userId      text NOT NULL,
  subjectId   text REFERENCES academic_subjects(id),
  date        date NOT NULL,
  status      text NOT NULL,           -- "present" | "absent" | "justified" | "late"
  source      text,                    -- "canvas" | "moodle" | "sigaa" | "manual"
  createdAt   timestamp DEFAULT now()
)
```

---

## 6. MAPEAMENTO UNIVERSIDADES → PORTAIS

> 128 faculdades de medicina mapeadas via probes HTTP reais (2026-03-29).
> Dados completos em UNIVERSITY_PORTALS.md

### Resumo por tipo

| Portal | Qtd | Strategy | Auth | Capabilities garantidas |
|--------|-----|----------|------|------------------------|
| **Canvas** | 24 | native_api | oauth | grades, courses, assignments, files, calendar, quizzes, modules, announcements |
| **Moodle** | 20 | native_api | token (login/token.php) | grades, courses, assignments, files, calendar, forums, quizzes, badges |
| **SIGAA** | 25 | vita_crawl (UFRN: native_api) | credentials (CAS SSO) | enrollment, grades, schedule, attendance, history, materials, library |
| **TOTVS RM** | 5 | vita_crawl | credentials | grades, absences, schedule, financial, enrollment, materials |
| **Sagres** | 2 | vita_crawl* | credentials (ServiceStack) | grades, absences, schedule |
| **Lyceum** | 2 | vita_crawl* | credentials (JSESSIONID) | grades, absences, financial, enrollment, schedule, materials |
| **WebAluno** | 4 | vita_crawl | credentials/cookies | grades, schedule, history |
| **Phidelis** | 1 | vita_crawl | credentials | grades, absences, schedule |
| **Ulife** | 2 | vita_crawl | Microsoft SSO | grades, schedule |
| **Custom** | ~30 | vita_crawl | varia | descoberto na conexão |

> `*` Sagres e Lyceum têm REST APIs próprias — possível integração nativa futura

### Canvas instances (25 confirmadas)
```
ulbra.instructure.com          → ULBRA (4 campi)
pucminas.instructure.com       → PUC Minas
pucpr.instructure.com          → PUCPR
puc-rio.instructure.com        → PUC-Rio
unifor.instructure.com         → UNIFOR
unichristus.instructure.com    → UNICHRISTUS
uvv.instructure.com            → UVV
ucs.instructure.com            → UCS
univali.instructure.com        → UNIVALI
estacio.instructure.com        → ESTÁCIO
positivo.instructure.com       → UP (Univ Positivo)
usp.instructure.com            → USP
ufscar.instructure.com         → UFSCar
usf.instructure.com            → USF
unimar.instructure.com         → UNIMAR
unit.instructure.com           → UNIT
escs.instructure.com           → ESCS
kroton.instructure.com         → UNIDERP, UNIC, UAM
sereducacional.instructure.com → UNINOVAFAPI, UnP
animaeducacao.instructure.com  → UniBH
cesmac.instructure.com         → CESMAC
niltonlins.instructure.com     → NILTON LINS
mackenzie.instructure.com      → FEMPAR
afya.instructure.com           → UniSL
unir.instructure.com           → UNIR
```

### Moodle instances (20, 14 com mobile API ativa)
```
moodle.ufrgs.br         4.3.3   mobile=ON
moodle.ufcspa.edu.br    4.2.9   mobile=ON
moodle.pucrs.br         4.5+    mobile=ON
moodle.ufsc.br          ?       mobile=?
moodle.ufu.br           4.5+    mobile=ON
moodle.ufjf.br          4.3.8   mobile=likely
moodle.ufop.br          3.9.25  mobile=ON
moodle.pucsp.br         4.5+    mobile=ON
moodle.famema.br        ?       mobile=?
moodle.unirg.edu.br     ?       mobile=OFF
moodle.ufba.br          3.11.8  mobile=ON
moodle.uefs.br          4.5+    mobile=ON
moodle.unifap.br        4.5.8   mobile=likely
moodle.ufrb.edu.br      ?       mobile=?
moodle.uncisal.edu.br   5.1     mobile=?
ava.ufms.br             4.5+    mobile=ON
moodle.unesp.br         4.1.6   mobile=ON
moodle.ufabc.edu.br     4.5.8   mobile=ON
moodle.unifenas.br      ?       mobile=?
e-aula.ufpel.edu.br     5.0.2+  mobile=ON
```

---

## 7. O QUE O VITA (LLM) PRECISA SABER

Quando o aluno conecta um portal, o Vita precisa saber o que extrair. O `student-context` aggregator deve fornecer:

### 7.1 Contexto do aluno (para cada conversa)
```json
{
  "student": {
    "name": "João Silva",
    "university": "ULBRA Porto Alegre",
    "semester": 6,
    "course": "Medicina",
    "plan": "pro",
    "streak": 12,
    "level": 8
  },
  "enrollments": [
    {"name": "Farmacologia Médica I", "code": "MED306", "professor": "Dr. Santos", "credits": 4}
  ],
  "grades": [
    {"subject": "Farmacologia", "evaluations": [{"title": "G1", "grade": 7.5, "maxGrade": 10}]}
  ],
  "schedule": [
    {"subject": "Farmacologia", "day": "monday", "start": "08:00", "end": "10:00", "room": "Lab 3"}
  ],
  "upcomingExams": [
    {"title": "G2 Farmacologia", "date": "2026-04-15", "subject": "Farmacologia"}
  ],
  "flashcardsDue": 42,
  "studyPlan": {...},
  "recentActivity": [...]
}
```

### 7.2 Quando o aluno FALA algo no chat
Se o aluno disser: "Tirei 8.5 na G1 de Farmaco"
→ Vita extrai: `{subject: "Farmacologia", evaluation: "G1", grade: 8.5}`
→ Grava em: `academic_evaluations` com `source: "vita_chat"`
→ Aparece em: `/api/grades`, `/api/progress`, dashboard

Se o aluno disser: "Tenho prova de Patologia dia 15"
→ Vita extrai: `{subject: "Patologia", type: "prova", date: "2026-04-15"}`
→ Grava em: `academic_calendar` com `source: "vita_chat"`
→ Aparece em: `/api/calendar`, `/api/exams`, dashboard, notificações

### 7.3 Quando o vita-crawl scrapa um portal
O LLM recebe HTML bruto e deve extrair pra estas categorias:
```
enrollment  → academic_subjects
grades      → academic_evaluations
schedule    → academic_schedule
calendar    → academic_calendar
attendance  → academic_attendance
files       → documents
assignments → academic_evaluations (type=trabalho)
```

---

## 8. PRIORIDADES PRÉ-LANÇAMENTO

### P0 — Crítico (sem isso não lança)
1. [ ] Fix: `/api/portal/extract` gravar em `academic_*` (Bug 1)
2. [ ] Fix: `/api/progress` ler de `academic_evaluations` (Bug 2)
3. [ ] Criar tabela `universities` + popular 128 faculdades
4. [ ] Criar tabela `university_portals` + popular com mapeamento
5. [ ] Criar endpoint real `GET /api/universities` (com portais)
6. [ ] Onboarding: mostrar conectores da faculdade selecionada

### P1 — Importante (primeira semana)
7. [ ] Criar `/api/connectors` unificado
8. [ ] Adicionar `qbank_disciplines` ao Drizzle schema
9. [ ] Eliminar endpoints `mockup/*` (migrar chamadas)
10. [ ] Criar tabela `academic_attendance`
11. [ ] Moodle native API connector (14 instâncias com mobile API)

### P2 — Pós-lançamento
12. [ ] Eliminar tabelas legado (`grades`, `webaluno_grades`, `webaluno_schedule`)
13. [ ] SIGAA UFRN native API (OAuth2 registration)
14. [ ] Google Classroom connector
15. [ ] Lyceum native API connector
16. [ ] Sagres native API connector
17. [ ] Crowdsource: capabilities discovery per university
18. [ ] Microsoft Teams connector

---

*Este documento é o source of truth do VitaAI. Qualquer mudança na API, modelo de dados, ou conectores deve ser refletida aqui primeiro.*

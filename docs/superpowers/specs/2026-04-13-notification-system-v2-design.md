# VitaAI Notification System v2 — Design Spec

**Date:** 2026-04-13
**Status:** Approved
**Approach:** Smart templates with context queries (no LLM). Intelligence = right data at right time.

## Philosophy

- Event-driven > time-driven. Only notify when something real happened.
- Every notification contains user-specific data from the DB. Never generic.
- Max 1 proactive nudge/day. Events are unlimited (they're real).
- Anti-spam: deterministic IDs, dedup, frequency caps.
- Zero LLM for notifications. LLM stays in chat only.
- No false positives: only reference data that EXISTS in the DB.

## Notification Types & Triggers

### Event-Driven (real-time, from API endpoints)

| Type | Trigger Location | Context Query | Template Example | Route |
|------|-----------------|---------------|------------------|-------|
| `gradePosted` | portal/ingest (grade changes) | score, subject name | "Farmacologia: nota 8.5 publicada" | /study/grades |
| `newDocument` | portal/ingest (new files) | file count, subject name | "3 novos arquivos em Patologia" | /materiais |
| `newAssignment` | portal/ingest (new evals) | assignment title, subject, due date | "Novo trabalho: Relatório Anatomia — entrega 25/04" | /study/trabalhos |
| `sessionExpired` | cron/portal-sync (session test fail) | portal name | "Conexão com Canvas expirou. Reconecte para manter sync." | /settings/portals |
| `studioComplete` | studio/generate (async completion) | output type, topic | "Seus flashcards de Neurologia estão prontos (32 cards)" | /study/flashcards |
| `transcriptionComplete` | ai/transcribe (completion) | duration, title | "Transcrição finalizada: Aula Farmacologia (47 min)" | /study/transcricao |
| `simuladoResult` | simulados/{id}/finish | score, total, percentile | "Simulado finalizado: 68/100 questões corretas (68%)" | /simulados/{id}/result |
| `qbankSession` | qbank/sessions/{id}/finish | correct, total, topic | "Sessão QBank: 15/20 em Cardiologia (75%)" | /qbank |
| `badgeEarned` | achievements (POST) | badge name, description | "Badge conquistada: Madrugador — Estudou antes das 7h" | /achievements |
| `levelUp` | activity (POST response) | new level, XP | "Level Up! Você alcançou o nível 12 (2.400 XP)" | /achievements |

### Cron-Driven (scheduled, daily at 7h BRT)

| Type | Trigger | Context Query | Template Example | Route |
|------|---------|---------------|------------------|-------|
| `examAlert` | 7, 3, 1 days before | exam title, subject, days, flashcard count for subject | "Prova de Farma em 3 dias. 23 flashcards pendentes nessa matéria. [Revisar]" | /study/grades |
| `examDay` | Day of exam | exam title, subject, last study date, flashcard accuracy | "Hoje: G1 Farmacologia. Último estudo: ontem. Flashcards: 89% acerto. Vai tranquilo!" | /study/grades |
| `deadline` | 3, 1 days before assignment due | title, subject, days | "Entrega do Relatório de Anatomia em 1 dia" | /study/trabalhos |
| `flashcardDue` | Daily if cards pending | due count, top subject | "142 flashcards pendentes. Maior grupo: Patologia (45)" | /study/flashcards |

## Preference Mapping (no migration needed)

New types map to existing `notification_preferences` columns:

| New Type | Preference Column | Rationale |
|----------|------------------|-----------|
| `newDocument` | `classBriefing` | Class content |
| `newAssignment` | `deadline` | Deadline-related |
| `examDay` | `examAlert` | Exam-related |
| `sessionExpired` | (always notify) | Critical system event |
| `studioComplete` | `studyPlan` | Study content |
| `transcriptionComplete` | `studyPlan` | Study content |
| `simuladoResult` | `examAlert` | Exam practice |
| `qbankSession` | `examAlert` | Exam practice |
| `levelUp` | `badge` | Gamification |

## Context Query Builders

Each notification type has a `buildContext()` function that pulls relevant data:

```
examDay context:
  → academicEvaluations (exam for today)
  → flashcardDecks + flashCards (cards for this subject, accuracy)
  → userProfiles (lastStudyDate)
  → combine into template
```

All queries use existing Drizzle schema. No new tables.

## Anti-Spam Rules

1. **Deterministic IDs**: `{type}-{entityId}-{dateKey}` → onConflictDoNothing
2. **Event-driven**: no frequency cap (real events are never spam)
3. **Cron proactive**: max 1 proactive notification per user per cron run
4. **sessionExpired**: max 1 per 24h per connection
5. **WhatsApp**: existing rate limit (max 3/day via whatsappLastSent)

## Deep Links

All notifications include `route` field. iOS AppRouter already handles these paths.
Missing routes will be added as needed.

## Implementation Order

1. Update `vita-notifications.ts` — add type mapping to preference columns
2. Update `cron/notifications` — add examDay + deadline + enriched examAlert context
3. Update `portal/ingest` — add newDocument + newAssignment triggers
4. Update `cron/portal-sync` — add sessionExpired trigger
5. Wire API endpoints — simulado/finish, qbank/finish, studio, transcribe, achievements, activity
6. Smoke test each event type

## What's NOT in scope

- LLM-generated notification text (stays in chat only)
- iOS UI changes (bell popout already works, deep links already work)
- Notification preferences UI redesign
- Weekly digest / summary emails

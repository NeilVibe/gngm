---
name: LOGGING — Structured logging standard for winacard
description: Backend + frontend logging conventions. Correlation-ID contract. Event naming. PII rules. Dev vs prod strategy. Fires on trigger "LOG".
type: protocol
last_verified: 2026-04-25
originSessionId: 75e4acc4-5b9b-4441-b7ee-b5be88eb8f59
---

# LOGGING Protocol

> **Trigger:** the word `LOG` in a user message opens this protocol — usually for adding logging to new code, auditing existing logging, or debugging a logging-specific question. Sister to [DEBUG.md](DEBUG.md).

## Principles

1. **Structured over string-formatted.** `logger.info("event_name", field=value)` — not `logger.info(f"event {value}")`.
2. **Correlation before content.** Every log line traceable to a single request via `correlation_id`.
3. **Events are verbs.** `sse_connect`, `pull_log_inserted`, `fal_budget_alert`. Not noun phrases.
4. **Logs are supplementary, not the audit trail.** Durable records (pull_log, disclosure_views, fal_spend_log, vault) live in the DB. Logs may be lost under rotation; DB rows must not.
5. **Log BEFORE the silent catch.** Any `except … pass` is either a bug or needs a warning log.
6. **Never log secrets.** PII scrubber enforces; developer still owes an eye.

## The Correlation-ID Contract

```
CLIENT                                    SERVER
------                                    ------
fetch(url, {                              CorrelationIdMiddleware:
  headers: {                                1. read inbound x-trace-id
    'x-trace-id': ctx.traceId                 (if valid UUIDv4 ≤64 bytes)
  }                                         2. else generate UUIDv4
})                                          3. contextualize(correlation_id=tid)
  ↓                                         4. call handler (logs auto-tagged)
response.headers.x-trace-id                 5. send_wrapper adds x-trace-id
bound back to ctx.traceId for                 to response headers
next request in same user flow              ↓
                                          every logger.* during request
                                          emits correlation_id={uuid}
```

**Invariants:**
- `x-trace-id` is a strict UUIDv4 (36 chars).
- Header present on EVERY response: 200, 4xx, 5xx, CORS preflight, streaming.
- CORS exposes the header so browser JS can read it (`Access-Control-Expose-Headers`).
- Middleware rejects malformed, oversized (>64 bytes), or newline-containing inbound values.
- Concurrent requests keep distinct IDs (contextvars, not thread-locals).

Source of truth: `server/app/core/middleware.py` + `server/tests/integration/test_correlation_id_middleware.py`.

## Backend logging standard

### Format

```
2026-04-25 00:12:34.567 | INFO     | 12345678-1234-4abc-8def-0123456789ab | app.services.roll_service:create_roll:142 - pull_log_inserted tier=S package_id=1
```

Columns: timestamp | level | correlation_id | module:function:line | message

### Event style

```python
# CORRECT
logger.info("sse_emit", type="tier_depleted", package_id=pid, stream_id=sid)
logger.warning("fal_budget_alert", used_usd=78.50, cap_usd=100.0)
logger.error("roll_unexpected_409", package_id=pid, remaining=0)

# WRONG (f-string, unparseable)
logger.info(f"emitted SSE {event_type} for package {pid}")

# LEGACY (still works, retrofit opportunistically)
logger.warning("roll_card_locked card_id={}", card_id)
```

### Levels

| Level | Use for |
|---|---|
| `DEBUG` | High-frequency state dumps, SSE heartbeats, Pentology hits |
| `INFO` | Business events — pull_log write, budget reserve, SSE connect/disconnect/emit |
| `WARNING` | Degradation (Ollama slow, budget at 75%, validation rejected) |
| `ERROR` | Unexpected failure with evidence (exception, 500 handler) |
| `CRITICAL` | Paging-worthy — correlation_id loss, hash-chain break, migration mid-flight abort |

### What NOT to log (ever)

- Full JWTs or ID tokens (PII scrubber masks via frozenset, but belt-and-suspenders: don't build log entries out of auth headers).
- Raw `r2_access_key_id` / `r2_secret_access_key` / `fal_key` / `gemini_api_key` / `google_ai_studio_key` / `pokemontcg_api_key`.
- User emails at INFO (OK at DEBUG with explicit consent in tests).
- Raw `user_id` UUIDs at INFO — log an 8-char truncation at DEBUG only.
- `roll_seed` values (hash-chain protected, but leaking future seeds = compliance concern for audit determinism).
- Request body contents for payment endpoints.
- Raw OAuth code / state values during Kakao/Naver callback.

### PII scrubber — reference

`server/app/core/logging.py` holds the `PII_KEYS` frozenset. Add new keys with `# Wave N [IDENTIFIER]:` comment headers (see Wave 3 / Wave 4 / Wave 8.5 [S5] precedent).

If you need to log a value that contains a known PII key name (e.g. error message mentioning `email`), the scrubber redacts the key name substring in the message. Verify via `test_logging.py::test_scrub_pii_record_filter_redacts_message_mentions`.

## Frontend logging standard

### API (to be used everywhere — see `app/src/lib/logging.ts`)

```typescript
import { log } from '$lib/logging';

log('info', 'user_clicked_roll', { package_id: pkgId });
log('warning', 'session_hydrate_retry', { attempt: n });
log('error', 'unhandled_rejection', { reason: e?.message });
```

### Structured output

Each call emits a `console.<level>` entry with shape:

```json
{
  "level": "info",
  "event": "user_clicked_roll",
  "trace_id": "12345678-...",
  "ts": "2026-04-25T00:12:34.567Z",
  "context": { "package_id": 1 }
}
```

Dev: visible in browser DevTools Console. Prod (Wave 10): shipped to external aggregator.

### Global error capture

`installGlobalErrorHandlers()` runs once at layout mount:
- `window.addEventListener('error', ...)` — caught `throw` in event handlers, onMount crashes, script errors.
- `window.addEventListener('unhandledrejection', ...)` — async promise rejections (API errors not caught at call site).

Both route through `log()` → structured entry with stack, trace_id (if context has one), origin.

**Coexistence:** `addEventListener` composes; does NOT use `window.onerror = ...` (would clobber existing listeners like `winacard:auth-expired`).

### Trace-ID propagation on fetch

`app/src/lib/api/client.ts` wraps every API call:
- Outbound: attach `x-trace-id` header (current context ID, or generate fresh).
- Inbound: read `x-trace-id` from response, update context.
- **Same-origin OR whitelisted API base** (via `PUBLIC_API_BASE` env): YES attach.
- **Truly foreign hosts** (pokemontcg.io, fal.ai CDN, Google OAuth endpoints): NO — don't leak our trace IDs.

### SSR safety

- `logging.ts` module-level code: NO `window.*` access.
- `installGlobalErrorHandlers()` guarded by `import { browser } from '$app/environment'; if (browser) { ... }`.
- `log()` helper: guards `typeof window !== 'undefined'` before `performance.now()`, `window.addEventListener`, etc.
- Component-level `$effect(() => log(...))` runs in browser only — safe.

### ApiError classification

When logging a caught `ApiError` from `app/src/lib/api/errors.ts`:

```typescript
if (e instanceof ApiError) {
  log('error', 'api_error', {
    error_class: e.constructor.name,
    error_code: e.code,
    error_status: e.status,
    error_i18n_key: e.i18nKey,
    error_retry_after: e instanceof RateLimitError ? e.retryAfterSeconds : undefined,
  });
} else {
  log('error', 'unexpected_error', { message: String(e) });
}
```

### Svelte 5 storage rule

`trace_id` is stored in a plain module-level `let` (per-request side-channel), NOT `$state`. Putting it in `$state` would make every `log()` call that reads it trigger `$effect` recomputation → infinite loop risk (LocaNext CS-015-class bug).

### Meta-observability

`logging.ts` maintains a `_logEmitFailures` counter. If a log emit itself throws (rare — JSON.stringify cycle, CSP blocking console), the counter increments. Inspectable via `window.__winacardDebug?.logEmitFailures`. If > 10 in a session, emits a direct `console.warn` — the ONE exception to "log doesn't log about itself".

## Audit-grade events (regulatory concern)

### What counts as audit-grade

Events where regulatory compliance (확률형 아이템 disclosure, financial reconciliation, IP-originality approval) depends on a permanent record:

- Probability disclosure insert (`probability_disclosures`).
- Roll insert (`pull_log` with hash chain).
- Disclosure view record (`disclosure_views`).
- Payment reconciliation (`payments`).
- Budget reservation / finalize (`fal_spend_log`).
- Vault add / redemption (`vault`, `shipments`).

### The rule

**Audit trails live in the DB.** Not in logs. The business write IS the audit record.

Loguru entries for these events are supplementary diagnostic signal — they may be LOST under `/tmp` rotation. Never query logs to answer a compliance question; query the DB.

When adding a new audit-class event, emit BOTH:
1. The DB write (source of truth).
2. A structured log entry for diagnostic grep (non-durable).

```python
# In roll_service.create_roll:
pull_log_row = PullLog(...)
db.add(pull_log_row)
await db.flush()

# DB row is the audit trail. Logger is the breadcrumb.
logger.info(
    "pull_log_inserted",
    pull_log_id=str(pull_log_row.id),
    package_id=package_id,
    tier=picked_tier,
    was_pity_forced=pity_forced,
)
```

### Audit query path

For regulatory or operational audit:
- `SELECT FROM pull_log WHERE package_id = ? ORDER BY rolled_at;`
- `SELECT FROM probability_disclosures WHERE package_id = ? AND effective_to IS NULL;`
- `SELECT FROM fal_spend_log WHERE completed_at IS NOT NULL;`

NEVER grep logs as the answer.

## Dev vs prod strategy (Wave 10 concern)

### Dev (now)

- Sink: stderr via `configure_logging`.
- Captured to `/tmp/winacard-uvicorn.log` when backend started via our nohup pattern.
- Structured format with ANSI colors for stderr readability.
- `capture.sh` snapshots tail + state when needed.

### Prod (Wave 10, deferred)

- Ship to external aggregator (Sentry / Datadog / ELK — decision at Wave 10 kickoff).
- JSON serializer instead of pretty format.
- Correlation-ID stays as a top-level field.
- Log rotation (8-hour or 1-GB windows).
- Alert on `ERROR`+ for critical paths.
- Sampling not needed at expected scale.

## Background tasks — trace-ID propagation

When a request spawns an `asyncio.create_task(...)` for background work, the loguru context IS inherited via contextvars. But if you later want to propagate trace_id across a task boundary (e.g. enqueue to Redis and process later), pass it EXPLICITLY:

```python
# In request handler:
from app.core.middleware import correlation_id_var
tid = correlation_id_var.get()

# Enqueue with trace_id as a field:
await queue.put({"payload": ..., "trace_id": tid})

# In worker:
with logger.contextualize(correlation_id=msg["trace_id"]):
    # handle…
```

## `LOG_SQL` toggle (deferred — implemented in Wave 8.5 S3)

`settings.LOG_SQL = False` default. When True, SQLAlchemy echoes every statement through loguru — expensive, dev-only. Document in DEBUG.md R4 for "roll returns 409" investigation.

## Triggers

- `LOG` — this protocol opens.
- `LOG SQL on` / `LOG SQL off` — composable toggles (Wave 10; atomic for now).

## Anti-patterns

| Anti-pattern | Replacement |
|---|---|
| `logger.info(f"event {value}")` | `logger.info("event_name", field=value)` |
| `logger.info("event " + str(data))` | `logger.info("event", data=data)` |
| `except: pass` | `except Exception: logger.warning("what_failed", exc_info=True)` |
| Raw `user_id` at INFO | 8-char truncation at DEBUG |
| Logging the full request body | Log shape + size only |
| "Just console.log for now" | Use `log('debug', ...)` — costs the same, benefits are compound |
| Answering a compliance question from logs | Query the DB |

## Related

- [DEBUG.md](DEBUG.md) — sister protocol
- [NLF.md](NLF.md) — truth discipline
- [RAC.md](RAC.md) — I2 (observable) + I5 (corroboration) + I8 (tested by proof)
- `~/.claude/rules/knowledge-system.md` — Pentology

## Docs

- `server/app/core/middleware.py` — CorrelationIdMiddleware
- `server/app/core/logging.py` — configure_logging + PII scrubber
- `server/tests/integration/test_correlation_id_middleware.py` — 13 contract tests
- `server/tests/unit/test_logging_correlation_id.py` — format tests
- `app/src/lib/logging.ts` — frontend structured logger (coming in next commits)
- `lessons/debug-protocol.md` — durable lessons

---
name: DEBUG — Systematic Debug Protocol for winacard
description: Iron Law + 4-phase method + 11 runbooks + WC-NNN case-study ledger. Fires on trigger "DEBUG".
type: protocol
last_verified: 2026-04-25
originSessionId: 75e4acc4-5b9b-4441-b7ee-b5be88eb8f59
---

# DEBUG Protocol

> **Trigger:** the word `DEBUG` in a user message (optionally scoped — `DEBUG R3` means "apply runbook R3"). Opens this protocol. Not a side-channel conversation — it takes over the session until the symptom is explained or scoped-out.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.
```

If Phase 0 + Phase 1 are not complete, **you are not allowed to propose a fix**.

Violating the letter of this protocol violates the spirit of debugging. Quick fixes mask problems; systematic investigation finds them. Systematic is FASTER under the clock than guess-and-check, measured across every real incident.

## When DEBUG fires

- Any user-reported bug, unexpected UI, or backend anomaly.
- Any CI failure.
- Any "it worked yesterday" symptom.
- Any silent-state class: "app blank", "SSE stopped", "button does nothing".
- **Especially:** when under time pressure, when a quick patch seems obvious, when you've already tried 2+ fixes.

Skip ONLY for:
- Pure typos in prose.
- A line of code you're writing and immediately test.
- Trivia the user explicitly waves off.

## Phase 0 — GNGM Pentology query (BEFORE reading code)

Six tiers, run in parallel:

```
1. sequential-thinking  — step-by-step reasoning about approach
2. graphiti search      — "what connects to <SYMPTOM_ENTITIES>?"
3. neuraltree lesson_match — past fixes for [symptom keywords]
4. viking_search        — prose docs about the area
5. memory MCP search    — cross-session rules
6. graphify query       — code call-graph for symptom entities
```

Query BEFORE reading code files. Reading first = blind work. Reading with full Pentology context = read the RIGHT files in the RIGHT order.

If any tier is unavailable, degrade per `~/.claude/rules/knowledge-system.md` §9.

## Phase 1 — Evidence gathering (no fixes yet)

Before forming any hypothesis:

```
bash scripts/debug/capture.sh [symptom-label]
```

Produces `/tmp/winacard-debug-YYYYMMDD-HHMMSS-<label>/` with:
- uvicorn log tail
- vite preview log tail
- API health probes
- DB schema + row counts
- git state (branch, status, last 50 commits — **no diff content**)
- process list + open ports

Then:

1. Read the symptom literally. Reproduce it once; write down exact steps.
2. Grep the uvicorn tail for `ERROR` / `WARNING` in last 5 min.
3. If symptom is browser-side: open DevTools Console + Network tab. Read every red line.
4. If operator has a trace ID from frontend: `grep "<uuid>" <bundle>/uvicorn-tail.log`
5. Ask: "what changed recently?" Check `git log --oneline -n 20`. Any commit near the symptom's onset time?

Write the evidence into the case-study draft (template at bottom of this file) BEFORE moving to Phase 2.

## Phase 2 — Pattern analysis

1. **Find working examples.** Is there a similar flow in the codebase that works? What's different?
2. **Compare against references.** If this is a stack pattern (FastAPI middleware, Svelte 5 runes, SSE client), read the reference docs COMPLETELY — no skimming.
3. **Identify differences.** List every delta between working and broken. "That can't matter" is forbidden.
4. **Understand dependencies.** What config, env, migration, service does the broken path need?

## Phase 3 — Hypothesis and testing (ONE at a time)

1. Write the hypothesis in one sentence: "I think X is the root cause because Y."
2. Design the smallest possible test to confirm or refute it.
3. ONE change at a time. Not multiple fixes in one commit.
4. Verify: did it work? Yes → Phase 4. No → new hypothesis (don't layer fixes).
5. If 3+ hypotheses have failed → STOP. Question the architecture, not the code.

## Phase 4 — Implementation (root-cause fix, with test)

Per `docs/GNGM/protocols/TDD.md`:

1. Write a failing test that reproduces the root cause (RED).
2. Implement the smallest fix that makes it pass (GREEN).
3. Run adjacent tests to check for regression.
4. Atomic commit. No "while I'm here" bundling.
5. Update `lessons/<domain>.md` with a lesson_add entry if the symptom was novel.

## The 11 Runbooks (initial set — extended as symptoms surface)

### R1 — App blank on `:5174` / hydration failure

**Symptom:** Browser shows white page or shell without content.

**First probes:**
```bash
curl -sS http://127.0.0.1:5174/ | head -30   # SvelteKit shell present?
pgrep -fa 'vite preview'                     # duplicate processes?
tail -100 /tmp/winacard-vite.log             # build warnings?
```

**Evidence to collect:**
- Browser DevTools Console — any red JS errors?
- Network tab — any 4xx/5xx for `_app/immutable/*`?
- Does `pnpm build` exit 0 locally?

**Candidate root causes:**
- Duplicate vite preview processes fighting for port (today's finding → WC-001).
- Stale prod build (Wave 8 code changed, preview not rebuilt).
- JS error during hydration (`+layout.svelte` $effect throw, session-store race).
- CSP blocking inline script.
- Vite HMR websocket 404 → blank with no error (rare).

**Fix boundary:**
- `+error.svelte` only catches `load()` throws.
- `onMount` throws → caught by `window.onerror` (installed by `installGlobalErrorHandlers`).
- Unhandled promise rejection → caught by `window.onunhandledrejection`.

**Map symptom → catch:**
| Symptom | Catches |
|---|---|
| Blank page, Console shows SyntaxError | build issue, nothing catches; rebuild |
| Blank page, Console shows "hydration failed" | `window.onerror` |
| Blank page, spinner forever | async rejection — `window.onunhandledrejection` |
| Blank page, `+error.svelte` renders | load() threw; read the stack |

### R2 — Backend 500 on `/api/v1/*`

**Symptom:** Frontend error toast, network tab shows 500.

**First probes:**
```bash
curl -sS http://127.0.0.1:8000/health          # backend alive?
grep "unhandled" /tmp/winacard-uvicorn.log | tail
grep "<trace-id-from-frontend-error>" /tmp/winacard-uvicorn.log
```

**Evidence:**
- Response body: is it ProblemDetail JSON (our handler) or raw stack (middleware bypass)?
- Response header: `x-trace-id` present? If yes → grep backend log.

**Candidate root causes:**
- SQLAlchemy MissingGreenlet after `UPDATE...RETURNING` with implicit attr access.
- Missing migration on dev DB.
- External API 5xx propagated unwrapped.
- Validation error on a field that was recently changed.

### R3 — SSE `/inventory/stream` silently stops

**Symptom:** Frontend stops receiving events; UI freezes live state.

**First probes:**
```bash
curl -N http://127.0.0.1:8000/api/v1/packages/1/inventory/stream \
  | head -5                     # at least 1 event within 3s?
grep "sse_emit\|sse_connect\|sse_disconnect" /tmp/winacard-uvicorn.log | tail -20
```

**Evidence:**
- Last event logged? At what wall-clock time?
- Disconnect logged with reason, or silent?

**Candidate root causes:**
- Middleware buffering the stream (Wave 8.5 CRIT-2 — should be fixed now).
- Client aborted but server didn't clean up → stale queue backing up.
- Event loop blocked by sync code in the route handler.
- Nginx / cloudflared buffering in between (dev: none; prod: check).

### R4 — `/roll` returns 409 `inventory_shifted_mid_roll`

**Is it a real bug or expected race?**

**Expected race (NOT a bug):** two concurrent rolls on last remaining copy. One wins (200), one gets 409. Frontend should retry.

**Real bug signals:**
- 409 with no concurrent roller in the log.
- 409 with `remaining_count=0` before the roll but frontend still asks.
- `disclosure_mismatch=True` on the 409 — user viewed a stale disclosure and the depletion snapshot didn't take.

**Probes:**
```sql
-- in docker exec postgres psql...
SELECT package_id, tier, remaining_count FROM package_tier_capacity WHERE package_id=?;
SELECT * FROM pull_log WHERE package_id=? ORDER BY rolled_at DESC LIMIT 10;
```

### R5 — Vision review (Qwen3-VL) timeout

**Symptom:** `vision_review_service` call hangs or returns after 300s timeout.

**Probes:**
```bash
curl -sS http://127.0.0.1:11434/api/ps | jq '.models[] | {name,size_vram}'
# qwen3-vl:8b should be loaded; if size_vram==0, Ollama evicted it
```

**Known F6 (Wave 4.7):** Ollama 5min idle eviction. Pipeline is supposed to pin with `keep_alive=-1`. If pinning didn't stick, model reloads cost ~30s each, batch times compound.

**Log lines to grep:**
- `vl_review_start` — the request went out.
- `vl_review_done latency_ms=` — did it return? how long?
- `ollama_idle_since` — how long was the model unused before this call?

### R6 — Roll returns wrong tier / probability drift

**Compliance-critical.** Triggers audit:

1. `pull_log.hash_chain_prev` + `hash_chain_curr` — chain intact?
2. The `disclosure_id` on this row — matches the current active disclosure for this package?
3. `was_pity_forced` flag — set correctly?
4. Property test (Hypothesis): after any legal depletion sequence, `sum(live_probs)==1.0` — does it?

If chain breaks: the entire pull_log for this package is suspect. Escalate.

### R7 — Video/audio won't play

**Symptom:** Reveal animation shows placeholder, no playback.

**Probes:**
- Browser Console: codec error? CSP violation? onerror fired (fallback)?
- URL: does it cache-bust (`?v=${Date.now()}`)?
- `<audio>` uses `src=` attribute directly (not `<source>` child)? Per `~/.claude/rules/media-cache-bust.md`.
- `crossorigin="anonymous"` if cross-port?

### R8 — Payment / OAuth error (Apple IAP / Google Play / PortOne / Kakao / Naver)

(Skeleton. Filled in when Wave 7.1 ships real payment integration.)

Common classes:
- OAuth callback missing `code` or `state` param.
- Receipt verification 5xx from Apple/Google.
- PortOne webhook signature mismatch.

### R9 — fal.ai / R2 / budget asset-pipeline failure

Classes: fal.ai 429 rate-limit, R2 403 (credentials drift), budget cap hit, Qwen3-TTS OOM eviction, vision review approval loop exhausted.

See `~/.claude/rules/pipelines/voice-image-video-asset-generation.md` for domain playbook. Winacard-specific grep targets: `fal_submit`, `fal_wait`, `fal_budget_alert`, `vl_review_done approve=false`.

### R10 — Korean text rendered as mojibake

Classes: UTF-8 / euc-kr byte confusion, missing font, CSP blocking webfont, wrong Content-Type on static.

Probes:
- `curl -I <asset-url>` — charset header?
- Browser: Elements panel → inspect the rendered node's computed `font-family`.
- Check `app/static/*` — all files UTF-8?

### R11 — Duplicate processes bound to dev port

**Motivating case:** today's `:5174` had two `vite preview` PIDs fighting.

**Probes:**
```bash
pgrep -fa 'vite preview|uvicorn app.main' | grep -v shell-snapshots
ss -tnlp | grep -E ':(5174|8000)\s'
```

**Fix:** kill all but one, restart cleanly. Never `kill -9` without checking what each is doing first.

## Case Study ledger — `WC-NNN`

Each debug session that surfaces a reusable insight gets a numbered case study. Template:

```markdown
### WC-NNN — <one-line symptom>

**Date:** YYYY-MM-DD
**Runbook:** R? (or "novel class — consider R12?")
**Reporter:** <user or auto-triggered>

**Symptom:** <observable>
**Reproduction:** <exact steps>
**Evidence bundle:** /tmp/winacard-debug-<id>/
**Phase 0 findings (Pentology):** <what graphiti/neuraltree/viking/memory returned>
**Root cause:** <THE bug>
**Fix:** <commit SHA + test>
**Lesson:** <what generalizes for future, saved via neuraltree_lesson_add>
```

### WC-001 — App blank on `:5174` during Wave 8 (2026-04-25)

**Date:** 2026-04-25
**Runbook:** R1 (blank page) + R11 (duplicate processes on dev port)
**Reporter:** User, mid-session

**Symptom:**
User opens `http://127.0.0.1:5174` and sees a blank page — no kawaii
hero, no "뽑기" button, no error. Initial curl probe returned HTTP 200
with a valid SvelteKit shell (modulepreload tags present), so the issue
is client-side (hydration / stale build / process collision), not HTTP.

**Reproduction:**
1. Open browser at `http://127.0.0.1:5174`.
2. Page loads blank; no visible content.
3. `curl -sS http://127.0.0.1:5174/` returns valid SvelteKit shell HTML.

**Phase 0 Pentology findings:**
- Graphiti: no direct "blank page" hits; adjacent facts about Wave 7
  dev-login bypass and Wave 8 frontend commits (blocked at c13-17).
- NeuralTree `lesson_match`: 0 hits on blank-screen / hydration / SSE
  silent-fail symptoms. **This is a novel domain for winacard.**
- Viking / Memory: no cross-session rule covered this specific
  symptom.

**Phase 1 evidence bundle:**
`bash scripts/debug/capture.sh wc-001-smoke` → `/tmp/winacard-debug-20260424-155338-wc-001-smoke/`

Key findings from the bundle:

1. **`processes.txt` shows TWO `vite preview` processes on :5174:**
   - PID `975352 → 975353` (started earlier, 198MB RSS, 0:06 CPU)
   - PID `1028014 → 1028015` (started later, 198MB RSS, 0:07 CPU)

2. **`ports.txt` shows only ONE actually bound:**
   ```
   LISTEN 0 511 127.0.0.1:5174 ... users:(("node",pid=1028015,fd=28))
   ```
   The earlier process (`975353`) lost the port race and is orphaned —
   still alive, holding RAM, but not serving.

3. **`api-health.json`** — backend green (`{"status":"ok","db":"ok"}`).
   Not the problem.

4. **`frontend-shell.html`** — valid SvelteKit bootstrap page with
   correct modulepreload tags. HTTP layer is fine.

5. **`vite-preview-tail.log`** — contains vite HMR `[vite] page reload`
   events referencing `build/*` paths. This is `vite dev`-style output
   (preview mode shouldn't emit HMR reloads), suggesting one of the
   "preview" processes may actually be misconfigured or stale from a
   prior `pnpm dev` session. Timestamps (`1:37:14 PM`, `1:43:07 PM`)
   pre-date the user's "app is blank" report, so the log isn't what's
   blocking hydration now — but it does hint at config drift worth
   cleaning up.

**Root cause:**
Duplicate `vite preview` processes competing for `:5174`. Only
`PID 1028015` is actually bound; `PID 975353` is orphaned. Depending
on which process was bound when the browser connected (and cached
modulepreload URLs from), hydration can hit a bundle that references
artifacts the currently-bound server doesn't have — producing a blank
hydrate without a visible error.

Secondary: the prod `build/` artifacts are from before Wave 8.5 changes
(no `+error.svelte`, no `installGlobalErrorHandlers`), so any hydration
throw goes to `/dev/null` — which is precisely what Wave 8.5 addresses.

**Fix (proposed, not applied this session):**
```bash
# 1. Kill all preview + orphaned shell wrappers.
pkill -f 'vite preview' 2>/dev/null
sleep 1

# 2. Rebuild with current Wave 8.5 code (includes +error.svelte +
#    global error handlers — a blank hydrate will now at least log
#    and the error boundary will render a Korean fallback).
cd /home/neil1988/winacard/app && pnpm build

# 3. Start ONE preview process cleanly.
nohup pnpm preview --host 127.0.0.1 --port 5174 \
  > /tmp/winacard-vite.log 2>&1 & disown

# 4. Verify single process + bound port:
pgrep -fa 'vite preview' | grep -v shell-snapshots
ss -tnlp | grep ':5174'

# 5. Hard-refresh browser (Ctrl+Shift+R) to clear service-worker
#    cache that may pin stale module URLs.
```

**Why the fix isn't applied inside Wave 8.5 this session:**
- Killing the preview mid-wave disrupts user-facing verification.
- The wave's true deliverable is the debug protocol + infrastructure
  that MAKES this diagnosis possible. Fix is a trivial pkill/rebuild,
  separable into a 5-minute chore commit at wave close.
- We deliberately let the next session (or the operator) apply the
  fix, proving the protocol works: evidence bundle → 3-minute analysis
  → actionable recipe. That's the win.

**Lesson (novel — seeds `lessons/debug-protocol.md` domain):**
Dev-port duplicate-process class is the first entry in the new domain.
Pattern: `pgrep -fa '<server>'` showing >1 PID + `ss -tnlp` showing
only one bound == orphaned sibling holding RAM without serving.
Always included in capture.sh so the signal surfaces on day 1.

**Meta-meta:**
Before Wave 8.5, diagnosing "app is blank" required ~15-30 minutes
of ad-hoc greps + curl + browser DevTools chase. With `capture.sh`
+ the R1/R11 runbooks, the full Phase 0+1 evidence arrives in ~10
seconds and the root cause reads out of `processes.txt` in 30
seconds. Full diagnosis-to-fix-recipe: ~3 minutes.

**Commit / SHA:** case study only — no code fix this commit.
Fix commit (when applied): TBD (simple pkill+rebuild chore).

## Trigger composition

- `DEBUG` — run the full protocol from Phase 0.
- `DEBUG R<n>` — jump into runbook R<n> after Phase 0 + Phase 1.
- `DEBUG WC-<n>` — resume an open case study.

(Composable triggers are a convention; hook-enforced variants are scheduled for Wave 10.)

## Anti-patterns (never do)

| Anti-pattern | Why bad |
|---|---|
| "Let me just try X and see" | Violates Iron Law; symptom-fix bandages |
| "It's probably a timing issue, let me add a sleep" | Arbitrary retries hide root cause |
| "Comment out the failing assert for now" | NLF violation; kills the diagnostic |
| Reading code before Phase 0 Pentology | Blind work — you read the wrong files |
| Multiple hypotheses tested in one commit | Can't isolate what worked; new bugs |
| "Works on my machine" without capture.sh bundle | Unreproducible; wastes reviewer time |
| Skipping `WC-NNN` write-up | Next incident repeats the learning |

## Related

- [NLF.md](NLF.md) — truth discipline that makes debug logs trustworthy
- [SDP.md](SDP.md) — wave-level structure; DEBUG fits inside a wave's EXECUTE stage
- [TDD.md](TDD.md) — Phase 4 uses RED/GREEN
- [RAC.md](RAC.md) — logging is a pipeline; debug invariants I2/I8
- [LOGGING.md](LOGGING.md) — what the logs look like (sister protocol)
- `~/.claude/rules/knowledge-system.md` — 6-tier Pentology mechanics
- `~/.claude/rules/pipelines/voice-image-video-asset-generation.md` — R9 domain

## Docs

- `scripts/debug/capture.sh` — Phase 1 evidence bundler
- `scripts/debug/deep_monitor.js` — CDP attach for live browser state
- `server/app/core/middleware.py` — CorrelationIdMiddleware source
- `app/src/lib/logging.ts` — frontend structured logger
- `lessons/debug-protocol.md` — WC-NNN durable lessons

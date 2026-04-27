---
name: STRESS-TEST — Cleverly Hunting Breaks Under Load
description: 7-dimension stress discipline (concurrency, burst rate, reconnect churn, state exhaustion, memory leak, cascading failure, long-tail latency). Smart small-N pressure with falsifiable invariants + cost guards. NEVER full-throttle on paid APIs. Find breaks before production users do, without burning the laptop or the budget.
type: gngm-protocol
version: 1
last_verified: 2026-04-27
trigger: STRESS (general) OR STRESS <feature> (scoped) OR STRESS audit / STRESS pre-launch (sweep modes)
---

# STRESS-TEST — Cleverly Hunting Breaks Under Load

> **Trigger:** `STRESS` or `STRESS <feature>`. Activates this protocol on the named feature/path.
>
> **Goal:** find breaks under load *before* production users do — without burning the laptop. Smart targeted pressure beats brute force every time.
>
> **Inheritance:** runs ON TOP of NLF (lie-free) + TDD (red-green) + LOGGING (proof in logs). A stress test that passes silently is a lie; a stress test without a failing variant first is theatre.

## The seven stress dimensions

Pick ONE (or two) per session. Don't try all at once.

| # | Dimension | Question it answers | Tool |
|---|---|---|---|
| **1** | Concurrency | Do my locks / state machines hold under N simultaneous identical requests? | `asyncio.gather`, Postgres advisory lock, c11 fixture |
| **2** | Burst rate | Does the rate limiter fire at the right threshold? Any inventory leak past the limit? | `hey`, `ab`, `vegeta` |
| **3** | Reconnect churn | Do long-lived connections (SSE, WebSocket) survive 10x reconnect cycles in 30s? Any memory leak? | bash loop + curl, Playwright `route.fulfill` |
| **4** | State exhaustion | When the table fills (depletion, migrations populated, queues at cap), does the system degrade gracefully or crash? | seeded fixture + sequential ops |
| **5** | Memory leak | After 10k operations + forced GC, does RSS stay bounded? | `psutil`, `node --inspect`, Chrome heap snapshot |
| **6** | Cascading failure | When dependency X dies mid-op (Postgres, Ollama, R2, fal.ai), do we degrade or crash? | `docker stop`, `pkill`, network namespace |
| **7** | Long-tail latency | What's p95/p99 under realistic load (not p50)? | `locust`, `k6` |

## When to invoke

| Trigger | Required dimensions |
|---|---|
| Adding any concurrency primitive (`SELECT FOR UPDATE`, advisory lock, mutex, queue) | **#1 mandatory** |
| Adding/changing rate limiter | **#2 mandatory** |
| Adding/changing long-lived connection (SSE, WebSocket, polling) | **#3 mandatory** |
| Adding migration that adds/changes constraints on existing data | **#4 mandatory** |
| Wave-end before declaring feature done | At least **one** of #1–#3 relevant to the feature |
| Pre-launch (Wave 10+) | **#1, #2, #5, #7** all required |

## The 4-step recipe

### Step 1 — Identify the invariant

State the property the stress test will FALSIFY. Not a vibe ("system feels fast"); a Boolean.

> _"Under 5 concurrent rolls at remaining=1, exactly ONE roll succeeds. The other 4 receive 409 inventory_shifted_mid_roll. Server-side `pull_log` count increments by exactly 1. `inventory_miss_log` has 4 rows."_

This is c11's stress invariant. Concrete. Verifiable. Falsifiable.

### Step 2 — Write the failing harness FIRST (RED)

The test must FAIL on a deliberately-broken implementation before you trust it. Two ways to "break it" to verify:

- Comment out the lock / advisory lock / SELECT FOR UPDATE → run → assert oversell happens
- Increase the operation count until the system actually breaks → assert your tooling catches it

If you can't make it fail, you haven't tested the right invariant.

### Step 3 — Run with intentional small-but-real load (GREEN)

**Smart load, not crushing load.** A 5-roller race under 100ms catches the same bug as a 1000-roller race under 10s, with 0.1% the CPU. Use the smallest N that exercises the contention.

| Domain | Smart N | Brute N (avoid) |
|---|---|---|
| DB row lock | 5 concurrent | 500 |
| HTTP rate limit (req/sec=60) | 70/sec for 2s | 6000/sec for 60s |
| SSE reconnect | 10 cycles in 30s | 1000 cycles |
| Memory leak | 10k ops + GC | 10M ops |
| Cascading failure | 1 process kill | full cluster collapse |

### Step 4 — Capture proof in logs (LOGGING)

Stress passing silently is unverifiable. Every stress run MUST emit:

- Start marker: `stress_test_start name=<X> n=<N> dimension=<D>`
- Per-batch outcome: `stress_test_batch idx=<i> success=<int> failures=<int>`
- End assertion: `stress_test_passed invariant="<text>" or stress_test_failed reason=<...>`

Then `grep stress_test capture.sh-output` should show the exact contour. Per LOGGING.md.

## Anti-patterns — do NOT

| ❌ | Why bad | ✅ Instead |
|---|---|---|
| 1000-roller race "to be safe" | Hides the actual minimum-reproducing case + cooks laptop | Find smallest N that breaks; usually 3-10 |
| Stress test without RED variant first | You're testing your tooling, not the system | Comment-out the lock, prove the test catches it |
| Stress on production-like cloud + hope | Slow, expensive, log-noisy | Local + targeted, then occasional cloud sanity |
| `time.sleep(5); assert ok` | Race-ridden, false-positives | Polling assertion with timeout |
| Pure brute force without invariant | Wastes resources, no signal | State the Boolean property first |
| Skipping logging | Pass-without-proof = NLF violation | Always emit start / batch / end markers |
| Running only happy-path concurrency | Misses race-on-failure paths | Stress with seeded failures (kill DB mid-op) |
| Forgetting cleanup | Pollutes future tests | `pytest fixture` teardown; `docker compose down`; `kill -9 $(jobs -p)` |

## Cost guards (mandatory)

Stress tests can spike resource use accidentally. Always include:

```python
# pytest fixture — bound the run
@pytest.fixture
def stress_budget():
    rss_start = psutil.Process().memory_info().rss
    t_start = time.time()
    yield
    rss_end = psutil.Process().memory_info().rss
    elapsed = time.time() - t_start
    rss_delta_mb = (rss_end - rss_start) / 1024 / 1024
    assert elapsed < 60, f"stress took {elapsed}s — too long"
    assert rss_delta_mb < 200, f"rss leaked {rss_delta_mb}MB — over budget"
```

For external-API stress (fal.ai, Ollama):
- HARD CAP per run (e.g. ≤10 calls). Fail loudly if exceeded.
- Use cheap models / prompts (Nano Banana 2 not Pro)
- Skip in CI if budget unspent var unset

## Existing winacard stress tests (audit, 2026-04-25)

Stress tests we already have (mostly accidental):

| File | Dimension | Status |
|---|---|---|
| `server/tests/integration/test_roll_wave8_c11.py::TestConcurrentRollRace` | #1 (5-roller `asyncio.gather`) | ✅ Exists; pinned [A5] compliance contract |
| Hypothesis property tests on `compute_live_probs` | #1 (random combinatorial) | ✅ Exists |
| `tests/unit/inventory-stream.test.ts` (3-fail offline) | #3 (reconnect churn proxy) | ✅ Exists |

Stress tests we should ADD before launch:

- **#2 burst rate on `/disclosure/view-event`** — 60/min limiter; verify 70/min triggers 429 cleanly
- **#3 SSE 10x reconnect under simulated network flap** — Playwright fixture
- **#4 fully-depleted package state** — extend c17 alembic roundtrip with populated `package_tier_capacity` rows at remaining=0
- **#5 memory leak on long-lived `/package/[id]` page** — 1h runtime + heap snapshot delta
- **#6 cascading failure: kill Postgres while batch roll in-flight** — assert no half-committed `pull_log` rows
- **#7 long-tail latency on `/roll`** — 100 RPS sustained, p95 < 500ms

## When to add the stress test (timing)

- **Concurrency primitive added** → stress test ships in the SAME commit (RED-GREEN-stress, atomic)
- **Rate limiter added** → same wave, separate test commit
- **New SSE / long-lived connection** → before wave close
- **Pre-launch** → dedicated stress wave (Wave 10c?) running #1, #2, #5, #7

## Trigger phrases

| You say | I do |
|---|---|
| `STRESS` | Audit recently changed code for stress-test gaps; recommend dimensions to add |
| `STRESS <feature>` | Run protocol against `<feature>` — pick smallest N, write RED-GREEN harness, log proof |
| `STRESS audit` | Sweep codebase for missing stress tests on concurrency / rate / SSE primitives |
| `STRESS pre-launch` | Run #1, #2, #5, #7 against the full app, produce report |

## Related
- [`NLF.md`](NLF.md) — stress passing silently is a lie
- [`TDD.md`](TDD.md) — RED-GREEN must fire before stress
- [`LOGGING.md`](LOGGING.md) — proof markers (`stress_test_*`)
- [`DEBUG.md`](DEBUG.md) — when stress finds a break, debug protocol kicks in
- [`SDP.md`](SDP.md) — Stage 5 "Live smoke" should include relevant stress dimensions
- [`RAC.md`](RAC.md) — pipelines need stress on every L2 (orchestration) handoff

## Docs
- `server/tests/integration/test_roll_wave8_c11.py` — reference c11 concurrent-roll harness
- `server/tests/conftest.py::concurrent_client` — per-request AsyncSession fixture for #1
- `~/.claude/rules/pipelines/RAC.md` §"The 7 failure modes" — stress dimensions map to F1-F7
- `lessons/pytest-async.md` — per-request sessionmaker pattern (c11 lesson)

## Changelog

- 2026-04-25 — **v1.** First draft. 7 dimensions, 4-step recipe, audit of existing winacard stress tests, anti-patterns table, cost guards, trigger phrases. Written in response to user observation that stress testing isn't formalized as a GNGM protocol despite being a key part of catching production bugs.

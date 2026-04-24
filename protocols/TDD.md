# TDD — Test-Driven Development + First-Debug Protocol

Two complementary patterns in one doc:

1. **TDD (baseline)** — Write the test first; prove the change with RED → GREEN.
2. **TDD-First Debug Protocol (heavy variant)** — For production bug fixes from logs, 6 disciplined steps; no implementation until proof exists.

---

## Part 1 — TDD baseline (used in SDP Step 4)

For every code change that matters, write a test that expresses the expected behavior BEFORE writing the implementation.

### The RED → GREEN cycle

```
1. Write a test that FAILS now (RED)
   - The failure mode defines the expected behavior
   - Without this, "passing" has no baseline

2. Apply the code change
   - The actual fix/feature

3. Run the test — it PASSES now (GREEN)
   - Proves the change works as intended

4. Run a quick smoke test
   - Nearby tests still pass
   - Imports still work
   - Nothing obvious broke
```

### The certificate

Every change records its evidence:

```
TDD CERTIFICATE:
  Change: [what was changed, 1 line]
  Test:   [test name]
  RED:    [test FAILED - expected X got Y]
  GREEN:  [test PASSED]
  Smoke:  [import OK, N nearby tests passing]
```

When a RED→GREEN cycle isn't practical (cosmetic change, config tweak, 1-line typo), use verify-only:

```
TDD CERTIFICATE (VERIFY-ONLY):
  Change: [what was changed]
  Verify: [curl / screenshot / import smoke test — how it was checked]
  Smoke:  [import OK]
```

### Testing tiers (CRITICAL)

| Tier | When | What to run | Time |
|------|------|-------------|------|
| **Smoke** | Every change | `python3 -c "from <module> import <thing>"` + targeted test | <30s |
| **Nearby** | After a batch | `pytest tests/ -k "related_keyword" -q` | <60s |
| **Full suite** | **CI only** — NEVER locally | `pytest tests/` | 5-10 min |

The full suite is CI's job. Local dev = smoke + nearby. This distinction matters: a developer running the full suite on every change wastes hours per day.

---

## Part 2 — TDD-First Debug Protocol (heavy variant)

**When to use:** Production bugs from logs. Auth/security issues (wrong fixes are dangerous). Cross-component bugs (blast radius matters). Any bug where "just try it" could make things worse.

**Why it exists:** Discovered during a real debugging session where the bug affected 23 components and ~80 routes. By proving the fix BEFORE implementing, a potentially dangerous change was avoided.

**Core principle:** No implementation until steps 1-5 are done. ~15 lines of fix, 5 agents of reasoning, 8 tests of proof. **Confidence > speed.**

### The 6 Steps

#### Step 1 — Read the logs (no grep, full context)

- Read FULL logs — grep hides context
- Identify EVERY distinct issue (there may be multiple root causes)
- Note exact error messages, timestamps, request paths

Common mistake: grep for the error message and fix only that one symptom, missing the 3 related failures in the same log window.

#### Step 2 — Trace the code (3+ parallel agents)

Launch simultaneously in one message:

| Agent | Role |
|---|---|
| **Root cause tracer** | Follow error from log to exact `file:line` |
| **Implementation reader** | Read ALL target files completely (not just the implicated one) |
| **Blast radius scanner** | Find ALL affected callers/components, not just the one in the log |

The log points at a symptom. The bug may be upstream.

#### Step 3 — Grill the plan (10 hard questions)

Before any fix, stress-test with questions answered FROM THE CODEBASE, not from memory:

- Does the target know it's in the affected mode?
- Security implications?
- Does the bug exist in the reverse direction too?
- Are there other entry points with the same bug?
- What's the simplest fix that's also correct?
- What existing patterns can we mirror?
- Which callers will this break?
- What's the rollback path?
- What does the test-that-catches-this look like?
- Who else needs to know?

If you can't answer one from the codebase, GNGM pre-task search the gap.

#### Step 4 — Simulate

Write a Python script that PROVES the fix works before touching production code:

- Reproduce the exact failure
- Prove the fix handles: valid input, invalid input, expired state, edge cases
- Run it — hard evidence, not theoretical reasoning

For auth bugs: script that mints tokens with different keys, tries different validation paths, asserts the failure reproduces and the fix cures it.

For race conditions: script that spawns concurrent workers, asserts the race reproduces without the fix and doesn't with it.

#### Step 5 — Write tests FIRST (TDD RED)

- Tests that **FAIL now, WILL PASS after fix** (define the behavior)
- **Guard tests** that **PASS now, MUST STILL PASS** (prevent regressions)
- Run them — confirm the exact RED/GREEN split

**The test count split IS the proof.** For example: *"3 tests fail (the ones testing the fix), 5 tests pass (regression guards)."*

If the split doesn't match your expectation, the test set is wrong. Fix the tests before implementing.

#### Step 6 — Write plan with exact code

ONLY NOW write the implementation plan:

- Exact file paths and line numbers
- Before/after diffs
- Security analysis table (what does this change enable? disable?)
- Rollback strategy (separate commits for independent changes)
- Verification checklist:
  - [ ] Unit tests pass
  - [ ] Integration tests pass (if applicable)
  - [ ] Smoke test: app starts, endpoint responds, auth works
  - [ ] Production scenario reproduced and cured

### Anti-patterns

- **Jumping to code changes after reading the error message** — the log is a symptom; the bug is upstream
- **Writing the fix then writing tests to match** (backwards TDD) — tests become rubber-stamps, miss real bugs
- **Testing one component when the bug affects many** — blast radius matters
- **Guessing about security instead of checking bind address, config, etc.** — security bugs don't tolerate guesses
- **"I'll add the test after it works"** — that's not TDD, that's retroactive justification

### Real incident metrics

Actual numbers from one production bug solved with this protocol:

| Metric | Value |
|--------|-------|
| Bug | Auth rejection across 23 components |
| Agents used | 6 (3 trace + 1 grill + 1 simulate + 1 TDD writer) |
| Simulation scenarios | 6 (all passed) |
| TDD tests written | 8 (3 RED, 5 GREEN) |
| Fix size | ~15 lines, 1 file |
| Frontend changes | 0 (server-side fix covered all components) |
| Confidence before implementation | High (proven) |

---

## When to use TDD baseline vs TDD-First Debug Protocol

| Situation | Use |
|---|---|
| Small bug fix, isolated | TDD baseline (RED→GREEN) |
| Feature, small scope | TDD baseline |
| Config/cosmetic | Verify-only certificate |
| Production bug with logs | TDD-First Debug Protocol (6 steps) |
| Auth/security bug | TDD-First Debug Protocol (always) |
| Cross-component bug | TDD-First Debug Protocol (blast radius matters) |
| "Just try it" feels tempting | TDD-First Debug Protocol (the temptation is a signal) |

---

## Related

- [SDP.md](SDP.md) — Standard Development Protocol. SDP Step 4 uses TDD baseline. SDP Step 1 + NeuralTree lesson_match can detect "this is a heavy-debug scenario."
- [NLF.md](NLF.md) — No Lie Fix. TDD proves the fix; NLF forbids the bandage.
- GNGM `02-PROTOCOL.md` Step 3.4 — NeuralTree lesson_match returns past fixes by symptom; run first before writing anything.

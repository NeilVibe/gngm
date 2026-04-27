---
name: SDP — Standard Development Protocol
description: Baseline 5-step protocol for ALL code changes (bug fixes, features, refactors). Brainstorm → ECC Plan Review → Execute → TDD Certificate → ECC Code Review, with a LEARN step closing the GNGM feedback loop. Layer PRXR on top for major multi-file features.
type: gngm-protocol
version: 1
last_verified: 2026-04-27
trigger: SDP (explicit) OR self-applied to any code change
---

# SDP — Standard Development Protocol

> **The baseline protocol for ALL code changes.** No exceptions — bug fixes, features, refactors.
> For major multi-file features, layer PRXR (Plan-Review-Execute-Review) on top.

## Why SDP exists

Every code change — even a 3-line bug fix — needs a minimum quality bar:

1. **Think before coding** — most bugs come from jumping straight to implementation
2. **Prove it works** — TDD certificate = hard evidence, not "I think it works"
3. **Fresh eyes catch what you miss** — 4 specialist review agents examine from different angles

The GNGM knowledge stack (Graphiti + NeuralTree + Viking + Memory) is **free and local**. Zero cost to using all of them on every single task. Skipping them means flying blind when the instruments are right there.

---

## The 5 Steps

```
1. BRAINSTORM       Understand context, stress-test approach, write plan
2. ECC PLAN REVIEW  4 agents examine the plan BEFORE code is written
3. EXECUTE          Implement per plan, each change gets a TDD certificate
4. TDD CERTIFICATE  Per change: test RED -> fix -> test GREEN = proof
5. ECC CODE REVIEW  4 specialist agents review the implementation
```

---

## Step 1 — BRAINSTORM

**Goal:** Understand the problem deeply, then write a plan specific enough that another agent could execute it blindly.

### 1a. Query the knowledge stack (MANDATORY — free, local)

Run these **in parallel** (single message, multiple tool calls):

```
Graphiti search    -> "What connects to [topic]?"           -> dependencies, blast radius
Graphiti search    -> "What changed about [topic]?"         -> recent history
Viking search      -> "[topic keywords]"                    -> find relevant docs/files
NeuralTree match   -> [symptom descriptions]                -> have we fixed this before?
Memory search      -> "[topic]"                             -> cross-session knowledge
```

**Then:**

```
Graphify query     -> "what calls [ENTITY]"                 -> code structure
```

**Why every tool matters:**

| Tool | What it tells you | Cost |
|------|-------------------|------|
| **Graphiti** | Entity connections, dependency graphs, temporal facts. "X connects to Y via Z." What grep and semantic search can't find. | Free (Qwen local) |
| **Viking** | Semantic doc search. Finds the right files even with vague queries. | Free (Model2Vec local) |
| **NeuralTree** | Past fixes by symptom. "We fixed this pattern in Phase 120." Prevents re-learning. | Free (local) |
| **Memory** | Cross-session behavioral rules. "User prefers X." "Never do Y." | Free (MCP local) |
| **Graphify** | Deterministic code graph. Caller lists, paths between entities. | Free (AST local) |

### 1b. Stress-test the approach

Ask hard questions answered FROM THE CODEBASE, not from memory:

- What's the simplest fix that's also correct?
- What else touches this code? (Graphiti told you)
- Have we seen this pattern before? (NeuralTree told you)
- What breaks if this fix is wrong?
- Is there an existing pattern to mirror?

### 1c. Write the plan

The plan MUST include:

- **What:** 1-2 sentence summary of the change
- **Why:** Root cause (for bugs) or motivation (for features)
- **Files:** Exact paths + what changes in each
- **Before/After:** Code snippets showing the diff
- **Blast radius:** What else might be affected (from Graphiti)
- **Past context:** Any NeuralTree lessons or Memory rules that apply

---

## Step 2 — ECC PLAN REVIEW (4 agents in parallel)

Launch 4 review agents in **one message** with 4 Agent tool calls. Each reviews from a different angle:

| Agent | Focus | What to look for |
|-------|-------|------------------|
| 1. **Correctness** | Does the logic hold? | Wrong assumptions, flawed reasoning, incorrect API usage |
| 2. **Blast Radius** | What else breaks? | Upstream/downstream effects, shared state, race conditions |
| 3. **Pattern Consistency** | Does it match the codebase? | Existing conventions, naming, error handling style |
| 4. **Completeness** | Anything missing? | Edge cases, error paths, cleanup, missing tests |

### Review agent prompt template

```
Review this PLAN for: [feature/fix name]

Context: [1-2 sentences — what and why]

Plan:
[paste the plan from Step 1c]

Codebase context (from Graphiti/Viking):
- [relevant connection or dependency]
- [past fix or lesson from NeuralTree]

Your focus: [CORRECTNESS / BLAST RADIUS / PATTERN CONSISTENCY / COMPLETENESS]

Classify findings as: CRITICAL (blocks) / WARNING (should fix) / SUGGESTION (nice to have)
Report in under 200 words.
```

### After review

- Address every CRITICAL and WARNING finding
- If review reveals a design flaw, go back to Step 1 (not forward)
- If you restart more than twice, escalate to user

---

## Step 3 — EXECUTE

Implement file by file in the order the plan specifies.

### Before each file change

```
Graphiti search -> "What depends on [this file]?"  -> avoid breaking callers
```

### During implementation

- Follow the plan exactly. If drift is detected, stop and reconcile.
- If the plan was wrong, go back to Step 1 with what you learned. Don't improvise.

### After each code change

→ TDD certificate (Step 4).

---

## Step 4 — TDD CERTIFICATE

The certificate is **proof that each change works**. Not "I read the code and it looks right" — actual test evidence.

### The pattern

```
1. Write test that FAILS now (RED)     -> defines expected behavior
2. Apply the code change               -> the actual fix/feature
3. Run test — it PASSES now (GREEN)    -> proves the change works
4. Quick smoke test (import + nearby)  -> proves nothing obvious broke
```

### Testing tiers (CRITICAL — don't waste time!)

| Tier | When | What to run | Time |
|------|------|-------------|------|
| **Smoke** | Every change | `python3 -c "from <module> import <thing>"` + targeted test file | <30s |
| **Nearby** | After a batch of changes | `pytest tests/ -k "related_keyword" -q` | <60s |
| **Full suite** | CI only (after push) | `pytest tests/` — everything | CI handles this |

**NEVER run the full test suite locally during development.** That's CI's job. Use smoke + targeted tests during dev; let CI run everything after push.

### Certificate format

After each change, record:

```
TDD CERTIFICATE:
  Change: [what was changed, 1 line]
  Test:   [test name]
  RED:    [test_name FAILED - expected X got Y]
  GREEN:  [test_name PASSED]
  Smoke:  [import OK, N nearby tests passing]
```

### When full TDD isn't practical

Some changes (cosmetic, config, 1-line typos) don't need a RED→GREEN cycle:

```
TDD CERTIFICATE (VERIFY-ONLY):
  Change: [what was changed]
  Verify: [how it was verified — curl, screenshot, import smoke test]
  Smoke:  [import OK]
```

**The key: every change has evidence.** No change ships on "trust me." But evidence = fast smoke tests, not running the entire CI pipeline locally.

---

## Step 5 — ECC CODE REVIEW (4 specialist agents in parallel)

Launch 4 specialist agents. Each reviews the implementation from a different angle:

| Agent | Focus |
|-------|-------|
| 1. **code-reviewer** | SOLID principles, complexity, risk analysis, style |
| 2. **code-simplifier** | Clarity, dead code, unnecessary abstractions, maintainability |
| 3. **silent-failure-hunter** | Error handling gaps, swallowed exceptions, bad fallbacks |
| 4. **logic-and-security** | Bugs, logic errors, security vulnerabilities |

### Review prompt template

```
Review this CODE for: [feature/fix name]

Context: [1-2 sentences]

Files changed:
- [path] — [what changed and why]

TDD certificates:
- [list of RED->GREEN evidence]

Your focus: [agent-specific focus]

Classify findings as: CRITICAL / WARNING / SUGGESTION
Report in under 200 words.
```

### After review

- Fix every CRITICAL finding immediately
- Fix WARNING findings unless there's a documented reason not to
- SUGGESTION findings are optional but log them for future reference

---

## Step 6 (after all 5 steps) — LEARN

Feed what you learned back into the knowledge stack — this is how GNGM compounds:

```python
# 1. Graphiti — store new connections/facts
await g.add_episode(
    name='phase-NNN-description',
    episode_body='What was done, what connects to what, what was learned. Connects: A -> B -> C.',
    source_description='SDP completion',
    reference_time=datetime.now(timezone.utc),
    group_id='<PROJECT>',
)

# 2. NeuralTree — record fixes for future retrieval (bugs only)
neuraltree_lesson_add(domain="<domain>", lesson={
    "symptom": "...", "root_cause": "...", "fix": "...",
    "chain": "A -> B -> C", "key_file": "path/to/file.py"
})

# 3. Memory — update rules if behavioral learning happened
#    Only if a NEW rule was discovered, not just a one-time fix
memory.create_entities(...) / add_observations(...) / create_relations(...)

# 4. Graphify — auto-refreshes via post-commit hook (if installed)
#    If not, run: .venv-graphify/bin/graphify update .
```

---

## When to use SDP vs PRXR

| Situation | Protocol |
|-----------|----------|
| Any bug fix (1-5 files) | **SDP** |
| Small feature (1-5 files) | **SDP** |
| Config/docs/trivial change | **SDP** (skip Step 2, verify-only certificate) |
| Multi-file feature (5+ files) | **PRXR** (7 steps, 5 agents) |
| Core logic rewrite | **PRXR** |
| Architecture refactor | **PRXR** + 3 expert critics |

**SDP is the floor, not the ceiling.** Always use SDP. Layer PRXR on top when the change is big enough to warrant it.

---

## Quick-reference card

```
STEP 1: BRAINSTORM
  [ ] Graphiti search (connections + blast radius)
  [ ] Viking search (relevant docs)
  [ ] NeuralTree lesson_match (past fixes)
  [ ] Memory search_nodes (cross-session rules)
  [ ] Graphify query (caller list)
  [ ] Stress-test the approach
  [ ] Write plan (what, why, files, before/after, blast radius)

STEP 2: ECC PLAN REVIEW (4 agents in parallel)
  [ ] Correctness agent
  [ ] Blast Radius agent
  [ ] Pattern Consistency agent
  [ ] Completeness agent
  [ ] Address all CRITICAL + WARNING findings

STEP 3: EXECUTE
  [ ] Graphiti check before each file change
  [ ] Implement per plan, no drift

STEP 4: TDD CERTIFICATE (per change)
  [ ] Test RED (fails before)
  [ ] Apply change
  [ ] Test GREEN (passes after)
  [ ] Smoke test (import + nearby — NOT full suite)
  [ ] Record certificate
  NOTE: Full test suite = CI only.

STEP 5: ECC CODE REVIEW (4 specialist agents in parallel)
  [ ] code-reviewer (SOLID, complexity)
  [ ] code-simplifier (clarity, dead code)
  [ ] silent-failure-hunter (error handling)
  [ ] logic-and-security (bugs, security)
  [ ] Fix all CRITICAL + WARNING findings

AFTER: LEARN
  [ ] Graphiti add_episode (new facts)
  [ ] NeuralTree lesson_add (if bug fix)
  [ ] Memory update (if new behavioral rule)
  [ ] Graphify auto-refreshes on commit (hook)
```

---

## Anti-patterns

- **Skipping knowledge stack** — "I already know this code." Graphiti knows connections you forgot.
- **Skipping plan review** — "The plan is obvious." Plans have bugs too. 4 agents take 30 seconds.
- **No TDD certificate** — "I tested it manually." Manual testing isn't evidence. Write the test.
- **Generic review prompts** — "Review this code." Be specific: files, context, focus area.
- **Ignoring review findings** — If you dismiss a finding, document why.
- **PRXR for trivial changes** — SDP is enough for most work. Don't over-process.
- **Skipping the LEARN step** — The knowledge stack compounds. Every skipped lesson is a future re-discovery.

---

## Related

- [NLF.md](NLF.md) — No Lie Fix. SDP finds root causes; NLF forbids bandages around them.
- [TDD.md](TDD.md) — TDD-First Debug Protocol. Heavier variant of Step 4 for production bugs.
- [PRD.md](PRD.md) — Product Requirements Document. Run BEFORE SDP for non-trivial new features.
- [PRD-TO-ISSUES.md](PRD-TO-ISSUES.md) — Each decomposed issue feeds exactly one SDP loop.
- [IMPROVE-ARCHITECTURE.md](IMPROVE-ARCHITECTURE.md) — If touch path is shallow, deepen it before SDP.
- [NATURAL-STOP-HANDOFF.md](NATURAL-STOP-HANDOFF.md) — NSH is SDP step 7's session-close form.

## Docs

- `../docs/02-PROTOCOL.md` — full GNGM 4-mode mechanics that SDP Step 1 uses
- `../docs/03-CHEATSHEET.md` — one-page reference
- `../docs/04-LESSONS.md` — pitfalls + resilience patterns from production use

---
name: GNGM Wave Protocol — Lifecycle of a Unit of Work
description: How each unit of major work (a "wave" — equivalent to a phase, milestone, or feature) runs against the GNGM stack + canonical project structure. 7-stage lifecycle (OPEN → BRAINSTORM → PLAN REVIEW → EXECUTE → VERIFY → CODE REVIEW → CLOSE) using NLF/SDP/TDD discipline at each stage. Works for any stack, any CLI AI.
type: gngm-doc
last_verified: 2026-04-27
---

# Wave Protocol — Lifecycle of a Unit of Work

> How each unit of major work (a "wave" — equivalent to a phase, milestone, or feature) runs against the GNGM stack + canonical project structure. Works for any stack, any CLI AI.

## Why waves

A wave is a bounded unit of work with a clear start, end, and deliverable. The wave protocol ensures:

- Knowledge stack fires at the right moments (pre-task + post-fix + close)
- Plan is reviewed BEFORE code is written (avoids expensive redesigns)
- TDD discipline is applied per change
- Lessons get captured (not lost)
- Each wave contributes to compounding knowledge

**Use waves for:** features, phases, milestones, major refactors, anything that takes >1 session.

**Don't use waves for:** typo fixes, one-line config changes, trivial tweaks. Apply SDP (see `protocols/SDP.md`) without the wave ceremony.

## The seven stages

```
1. OPEN           — create wave folder, write PLAN.md, announce
2. BRAINSTORM     — GNGM pre-task: parallel query all 4 layers + read docs
3. PLAN REVIEW    — 4 ECC agents review PLAN.md
4. EXECUTE        — atomic commits, TDD per change, NLF discipline
5. VERIFY         — tests + property tests + (optional) vision review
6. CODE REVIEW    — 4 specialist agents in parallel
7. CLOSE          — SUMMARY.md, lesson_add, add_episode, update active/_INDEX.md
```

Stage details below.

## Stage 1 — OPEN

Create wave folder + plan file.

```bash
# Naming convention: wave-<number>-<shortname>
mkdir -p docs/waves/wave-N-shortname/{assets}
```

Write `docs/waves/wave-N-shortname/PLAN.md`:

```markdown
---
name: Wave N — <title>
description: <one-line goal>
type: wave-plan
wave_number: N
status: open
opened: YYYY-MM-DD
---

# Wave N — <title>

## Goal
<one paragraph>

## Scope IN / OUT
...

## Changes (DB / API / UI / config)
...

## Tools (skills / APIs / services)
...

## Protocols (NLF / SDP / TDD)
...

## TDD strategy
...

## Exit criteria
- [ ] criterion 1
- [ ] ...

## Related
...

## Docs
...
```

Update `memory/active/_INDEX.md` → current wave = N.

## Stage 2 — BRAINSTORM (GNGM pre-task)

Single message, parallel tool calls:

```
1. Graphiti search — 2-3 specific entity names for the wave's topic
2. NeuralTree lesson_match — domain symptoms we might hit
3. Viking search — relevant project docs
4. Memory search_nodes — cross-session rules
5. Graphify query — code structure (if wave touches existing code)
```

Then write PLAN.md with concrete file-level changes. Stress-test: "What else touches this? What could break?"

## Stage 3 — PLAN REVIEW (4 ECC agents in parallel)

Single message, 4 Agent tool calls:
- Agent 1: Correctness — does the logic hold?
- Agent 2: Blast radius — what else breaks?
- Agent 3: Pattern consistency — does it match codebase conventions?
- Agent 4: Completeness — anything missing?

Each gets PLAN.md + codebase context. Classifies findings CRITICAL / WARNING / SUGGESTION.

- CRITICAL → block, revise PLAN.md
- WARNING → fix unless documented reason
- SUGGESTION → optional

If 2+ CRITICALs → wave may need redesign. Back to Stage 2.

## Stage 4 — EXECUTE (atomic commits)

For each task:
1. Write test that FAILS (TDD red)
2. Implement to make it pass (TDD green)
3. Smoke test (import + adjacent test — NOT full suite, that's CI's job)
4. Commit atomic: `feat(scope): description` or `fix(scope): description`
5. Graphify post-commit hook fires (automatic via installed hook)

NLF discipline throughout:
- No "comment out / catch-and-ignore" bandages
- No claim without verification via tool call in THIS session
- "Investigating" > "here's a plausible answer"

## Stage 5 — VERIFY

- **Unit tests:** pytest / Vitest / cargo test / whatever your stack uses — 100% on changed code
- **Integration tests:** DB or service tests against real services (testcontainers, etc.)
- **Property tests:** Hypothesis or similar for math-heavy or determinism-critical code
- **Vision review:** (optional, for UI waves) Qwen3-VL on Playwright screenshots; score ≥ 7
- **Manual check:** localhost preview — everything visible?

All tests green → Stage 6. Red → back to Stage 4 with a NEW commit (don't amend).

## Stage 6 — CODE REVIEW (4 specialist agents in parallel)

Single message, 4 parallel Agent calls:
- `code-reviewer` — SOLID, complexity, style
- `code-simplifier` — clarity, dead code, over-abstraction
- `silent-failure-hunter` — error handling, swallowed exceptions
- `security-reviewer` — bugs, auth/crypto/input handling

Address all CRITICAL + WARNING findings. SUGGESTIONS optional but logged.

## Stage 7 — CLOSE

1. Write `docs/waves/wave-N-shortname/SUMMARY.md`:

```markdown
---
name: Wave N — <title> SUMMARY
type: wave-summary
wave_number: N
status: closed
opened: YYYY-MM-DD
closed: YYYY-MM-DD
---

# Wave N — <title> — Summary

## What shipped
- ...

## Files touched
- ...

## Key decisions / tradeoffs
- ...

## Lessons captured
- <link to lesson files>

## Handoff to next wave
- <what Wave N+1 needs to know>
```

2. For each significant lesson, `neuraltree_lesson_add`:

```python
neuraltree_lesson_add(
    domain="<domain>",
    lesson={
        "symptom": "...", "root_cause": "...", "fix": "...",
        "chain": "A → B → C",
        "key_file": "<path>",
        "commit": "<sha>"
    }
)
```

3. Graphiti `add_episode` for the wave completion:

```python
await g.add_episode(
    name=f'wave-{N}-{shortname}-complete-{YYYY-MM-DD}',
    episode_body="<what shipped, Connects: chain, key files>",
    source_description=f'Wave {N} close',
    reference_time=datetime.now(timezone.utc),
    group_id='<project>',
)
```

4. Update `memory/active/_INDEX.md` → Wave N closed, next = N+1.

5. If a lesson domain just crossed 3 entries → QUEUE wiki compile (separate session, not inline).

6. Final commit: `chore(wave-N): close + summary + knowledge feed`.

## Wave-skipping rule

Never skip stages. Stages 2, 3, 6 feel like overhead — they aren't. They're the reason the plan survives contact with reality. Skipping plan review = finding bugs during execute = doubled time.

## Emergency deviation

If mid-wave we discover PLAN.md is fundamentally wrong:
1. STOP coding
2. Document in `docs/waves/wave-N-shortname/DEVIATION.md`
3. Re-enter Stage 2 with new information
4. Previously-written code stays if still valid; revert if not

## Lightweight variant (for small waves)

Not every wave needs the full ceremony. For simpler changes (2-3 files, one session):

- Stage 2: GNGM pre-task (mandatory — this is cheap and high value)
- Stage 3: skip (but at least consider the 4 review dimensions yourself)
- Stages 4, 5: mandatory (TDD, verify)
- Stage 6: 2 agents (code-reviewer + silent-failure-hunter) instead of 4
- Stage 7: SUMMARY + lesson_add + episode (mandatory — knowledge feed)

## Works for any stack

The protocol is language/stack-agnostic. The SDP and TDD steps reference "tests" which means pytest / Vitest / cargo test / jest / go test / whatever your stack provides. Adapt the commands; keep the discipline.

## Works for any CLI AI

`CLAUDE.md` / `AGENTS.md` / `GEMINI.md` all reference this doc. The protocol steps are tool-agnostic — Claude Code's subagents, Cursor's composer, Codex's tools, Gemini's agents — they all have equivalents of "review plan with 4 critics", "run TDD", "apply lessons". Map the verbs to your CLI.

## Related
- [05-PROJECT-STRUCTURE.md](05-PROJECT-STRUCTURE.md) — the structure this runs against
- [02-PROTOCOL.md](02-PROTOCOL.md) — GNGM mechanics
- [../protocols/SDP.md](../protocols/SDP.md) — SDP (applies per-task within Execute stage)
- [../protocols/TDD.md](../protocols/TDD.md) — TDD discipline
- [../protocols/NLF.md](../protocols/NLF.md) — NLF discipline

## Docs
- `scripts/gngm-full-scaffold.sh` — scaffolds a project ready for this protocol

---
name: {{PROJECT_NAME}} project-level Claude Code instructions
description: Auto-loaded at session start. Project discipline, triggers, stack, anti-patterns.
type: project-claude
last_verified: {{DATE}}
---

# CLAUDE.md — {{PROJECT_NAME}} project-level instructions

> Auto-loaded by Claude Code at session start. Extends (does not replace) global rules at `~/.claude/rules/`.

## Project
{{PURPOSE}}

## Governance authority (read in this order before starting work)

1. **Global rules** at `~/.claude/rules/` — knowledge-system, organization-master, power-stack, graphiti-protocol, neuraltree-protocol, cleanup-protocol, skill-tier-list
2. **Memory trunk** auto-loaded from `~/.claude/projects/-<project-id>/memory/MEMORY.md` → branches into rules, active, reference
3. **Project protocols** at `docs/GNGM/protocols/` — NLF, SDP, TDD, GIT-SAFETY
4. **Master plan** at `MASTER_PLAN.md` if present — the roadmap

## Trigger phrases (act without asking)

| You say | I run |
|---|---|
| `GNGM` | Full 4-layer knowledge stack (pre-task or post-fix, context-dependent) |
| `GNGM pre-task` | Parallel search Graphiti + NeuralTree + Viking + MemoryMCP + Graphify |
| `GNGM post-fix` | Feed all 4 layers after meaningful change |
| `GNGM health` | 10-second service check |
| `NLF` | No-Lie-Fix discipline — verify every claim with a tool call in THIS session |
| `SDP` | Standard Development Protocol — brainstorm → plan review → execute → TDD cert → code review → learn |
| `wave start N` | Open wave N per wave-protocol.md |
| `wave close N` | Close wave N — SUMMARY.md + lessons + episode + index update |

## Discipline (non-negotiable)

### 1. NLF (No-Lie-Fix)
- No "comment out / catch-and-ignore / disable" bandages
- No architectural claim without reading code with tool calls IN THIS SESSION
- "I don't know yet, checking" > a confident wrong answer
- See `docs/GNGM/protocols/NLF.md`

### 2. SDP (every code change)
Brainstorm → Plan Review (4 ECC agents) → Execute → TDD Certificate → Code Review (4 specialist agents) → Learn
- See `docs/GNGM/protocols/SDP.md`

### 3. Wave protocol
Every wave: OPEN → BRAINSTORM (GNGM) → PLAN REVIEW (4 ECC agents) → EXECUTE (TDD + NLF) → VERIFY → CODE REVIEW (4 specialist agents) → CLOSE (lesson_add + add_episode + SUMMARY.md)
- See `memory/rules/wave-protocol.md` (if created) or `docs/GNGM/docs/06-WAVE-PROTOCOL.md`

### 4. Organization
- `docs/current/` ≤ 3 files max
- Every .md has frontmatter (name, description, type, last_verified)
- Every .md ends with `## Related` + `## Docs`
- `MEMORY.md` trunk ≤ 100 lines — index only, never dump content
- See `docs/GNGM/docs/05-PROJECT-STRUCTURE.md`

## Dev loop

Populate when services come online:
- Frontend dev server: `localhost:XXXX`
- Backend: `localhost:XXXX`
- Dashboard: `localhost:XXXX`

## Session start checklist (~30s)

```bash
bash docs/GNGM/scripts/gngm-health.sh    # 10-second GNGM service check
# Memory trunk auto-loaded
# Read memory/active/_INDEX.md for current wave + blockers
git status                                # uncommitted work?
```

## Anti-patterns (don't do)

- Read code files before running GNGM pre-task → blind work
- Generic Graphiti queries ("auth", "the bug") → noise
- Skip vision review on frontend changes → design drift
- Amend commits (use new commits, never --amend)
- Dump content into MEMORY.md instead of a branch
- Compile a wiki with <3 lessons in the domain
- Skip frontmatter "just this once"

## Related
- `MASTER_PLAN.md` — vision + waves (if created)
- `docs/INDEX.md` — project doc tree
- `~/.claude/projects/-<project-id>/memory/MEMORY.md` — memory trunk (auto-loaded)
- `docs/GNGM/docs/02-PROTOCOL.md` — GNGM mechanics

## Docs
- Memory: `~/.claude/projects/-<project-id>/memory/`
- Global rules: `~/.claude/rules/`
- GNGM protocols: `docs/GNGM/protocols/`

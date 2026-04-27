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
3. **Project protocols** at `docs/GNGM/protocols/` — full set listed in `docs/GNGM/README.md` (foundational + operational + product/scoping clusters; 14 universal protocols as of 0.6.1)
4. **Master plan** at `MASTER_PLAN.md` if present — the roadmap

## Trigger phrases (act without asking)

### Knowledge-stack triggers

| You say | I run |
|---|---|
| `GNGM` | Full 4-layer knowledge stack (pre-task or post-fix, context-dependent) |
| `GNGM pre-task` | Parallel search Graphiti + NeuralTree + Viking + MemoryMCP + Graphify |
| `GNGM post-fix` | Feed all 4 layers after meaningful change |
| `GNGM health` | 10-second service check |

### Engineering protocol triggers

| You say | I run |
|---|---|
| `NLF` | No-Lie-Fix discipline — verify every claim with a tool call in THIS session |
| `SDP` | Standard Development Protocol — brainstorm → plan review → execute → TDD cert → code review → learn |
| `RAC` | Repeatable Action Chain — universal pipeline methodology |
| `LOG` | Structured logging + correlation-ID contract enforcement |
| `STRESS` / `STRESS <feature>` | 7-dimension stress discipline (concurrency, burst, reconnect, etc.) |
| `NSH` / `NSH dry` / `NSH minimal` | Natural Stop Handoff — proactive session close + cold-start-friendly handoff |
| `PRD` | Interactive Product Requirements Document creation |
| `PRD-TO-ISSUES` | Tracer-bullet vertical-slice decomposition (PRD → SDP-ready issues) |
| `UL` / `UBIQUITOUS-LANGUAGE` | DDD glossary extraction (auto-suggested by NSH if stale) |
| `IA` / `IMPROVE-ARCHITECTURE` | Codebase audit + parallel sub-agent interface designs |
| `wave start N` | Open wave N per wave-protocol.md |
| `wave close N` | Close wave N — SUMMARY.md + lessons + episode + index update |

Git-safety + git-hygiene apply automatically to every git operation; no trigger needed.

## Discipline (non-negotiable)

### 1. NLF (No-Lie-Fix)
- No "comment out / catch-and-ignore / disable" bandages
- No architectural claim without reading code with tool calls IN THIS SESSION
- "I don't know yet, checking" > a confident wrong answer
- See `docs/GNGM/protocols/NLF.md`

### 2. SDP (every code change)
Brainstorm → Plan Review (4 ECC agents) → Execute → TDD Certificate → Code Review (4 specialist agents) → Learn
- See `docs/GNGM/protocols/SDP.md`

### 3. PRD-first for new features
For non-trivial new features (multi-module, multi-session, externally-visible): run `PRD` BEFORE `SDP`. SDP assumes a spec exists; PRD creates it.
PRD → PRD-TO-ISSUES → SDP (one loop per issue) → NSH
- See `docs/GNGM/protocols/PRD.md` + `docs/GNGM/protocols/PRD-TO-ISSUES.md`

### 4. Wave protocol
Every wave: OPEN → BRAINSTORM (GNGM) → PLAN REVIEW (4 ECC agents) → EXECUTE (TDD + NLF) → VERIFY → CODE REVIEW (4 specialist agents) → CLOSE (lesson_add + add_episode + SUMMARY.md)
- See `memory/rules/wave-protocol.md` (if created) or `docs/GNGM/docs/06-WAVE-PROTOCOL.md`

### 5. Session close — NSH
When a logical unit lands clean (tree clean + tests green + clarity high), proactively run `NSH`. Closes the off-machine-gap + discovery-rot + state-drift trio. Step 3.5 auto-suggests `UL` glossary refresh if stale.
- See `docs/GNGM/protocols/NATURAL-STOP-HANDOFF.md`

### 6. Organization
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

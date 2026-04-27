---
name: PRD-TO-ISSUES — Vertical-Slice Decomposition Protocol
description: Break a PRD into independently-grabbable issues using tracer-bullet vertical slices. Each slice cuts through every layer (schema → API → UI → tests) end-to-end. Each completed issue feeds one SDP loop. Bridges the PRD → SDP gap so downstream implementation never has to re-derive scope.
type: gngm-protocol
version: 1
last_verified: 2026-04-27
trigger: PRD-TO-ISSUES (explicit) OR user says "break this PRD down" / "create implementation issues" / "slice this up"
---

# PRD-TO-ISSUES — Vertical-Slice Decomposition Protocol

> **Purpose.** A PRD describes the destination. Issues describe how to get there in independently-deployable steps. This protocol enforces tracer-bullet slicing so each issue is demoable on its own, dependencies are explicit, and SDP can pick up any issue without re-reading the entire PRD.

## Why this exists

Without disciplined slicing, the failure mode is two extremes:

1. **One mega-issue** that says "implement the whole PRD." Impossible to schedule, parallelize, or partially deliver.
2. **N horizontal-layer issues** ("schema only," "API only," "UI only"). None of them are demoable until the last one ships. Mid-stream cancellation = sunk cost.

Tracer bullets fix both: every slice goes end-to-end (thin but COMPLETE through every integration layer), every slice is demoable, and the PRD's user stories distribute across slices like a manifest.

The other failure mode this prevents: **scope drift inside SDP.** When SDP starts from a vague task, Step 1 (Brainstorm) becomes a mini-PRD interview. By feeding SDP a tightly-scoped, dependency-aware issue, Step 1 stays focused on **how** instead of relitigating **what**.

## When PRD-TO-ISSUES fires

- After a PRD lands (GitHub issue, local spec, or other artifact)
- When user says "let's start implementing" but multiple work units exist
- When a coarse-grained issue blocks parallel work and needs splitting

**Skip when:**

- The PRD is already a single tracer-bullet (1-3 day's work, end-to-end) → skip straight to SDP
- Single-line bug fix → SDP is enough, no decomposition needed
- The "PRD" is actually a refactor → use IMPROVE-ARCHITECTURE protocol instead

## Vertical-slice rules (load-bearing)

Read these every time. They are the contract.

1. **End-to-end.** Each slice cuts through schema → API → UI → tests (whatever layers exist in this stack). NOT a horizontal slice of one layer.
2. **Demoable on its own.** A completed slice can be merged, deployed, and shown to a user. Even if the feature is incomplete, what shipped is real.
3. **Many thin slices > few thick ones.** When in doubt, split. The cost of splitting is lower than the cost of an over-scoped slice.
4. **Dependencies explicit.** Each slice declares "Blocked by #N" or "None — can start immediately." No implicit ordering.
5. **HITL vs AFK explicit.**
   - **HITL** (Human-in-the-Loop) — needs human interaction mid-implementation. Architectural decisions, design reviews, manual config of external services, ambiguous UX.
   - **AFK** (Away-From-Keyboard) — fully implementable + verifiable without further human input. SDP runs end-to-end.
   - **Prefer AFK.** If a slice can be made AFK by pre-deciding the HITL question in the PRD, do that.

A slice that violates rule 1 (horizontal layer) or rule 2 (not demoable) is **not a tracer bullet** — it's a task. Tasks belong inside an issue's checklist, not as their own issue.

## The 5 steps

### Step 1 — Locate the PRD

If the user gave an issue number or URL: fetch with `gh issue view <number> --comments` (or the platform-equivalent).

If the user pointed to a local file: read it.

If the user just said "let's break this down" without identifying the PRD: ask which one. Do NOT guess.

The PRD MUST be in your context window before proceeding. Half-remembered is not good enough.

### Step 2 — GNGM the codebase

Optional but strongly recommended if the PRD's touch path isn't already loaded:

```
Graphify query   → "what calls <main entity from PRD>"
Viking search    → "<feature area>"
Graphiti search  → "what depends on <component>"
NeuralTree match → ["any past fixes in this area"]
```

This catches dependencies the PRD might have missed — e.g., "the PRD says we'll add field X to model Y, but Graphify shows 14 callers of Y that need migration."

### Step 3 — Draft vertical slices

Convert the PRD into a numbered list of tracer-bullet slices. For each slice:

| Field | Content |
|---|---|
| **Title** | Short, action-oriented (e.g., "Add inventory count column to product list") |
| **Type** | HITL or AFK |
| **Blocked by** | Issue numbers (or "None") |
| **User stories covered** | List of story numbers from the PRD |
| **End-to-end touchpoints** | Schema / API / UI / Tests / etc. |
| **Acceptance criteria** | Bulleted, observable, demoable |

### Step 4 — Quiz the user

Present the breakdown. Ask **all four** questions explicitly:

1. **Granularity** — Does this feel right? Too coarse / too fine?
2. **Dependencies** — Are the "Blocked by" relationships correct?
3. **Splits + merges** — Should any slice be split further? Any pair that should be merged?
4. **HITL/AFK classification** — Are the right slices marked HITL vs AFK?

Iterate until the user **approves the breakdown**. Do not skip iteration; the cost of one more round is low, the cost of mis-scoped issues compounds.

If the user's pushback reveals the PRD itself is wrong (unstated assumption, contradiction, missing requirement) → **stop**. Go back to PRD protocol to amend. Don't try to slice around a broken PRD.

### Step 5 — Create the issues

Create issues in **dependency order** (blockers first) so you can reference real issue numbers in "Blocked by" fields.

Use the template below. One issue per slice. Each issue is **self-contained**:

- Reference the parent PRD by issue number, don't duplicate its content
- Make acceptance criteria observable (someone other than Claude can verify)
- Make "Blocked by" explicit (or "None")

Use the platform's CLI:

```bash
gh issue create --title "<title>" --body "$(cat issue-body.md)" --label "tracer-bullet"
```

For non-GitHub platforms, adapt the CLI but keep the content shape.

**Do NOT close, edit, or modify the parent PRD issue.** It stays as the durable record.

## Issue Template

```markdown
## Parent PRD

#<prd-issue-number>

## What to build

A concise description of this vertical slice. Describe the **end-to-end behavior**,
not layer-by-layer implementation. Reference specific sections of the parent PRD
rather than duplicating content.

## Acceptance criteria

- [ ] Criterion 1 (observable, demoable)
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- #<issue-number> — <one-line reason>

(or "None — can start immediately" if no blockers.)

## User stories addressed

Reference by number from the parent PRD:

- User story 3
- User story 7
- User story 11

## Type

HITL — needs <specific human input mid-flight>

(or AFK — fully implementable end-to-end.)

## Touchpoints

- Schema: <table / migration name or "none">
- API: <endpoint or "none">
- UI: <component / route or "none">
- Tests: <unit / integration / E2E>
```

## Anti-patterns

| Anti-pattern | Why bad |
|---|---|
| Horizontal-layer slicing ("schema PR" → "API PR" → "UI PR") | Nothing demoable until last PR; blocks parallel work; sunk cost on mid-stream cancellation |
| One mega-issue covering the whole PRD | Can't parallelize; no checkpoint; hard to merge incrementally |
| Implicit dependencies (no "Blocked by" field) | SDP picks up an issue that secretly needs another to ship first; rework |
| HITL/AFK left unspecified | Operator surprised mid-flight by a "wait, I need to decide X" |
| Duplicating PRD content into every issue | Drift between PRD and issues; one updates, the other doesn't |
| Specifying file paths in the issue body | Rot quickly during implementation; SDP figures them out from the PRD |
| Skipping the quiz step | Slicing is one of the highest-leverage places for user input; don't optimize past it |
| Creating issues out of dependency order | "Blocked by #—" placeholder rot when you forget to fill it in |
| Tracer bullets that don't actually trace through every layer | Defeats the whole point; slice ships, demo fails |

## Relationship to other protocols

| Protocol | Relationship |
|---|---|
| **PRD** | Upstream — produces the artifact this protocol consumes |
| **SDP** | Downstream — each created issue feeds exactly one SDP loop |
| **NLF** | This protocol inherits NLF — claims about codebase touch points are GNGM-verified |
| **GNGM** | Step 2 IS the GNGM pre-decomposition sweep |
| **IMPROVE-ARCHITECTURE** | If Step 2 surfaces deep architectural friction in the PRD's touch path, run IMPROVE-ARCHITECTURE issues FIRST and mark feature issues as blocked-by them |
| **NATURAL-STOP-HANDOFF** | If decomposition spans sessions, NSH preserves the in-progress slice list |
| **GIT-HYGIENE** | Each issue's eventual implementation follows the WIP-commit / push cadence |

## Calibration

A typical PRD produces **3-12 vertical-slice issues**. Less than 3 = under-sliced (the PRD was probably small enough to skip this protocol). More than 12 = either the PRD is too big (split it) or the slicing is over-fine (merge thin pairs).

Each slice should be **1-3 days** of focused work for a single agent / developer. A slice that's >5 days is probably 2-3 slices in disguise.

If you find yourself drafting a slice and reaching for "Phase 1" / "Phase 2" sub-tasks inside it → that's the signal to split it into multiple slices.

## Related

- [PRD.md](PRD.md) — The upstream protocol that produces the artifact this consumes
- [SDP.md](SDP.md) — Standard Development Protocol (one SDP loop per created issue)
- [IMPROVE-ARCHITECTURE.md](IMPROVE-ARCHITECTURE.md) — If touch path needs deepening, run this first
- [NLF.md](NLF.md) — Truth discipline
- [NATURAL-STOP-HANDOFF.md](NATURAL-STOP-HANDOFF.md) — Multi-session decomposition handoff
- [GIT-HYGIENE.md](GIT-HYGIENE.md) — Commit cadence for the eventual implementation

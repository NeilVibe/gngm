---
name: PRD — Product Requirements Document Protocol
description: Interactive PRD creation through user interview, GNGM-grounded codebase exploration, and deep-module sketching. Closes the front-of-funnel gap where SDP currently assumes a spec already exists. Output is a single PRD document (GitHub issue, Linear, or local markdown) that downstream protocols (PRD-TO-ISSUES → SDP) consume.
type: gngm-protocol
version: 1
last_verified: 2026-04-27
trigger: PRD (explicit) OR user says "write a PRD" / "let's spec this" / "what should this feature do"
---

# PRD — Product Requirements Document Protocol

> **Purpose.** SDP starts with "the plan." This protocol creates the artifact that produces the plan. It's the missing front-of-funnel step that prevents Claude from drifting into implementation before the problem is even understood.

## Why this exists

Without an explicit PRD step, the failure mode is predictable:

1. User says "let's add feature X."
2. Claude jumps to SDP Step 1 (Brainstorm) and writes a plan.
3. The plan is technically sound but solves the wrong problem because the user's actual goal was never extracted.
4. Implementation ships, user says "this isn't what I meant."
5. Two more SDP cycles to course-correct.

The cost of one PRD interview (10-30 min) is much lower than the cost of two wrong implementations. PRD is the gate that catches "we agreed on the words but not the meaning."

PRD also produces a **durable artifact** that survives `/clear`, becomes the parent issue for `PRD-TO-ISSUES`, and gives future-Claude (and human collaborators) a single source of truth for "why are we building this?"

## When PRD fires

Use PRD when **any** of these are true:

- The feature touches multiple modules / surfaces (frontend + backend + DB)
- The user's mental model and the codebase's current behavior diverge
- There are unstated assumptions about user-facing behavior
- The work will span more than one session
- A non-Claude collaborator will eventually pick up the implementation
- The change has externally-visible consequences (API contract, UX, data shape)

**Skip PRD when:**

- Pure bug fix with one symptom and one root cause → SDP is enough
- One-line config / cosmetic change → SDP verify-only certificate
- Refactor with no behavior change → use IMPROVE-ARCHITECTURE protocol instead
- The "PRD" already exists (issue, spec, design doc) → skip to PRD-TO-ISSUES

## The 5 steps

### Step 1 — Get the long form

Ask the user for a **long, detailed description** of the problem they want to solve plus any solution ideas they already have.

Don't accept "let's add login." Push for:

- What does the user observe today that's broken / missing?
- What would they observe after this ships?
- Who is the user? (Specific persona, not "users.")
- What's the trigger? (When does this matter?)
- What ideas have they already considered + rejected?

If the user gives a 1-line answer, push back: "That's the headline. Can you tell me the longer version?"

### Step 2 — GNGM the codebase

Verify the user's assertions against reality. Run all four GNGM tools **in parallel** (one message, multiple tool calls):

```
Graphiti search   → "What connects to <feature area>?"
Graphiti search   → "What changed about <feature area>?"
Viking search     → "<feature area> + related domain terms"
NeuralTree match  → ["symptoms the user described"]
Memory search     → "<feature area> rules + preferences"
Graphify query    → "what calls <relevant entity>"
```

The point: **catch the gap between user mental model and current code state before designing the solution.** If the user says "we don't have rate limiting," confirm it. If they say "the cart works fine in offline mode," verify it.

Report findings explicitly. "You said X. The code shows Y. Which is the actual goal?"

### Step 3 — Interview relentlessly

Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

This is the part that feels rude in normal conversation but is **load-bearing** for PRD quality. Examples of branch-walking:

- "When the user does X, what should they see?"
- "What if X happens during Y? What's the priority?"
- "Who owns this state — server or client?"
- "Is this synchronous or eventual? What does the UI show during the gap?"
- "What's the failure mode? Hard error? Silent retry? Degraded UX?"

Don't move past a branch until **shared understanding is confirmed**. Re-state the user's answer in your own words before continuing: "So we're saying when X fails, we surface a toast with retry CTA — not a modal — and the underlying state stays optimistic until the retry confirms?"

If the user says "I don't know yet, you decide" → push back with 2-3 concrete options + your recommendation. Don't accept abdication; PRD is the place to make these calls.

### Step 4 — Sketch deep modules

Identify the modules that will be built or modified. Actively look for opportunities to extract **deep modules** (Ousterhout — small interface hiding a large implementation) that can be tested in isolation.

For each candidate module:

| Field | Content |
|---|---|
| **Name** | What it's called (use the ubiquitous-language terms — see UBIQUITOUS-LANGUAGE protocol) |
| **Interface** | The 1-3 entry points it exposes |
| **Hides** | What complexity lives behind the interface |
| **Tests** | Boundary tests that would validate it |

Check with the user:

- Do these modules match your mental model?
- Which modules do you want explicit test coverage for?
- Are any of these tightly coupled to existing modules in a way that needs deepening first? (If yes → consider IMPROVE-ARCHITECTURE protocol on the existing modules before this PRD.)

### Step 5 — Write the PRD

Use the template below. Save to:

- **GitHub issue** if the project tracks PRDs in GitHub (default)
- `docs/superpowers/specs/<YYYY-MM-DD>-<topic>.md` if the project uses local markdown specs
- **Linear / Notion / etc.** if the user explicitly says so

The PRD must be **self-contained**. A new collaborator (human or AI) reading only the PRD must be able to understand the problem, the solution shape, and the success criteria without further context.

## PRD Template

```markdown
# <Feature name>

## Problem Statement

The problem the user is facing, from the user's perspective.

(What do they observe today? What's the friction? Why does it matter?)

## Solution

The solution to the problem, from the user's perspective.

(What do they observe after this ships? Stay user-facing — not implementation.)

## User Stories

A LONG, numbered list. Each in the format:

1. As a <actor>, I want a <feature>, so that <benefit>.

Example:
1. As a mobile bank customer, I want to see balances on my accounts, so that I can make better-informed spending decisions.

This list should cover ALL aspects of the feature — happy paths, edge cases,
permission boundaries, multi-actor scenarios, error states, recovery flows.
20+ stories is normal for a non-trivial PRD.

## Implementation Decisions

Decisions made during the interview:

- Modules being built / modified (names + interfaces, no file paths)
- Architectural decisions (sync vs eventual, server vs client state, etc.)
- Schema changes (logical, not column-by-column)
- API contracts (shape of the wire format)
- Specific interactions (what the UI does in state X)

Do NOT include specific file paths or code snippets — they rot quickly.

## Testing Decisions

- What makes a good test for this feature (test external behavior, not internals)
- Which modules will have explicit test coverage
- Prior art (similar tests already in the codebase to mirror)

## Out of Scope

A short list of things explicitly NOT in this PRD. This is as important as what's in.

## Further Notes

Anything else: open questions for follow-up PRDs, dependencies on other work,
risks, performance budgets, accessibility commitments, etc.
```

## Anti-patterns

| Anti-pattern | Why bad |
|---|---|
| Skipping Step 2 (GNGM verification) | User mental model and codebase reality drift; PRD ships solving the wrong problem |
| One-question interviews | Every PRD branch hides 3-5 sub-decisions; one question can't surface them |
| Accepting "you decide" abdication | The whole point of PRD is to make decisions explicit; if Claude decides silently, the PRD is fictional |
| Specifying file paths in the PRD | They rot in days; downstream issues use them; whole tree breaks on rename |
| Writing the PRD before the interview is done | Document becomes a sales pitch instead of a record |
| Skipping deep-module sketching | PRD becomes a wishlist; implementation discovers structure on the fly |
| Bundling multiple features into one PRD | Hard to slice into vertical issues; usually means 2-3 PRDs |
| Skipping ubiquitous-language alignment | PRD uses term X, codebase uses term Y, downstream confusion compounds |

## Relationship to other protocols

| Protocol | Relationship |
|---|---|
| **NLF** | PRD inherits NLF — every claim about current state is verified against code, not asserted from memory |
| **GNGM** | PRD Step 2 IS the GNGM pre-task sweep, scoped to feature design |
| **UBIQUITOUS-LANGUAGE** | Run before / during PRD interview if domain terms are ambiguous; PRD reuses the canonical glossary |
| **IMPROVE-ARCHITECTURE** | If Step 4 surfaces shallow modules in the touch path, run IMPROVE-ARCHITECTURE on them BEFORE the PRD-TO-ISSUES breakdown |
| **PRD-TO-ISSUES** | The downstream protocol — converts the PRD into vertical-slice issues, each of which becomes one SDP loop |
| **SDP** | Each issue created by PRD-TO-ISSUES is implemented under SDP discipline |
| **NSH** | If a PRD interview spans multiple sessions, NSH preserves the interview state in the handoff |

## Calibration

A good PRD interview takes **10-30 minutes** of operator-visible work for non-trivial features. If it takes less, you're skipping branches. If it takes more than 60 minutes, the feature is probably 2-3 PRDs in disguise — split it.

The PRD document itself is typically **150-400 lines** of markdown. Less = under-specified. More = either the feature is too big or the document includes implementation details that belong in downstream issues.

## Related

- [SDP.md](SDP.md) — Standard Development Protocol (consumes PRD-TO-ISSUES output, one SDP loop per issue)
- [PRD-TO-ISSUES.md](PRD-TO-ISSUES.md) — Vertical-slice decomposition (downstream of PRD)
- [UBIQUITOUS-LANGUAGE.md](UBIQUITOUS-LANGUAGE.md) — Domain terminology (PRD reuses the glossary)
- [IMPROVE-ARCHITECTURE.md](IMPROVE-ARCHITECTURE.md) — Run on shallow modules in the PRD touch path before slicing into issues
- [NLF.md](NLF.md) — Truth discipline (PRD claims are code-verified, not memory-asserted)
- [NATURAL-STOP-HANDOFF.md](NATURAL-STOP-HANDOFF.md) — NSH preserves multi-session PRD interview state

## Docs

- `../docs/02-PROTOCOL.md` — GNGM 4-mode mechanics PRD Step 2 uses
- `../docs/05-PROJECT-STRUCTURE.md` — where to save PRDs in the project tree
- `../README.md` — protocol cluster overview (PRD lives in product / scoping cluster)

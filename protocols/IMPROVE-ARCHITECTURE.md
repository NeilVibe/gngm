---
name: IMPROVE-ARCHITECTURE — Codebase Architectural Audit Protocol
description: Explore a codebase to find opportunities for architectural improvement, focusing on deepening shallow modules per Ousterhout's "A Philosophy of Software Design." Surfaces friction organically (not via rigid heuristics), spawns 3+ parallel sub-agents to design competing interfaces for chosen candidates, and produces an opinionated recommendation as a refactor RFC. Complements RAC at the L3 (Execution) layer where module shape determines testability, AI-navigability, and integration risk.
type: gngm-protocol
version: 1
last_verified: 2026-04-27
trigger: IMPROVE-ARCHITECTURE / IA (explicit) OR user says "find refactoring opportunities" / "what's tightly coupled here?" / "make this more testable" / "deepen this module" / quarterly architecture audit
---

# IMPROVE-ARCHITECTURE — Codebase Architectural Audit Protocol

> **Purpose.** Most refactoring requests are reactive ("this is hard to test" or "this keeps breaking"). This protocol is proactive: explore the codebase like a new collaborator would, notice the friction, and propose **deep-module redesigns** that reduce future friction. Output is one refactor RFC per chosen candidate, spec'd through 3+ competing interface designs.

## Why this exists

Ousterhout's central thesis: a **deep module** has a small interface hiding a large implementation. A **shallow module** has an interface nearly as complex as its implementation. Shallow modules:

- Multiply integration risk (every shallow seam is a place bugs hide)
- Resist testing (you end up testing implementation details, not behavior)
- Resist AI navigation (Claude bounces between many small files to understand one concept)
- Compound across years (each new feature adds another shallow layer)

Most codebases drift toward shallow over time. The pull request that "extracts a helper for testability" often makes things worse — the helper is a pure function but the real bug hides in how it's called.

This protocol exists because shallow-module drift is **invisible to grep, lint, and code review.** It only shows up as friction when you try to understand or change the code. The protocol's job: make that friction visible, then turn it into an opinionated proposal.

The other reason: **GNGM's other protocols handle the project surface, but the L3 Execution layer (per RAC) is where module shape matters.** RAC handles pipeline shape; this handles internal-module shape. They're orthogonal — both can be wrong independently.

## When IMPROVE-ARCHITECTURE fires

Use IA when **any** of these are true:

- User explicitly asks ("find refactoring opportunities," "make this more testable")
- Mid-PRD when Step 4 (deep-module sketching) reveals existing modules are too shallow to build on
- Mid-SDP when Step 1 (Brainstorm) keeps stumbling over the same coupling
- Quarterly audit (see "Cadence" below)
- After a debugging session where multiple bugs traced to the same architectural seam
- When new collaborator (human or AI) reports "I keep getting confused about how X works"

**Skip IA when:**

- You have a specific bug to fix → use SDP / DEBUG instead
- You have a specific feature to build → use PRD / SDP instead
- The codebase is genuinely greenfield → IA needs surface area to audit
- Time-pressured ship is imminent — IA is not a last-mile activity

## The 7 steps

### Step 1 — Explore organically

Use the `Agent` tool with `subagent_type=Explore` to navigate the codebase **the way a new collaborator would.** Do NOT follow rigid heuristics. The goal is to **notice friction**, not to grade against a checklist.

While exploring, watch for:

- Where does understanding one concept require bouncing between many small files?
- Where are modules so shallow that the interface is nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called?
- Where do tightly-coupled modules create integration risk in the seams between them?
- Which parts of the codebase are untested or hard to test?
- Where does the same domain concept live in 3 files instead of 1?

**The friction you encounter IS the signal.** Note it as you go.

You may also pull GNGM context to ground exploration:

```
Graphify query  → "what calls <central entity>"  → caller fan-out (shallow signal)
Viking search   → "<feature area>"               → doc/code clusters
Graphiti search → "what changed about <module>"  → churn hotspots
NeuralTree      → ["bug patterns in <area>"]     → past pain
```

High caller fan-out + high churn + multiple past bugs = strong deepening candidate.

### Step 2 — Present candidates

Present a numbered list of **deepening opportunities**. For each candidate:

| Field | Content |
|---|---|
| **Cluster** | Which modules / concepts are involved (use the canonical vocabulary from UBIQUITOUS-LANGUAGE if available) |
| **Why coupled** | Shared types, call patterns, co-ownership of a concept, repeated migration churn |
| **Dependency category** | One of: in-process / local-substitutable / remote-but-owned (ports & adapters) / true-external (mock) — see "Dependency categories" below |
| **Test impact** | What existing tests would be replaced by boundary tests on the deepened module |
| **Friction signal** | What you encountered during exploration that flagged this |

**Do NOT propose interfaces yet.** Ask: "Which of these would you like to explore?"

The point of separating Step 2 (candidates) from Step 5 (designs) is that interface design is expensive (3+ parallel sub-agents) and shouldn't be spent on candidates the user doesn't care about.

### Step 3 — User picks a candidate

Wait for explicit selection. Don't proceed multi-candidate in parallel — each candidate gets its own design pass for cognitive coherence.

### Step 4 — Frame the problem space

Before spawning sub-agents, write a **user-facing explanation of the problem space** for the chosen candidate:

- The constraints any new interface would need to satisfy
- The dependencies it would need to rely on
- A rough illustrative code sketch to make the constraints concrete (this is NOT a proposal — it's a way to ground the constraints)

Show this to the user, then **immediately proceed to Step 5**. The user reads and thinks about the problem space WHILE the sub-agents work in parallel. Don't wait for user input here — the user can interject during Step 5 if they spot a constraint you missed.

### Step 5 — Design 3+ competing interfaces (parallel sub-agents)

Spawn **3+ sub-agents in parallel** using the `Agent` tool (single message, multiple `Agent` tool calls). Each sub-agent must produce a **radically different** interface design. They should not converge on the same shape — that defeats the parallel-design point.

Give each sub-agent a separate technical brief (file paths, coupling details, dependency category, what's being hidden). The brief is **independent of the user-facing explanation in Step 4** — sub-agents don't need the meta-narrative.

Assign each sub-agent a **different design constraint**:

| Sub-agent | Constraint |
|---|---|
| **Agent 1** | "Minimize the interface — aim for 1-3 entry points max" |
| **Agent 2** | "Maximize flexibility — support many use cases and extension" |
| **Agent 3** | "Optimize for the most common caller — make the default case trivial, edge cases possible-but-explicit" |
| **Agent 4** *(if applicable)* | "Design around ports & adapters for the cross-boundary dependency" |
| **Agent 5** *(rare)* | "Prove this candidate is NOT worth deepening — design the strawman that justifies leaving it as-is" |

Each sub-agent outputs:

1. **Interface signature** — types, methods, params
2. **Usage example** — how callers invoke it
3. **What complexity it hides** — the implementation that's now behind the interface
4. **Dependency strategy** — how external deps are handled (per the dependency category)
5. **Trade-offs** — what the design optimizes for + what it sacrifices

### Step 6 — Compare + recommend (be opinionated)

Present the designs **sequentially** (each as its own block — don't merge into one table; the comparison is qualitative).

Then write a **prose comparison** across 3-5 dimensions (e.g., testability, caller ergonomics, extensibility, refactor cost, AI-navigability).

Then **give your own recommendation:** which design you think is strongest and **why**. Be opinionated — the user wants a strong read, not a menu.

If elements from different designs would combine well → propose a **hybrid** explicitly. Don't hedge.

### Step 7 — Create the refactor RFC

Once the user picks an interface (or accepts your recommendation), create a **refactor RFC** as a GitHub issue using `gh issue create` (or the platform equivalent). Use the template below.

**Do NOT ask the user to review before creating.** Just create it and share the URL. The RFC is a starting point for downstream refactor work; if the RFC needs amendment, that happens in PRs against the issue.

## Dependency categories (load-bearing)

When assessing a candidate, classify its dependencies:

### 1. In-process

Pure computation, in-memory state, no I/O. **Always deepenable** — merge the modules and test directly.

### 2. Local-substitutable

Dependencies that have local test stand-ins (PGLite for Postgres, in-memory filesystem, etc.). **Deepenable if the test substitute exists.** Tests run with the local stand-in.

### 3. Remote but owned (Ports & Adapters)

Your own services across a network boundary (microservices, internal APIs).

**Define a port (interface) at the module boundary.** The deep module owns the logic; the transport is injected. Tests use an in-memory adapter; production uses the real HTTP / gRPC / queue adapter.

Recommendation shape: "Define a shared port; implement an HTTP adapter for production and an in-memory adapter for testing, so the logic can be tested as one deep module even though it deploys across a network boundary."

### 4. True external (Mock)

Third-party services (Stripe, Twilio, OpenAI, etc.) you don't control. **Mock at the boundary.** The deepened module takes the external dependency as an injected port; tests provide a mock implementation.

## Refactor RFC Template

```markdown
## Problem

Describe the architectural friction:

- Which modules are shallow and tightly coupled
- What integration risk exists in the seams between them
- Why this makes the codebase harder to navigate, test, and maintain

## Proposed Interface

The chosen interface design:

- Interface signature (types, methods, params)
- Usage example showing how callers invoke it
- What complexity it hides internally

## Dependency Strategy

Which category applies and how dependencies are handled:

- **In-process**: merged directly
- **Local-substitutable**: tested with [specific stand-in]
- **Ports & adapters**: port definition, production adapter, test adapter
- **Mock**: mock boundary for external services

## Testing Strategy

Core principle: **replace, don't layer.**

- New boundary tests to write (describe behaviors at the interface)
- Old tests to delete (shallow-module tests that become redundant)
- Test environment needs (local stand-ins or adapters required)

## Implementation Recommendations

Durable architectural guidance NOT coupled to current file paths:

- What the module should own (responsibilities)
- What it should hide (implementation details)
- What it should expose (the interface contract)
- How callers should migrate to the new interface

## Migration plan

Coarse-grained sequence (downstream PRD-TO-ISSUES will refine into vertical slices):

1. Step 1 — define new interface, no callers yet
2. Step 2 — implement new module behind interface
3. Step 3 — migrate callers in batches (per dependency level)
4. Step 4 — delete old shallow modules + their tests
```

## Anti-patterns

| Anti-pattern | Why bad |
|---|---|
| Following rigid heuristics during exploration | Friction is the signal; checklists make you miss it |
| Proposing interfaces in Step 2 | Wastes parallel-sub-agent budget on candidates the user doesn't care about |
| Designing only 1-2 interfaces | Whole point is comparing radically different shapes; 1 design is just an opinion |
| Sub-agents converging on the same shape | Defeats parallel-design; redo with sharper constraints |
| Hedging in Step 6 ("either is fine") | User wants opinion; if you don't have one, do more exploration |
| Merging the design comparison into one table | Designs differ qualitatively; tables flatten the differences that matter |
| Skipping the user-facing problem-space writeup (Step 4) | User can't engage with the design without understanding constraints |
| Asking user to review the RFC before creating | RFC is a starting point; review happens in PRs against it |
| Proposing migration as one big-bang PR | Slow, risky, blocks parallel work; downstream PRD-TO-ISSUES handles slicing |
| Including specific file paths in the RFC's "Implementation Recommendations" | They rot quickly; downstream issues use them |

## Cadence (proactive use)

A useful cadence for codebases under active development:

| Trigger | Action |
|---|---|
| **Quarterly** | Run IA on each major subsystem (1 candidate per subsystem if any surface) |
| **After 3+ bugs in same area in 30 days** | IA on that area — bugs cluster around shallow seams |
| **Before major feature work** | IA on the feature's touch path; deepen FIRST, then build |
| **After ingesting unfamiliar code** | IA as a diagnostic — what does the friction tell you about the prior author's mental model? |

Don't run IA more than once a month on the same subsystem unless you've actually shipped the prior recommendations — auditing without acting compounds friction.

## Relationship to other protocols

| Protocol | Relationship |
|---|---|
| **PRD** | If PRD Step 4 (deep-module sketching) reveals existing modules are too shallow to build on, run IA on those modules FIRST |
| **PRD-TO-ISSUES** | The IA RFC, once approved, becomes a parent PRD that PRD-TO-ISSUES decomposes into refactor slices |
| **SDP** | Each refactor slice is implemented under SDP discipline (RED → GREEN per migration step) |
| **RAC** | RAC handles pipeline shape (cross-action contracts); IA handles module shape (within-action implementation). Orthogonal — both can be wrong independently |
| **NLF** | IA inherits NLF — claims about current shallowness, coupling, and dependency categories are GNGM-verified, not memory-asserted |
| **GNGM** | Step 1 (Explore) uses Graphify + Viking + Graphiti + NeuralTree to ground the friction observation |
| **UBIQUITOUS-LANGUAGE** | Module names + interface names use canonical vocabulary; if vocab is missing, run UL alongside IA |
| **DEBUG** | If IA was triggered by a debug session that surfaced repeated bugs, DEBUG's WC-NNN case study is the input evidence |
| **NATURAL-STOP-HANDOFF** | If IA spans sessions (common for large audits), NSH preserves the candidate list + chosen designs |

## Calibration

A first IA pass on a non-trivial codebase surfaces **5-15 candidates**. Less than 5 = the codebase is genuinely well-shaped (rare) OR the explorer was too shallow. More than 15 = the codebase has years of drift; consider scoping the audit to one subsystem at a time.

A typical session through Steps 1-7 takes **45-90 minutes** for one chosen candidate (longer if the parallel sub-agent designs require iteration). Audit-only sessions (Steps 1-2 only, no candidate picked) take **30-45 minutes**.

If Step 5 sub-agents take longer than 5 minutes each, the brief was probably too vague — sharpen the constraint and respawn.

## Related

- [SDP.md](SDP.md) — Standard Development Protocol (consumes IA's RFC via PRD-TO-ISSUES)
- [PRD.md](PRD.md) — If PRD Step 4 surfaces shallow modules, run IA first
- [PRD-TO-ISSUES.md](PRD-TO-ISSUES.md) — Decomposes IA RFCs into refactor slices
- [RAC.md](RAC.md) — Pipeline-shape methodology; complements IA at the L3 layer
- [DEBUG.md](DEBUG.md) — Debug case studies often reveal IA candidates
- [UBIQUITOUS-LANGUAGE.md](UBIQUITOUS-LANGUAGE.md) — Module / interface names use canonical vocabulary
- [NLF.md](NLF.md) — Truth discipline (claims about coupling are code-verified)
- [GNGM] (`docs/02-PROTOCOL.md` in the GNGM root) — knowledge-stack mechanics IA Step 1 uses
- Ousterhout, "A Philosophy of Software Design" — the deep-module thesis underlying this protocol

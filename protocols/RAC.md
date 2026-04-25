---
name: RAC — Repeatable Action Chain
description: Methodology for building repeatable, auditable, invariant-tested chains of actions that transfer across domains. Universal base discipline — applies to any multi-step process, software or otherwise.
trigger: RAC
---

# RAC — Repeatable Action Chain

> **Pronounced** /ræk/ (rhymes with "rack"). Three letters; three concepts: **R**epeatable, **A**ction, **C**hain.

> Naming note: Oracle Real Application Clusters also uses "RAC." Scoped collision — Oracle DBAs might briefly pause. For universal methodology use, write "Repeatable Action Chain" on first mention.

## What this is

A **RAC** is a discipline for building workflows that:

1. **Run the same way every time** (Repeatable),
2. **Are composed of discrete, typed units of work** (Actions),
3. **Compose into chains where individual links can be re-run** (Chain).

Three words describe the surface. Ten invariants define the substance. Five layers describe the anatomy. Seven failure modes describe what goes wrong when invariants are skipped.

## Why RAC matters

You only get better at something by doing it repeatedly. You get *compounding* improvement only when you do it the same way each time — because sameness is what lets you measure deltas, automate stages, and transfer patterns to new domains.

The default human instinct is to do each task *a little differently* each time: new vocabulary, new layout, new tools, "a few tweaks." This feels adaptive; it is the enemy of compounding. Every variant resets the learning curve.

RAC is the discipline of **intentionally forcing repeatability on a process that would otherwise drift** — while explicitly preserving the parts that legitimately should vary (inputs, parameters, domain-specific language).

Value shows up as:
- **Fewer 3am incidents** — invariant tests catch drift before prod does.
- **Faster onboarding** — operators execute step-by-step without tribal knowledge.
- **Cross-project transfer** — patterns that took three bug-discovery iterations to harden in project A move to project B in 30 minutes.
- **Audit-readiness** — every run is evidentiary; "prove this happened on day X at time Y" has a provable answer.
- **Honest debugging** — "did action 3 run?" is a yes/no question with a row-level answer.

Civilization already runs on RACs: scientific method, court procedure, drug trials, assembly lines, peer review, double-entry bookkeeping, election administration. When a RAC is done well, it fades into infrastructure. When it is absent, the absence is visible: fraud, drift, unreproducible results, lost audit trails, tribal-knowledge bottlenecks.

## The three words unpacked

### Repeatable
Same inputs → same observable outputs. Re-runnable by any operator. Failure modes documented, not surprises. Re-runs leave evidence (new row, new log) — never silent overwrites.

**Test of repeatability:** write the actions on paper; hand them to a new person; they should produce the same result you do. If not, it isn't repeatable.

### Action
A discrete unit of work. Has ONE responsibility. Takes typed input. Emits typed output or typed error. Doesn't share mutable state with other actions.

**Test of action-ness:** can you name what the action does in 5 words? Is the input contract written in code (not prose)? If not, you have a blob masquerading as an action.

### Chain
Actions compose. Output of one action is (or feeds) input of the next. **"Chain" in RAC means directed acyclic graph** — branching and merging are still chains from the node perspective. Chains have explicit start and end states, are resumable from any failed link, and compose into larger chains.

**Test of chain-ness:** if action A breaks, can downstream action B still run in a degraded mode from cached or mocked input? If not, A and B aren't chained — they're coupled.

## The 10 invariants

Axioms. Violate any and it is not really a RAC — it is a "process that someone hopes is repeatable."

### I1 — Contract-First
Every action has a written schema for input, output, and error shapes. Schemas live in code (Pydantic / TypeScript / JSON Schema / protobuf), not in a README that can drift.
*Why:* without a contract, "compatible" is a debate, not a test.

### I2 — Every Action Observable
Every action emits at least one trace on completion (row, log, metric, event). Invisible actions are forbidden.
*Why:* debugging cost is multiplicative in the number of dark actions.

### I3 — Failure Loud, Not Silent
Errors propagate as explicit failure states. No catch-and-ignore. Silent fallbacks forbidden. If a fallback exists, it is declared, typed, and logged.
*Why:* silent degradation is the bug that takes weeks to find.

### I4 — Idempotent OR Explicitly Append-Only
Re-runs produce the same result (idempotent), OR explicitly append to a history (append-only log). Never silently "update with a different result."
*Why:* these are the only two modes that keep re-runs debuggable. A third mode (silent update) creates "it worked the first time" Heisenbugs.

### I5 — Corroboration Across Actions
Downstream actions validate upstream claims. Trust but verify. If action 3 depends on action 2 having produced X, action 3 checks X rather than assumes.
*Why:* without corroboration, a bug in action 2 silently poisons every downstream action and the audit trail.

### I6 — Temporal Invariants Are Queryable
Required orderings ("A happened before B") are DB-queryable facts, not unstated assumptions. Tests assert them directly.
*Why:* temporal assumptions rot. What was "obviously" ordered becomes a race at scale.

### I7 — Bounded Resource Consumption
Every chain has budget / rate / time caps with pre-flight checks. No unbounded loops.
*Why:* unbounded processes create incidents (disk fills, bills spike, APIs throttle).

### I8 — Tested By Proof, Not By "No Exception"
Tests assert invariants directly ("viewed_at precedes rolled_at"), not just that the call completed. Happy-path coverage is recognized as insufficient.
*Why:* no-exception tests catch easy bugs. Hard bugs — wrong order, wrong sign, wrong aggregate — need property assertions.

### I9 — Resumable From Any Failed Link
Failed runs restart from the last completed action. Not from the beginning (wasteful) or from an arbitrary point (unsafe).
*Why:* production can't afford "start over."

### I10 — Transfer-Ready Documentation
The RAC ships with a recipe doc: what this is, when to use, known failure modes (numbered), how to apply in another project.
*Why:* without a recipe, the pattern lives in the author's head.

### The non-negotiable 4 (starter subset)

If 10 invariants feels like too much to hold in mind, the minimum viable subset is **I1, I2, I8, I10**:

- **I1 (contract)** forces typed handoffs → downstream reliability.
- **I2 (observable)** makes debugging tractable.
- **I8 (invariant tests)** catches silent drift.
- **I10 (recipe)** enables transfer.

I3–I7 and I9 tend to *emerge* from doing these four well. When they don't emerge, add them deliberately. **Start with 4; grow into 10.**

## The 5 layers

| Layer | Contents | Failure signature |
|---|---|---|
| **L1 Contract** | Input / output / error schemas. Versioned. | Actions drift silently. |
| **L2 Orchestration** | Sequencing, retry, timeout, backoff, resumability. | Cannot restart from failure. |
| **L3 Execution** | Actual work: compute, I/O, API calls, DB writes. | Domain logic tangled with infra. |
| **L4 Observability** | Logs, metrics, traces, audit rows. Every action emits. | Dark actions; debugging intractable. |
| **L5 Verification** | Tests, invariants, monitoring alerts. | Silent drift; production surprises. |

**Rule of thumb:** if you can't point to an artifact for each layer, the RAC is incomplete. Common failure: strong L3 (lots of code), weak L5 (few invariant tests) — looks sophisticated, is actually brittle.

## Cross-field gallery — 12 fields, same shape

| Field | Chain (actions) | Signature invariant | Cost of absence |
|---|---|---|---|
| Software CI/CD | commit → build → test → deploy → monitor | `build_hash == deployed_hash` | silent drift |
| Data ETL | extract → validate → transform → load → reconcile | `row_count_in == row_count_out` | data loss |
| ML training | collect → clean → train → eval → deploy → monitor | `eval_metric > threshold` | silent degradation |
| Scientific research | observe → hypothesize → design → run → analyze → peer-review → publish | treatment isolated from control | replication crisis |
| Drug trial | preclinical → Phase I → II → III → FDA → post-market | safety signal acted on each phase | adverse events at scale |
| Trade execution | order → validate → route → execute → clear → settle | `trade_id` consistent across rows | failed settlement |
| Chain of custody | collect → log → transport → store → analyze → present | no unlogged gap | evidence inadmissible |
| Manufacturing | parts → sub-assembly → QC → final → test → ship | each unit serialized | recall scope unknowable |
| Editorial publishing | draft → edit → fact-check → legal → publish → correct | every claim sourced | defamation / retraction |
| Gacha roll (winacard) | tap → RNG → pull_log → vault → animation | hash chain unbroken | unprovable fairness |
| Compliance audit (winacard) | view disclosure → record → corroborate → store → query | `viewed_at < rolled_at` | 전자상거래법 fine |
| Asset generation (winacard) | prompt → generate → review → approve → store → publish | `cost ≤ budget` AND `IP-original` | overspend / IP leak |

If your field isn't here, write the row. If every column fills plausibly, you have a RAC-able workflow.

## The 7 failure modes

Paired with invariants.

### F1 — Silent drift (violates I2, I6)
Output shifts over time; same inputs produce gradually different results.
*Fix:* invariant test vs reference; monitor delta between runs.

### F2 — Untested invariants (violates I8)
Test suite green; production fails on "impossible" state.
*Fix:* assert properties, not exception-absence. Property-based testing (Hypothesis) for combinatorial coverage.

### F3 — Mock-vs-real divergence (violates I5)
Every test green, first live run fails.
*Fix:* at least one live-smoke test per external integration. Contract tests replaying real responses.

### F4 — Dark actions (violates I2)
Failure attributed to "something in the middle"; no one knows where.
*Fix:* L4 on every action. Alert on actions that haven't emitted in N minutes.

### F5 — Budget overrun (violates I7)
Costs balloon; rate limits trip; disk fills.
*Fix:* pre-flight cost check at L2; alert at 75% of cap; block at 100%.

### F6 — Tribal knowledge (violates I10)
Only one person can run it; ops break when they're on vacation.
*Fix:* write the recipe. Have someone else execute cold from only the recipe.

### F7 — Pattern ossification (violates I10)
Works but can't adapt to new domain; each port rewrites from scratch.
*Fix:* recipe includes "Repeating in another project" with copy-this-then-do-that steps. Separate domain-specific params from generic orchestration.

## Famous RAC failures (case studies)

Real-world incidents where the absence of RAC discipline caused measurable harm.

### Boeing 737 MAX MCAS — F4 (dark action) + F3 (mock vs real)
MCAS (Maneuvering Characteristics Augmentation System) automatically pushed the nose down based on a single angle-of-attack sensor reading. **Dark action:** the automation had no cockpit-visible indicator when active — pilots couldn't see which "action" was running. **Mock-vs-real:** simulator training did not expose the failure mode; live flight did. Result: two crashes, 346 deaths, global grounding.
**RAC lessons:** every action must be observable (I2); live-smoke must be distinct from simulated testing (I5 / F3).

### Theranos — F2 (untested invariants) + F5 (unbounded claims)
Blood-testing claims were never invariant-tested against reference labs. Venture capital funded unbounded scaling claims without verification. **F2:** no assertion that Theranos results matched established reference values on blind samples. **F5:** revenue projections unconstrained by validation reality.
**RAC lessons:** tests must assert properties, not just "process completed" (I8); claims must be bounded by what is verified (I7).

### GameStop short-squeeze clearing (Jan 2021) — F6 (tribal knowledge)
Depository Trust & Clearing Corporation (DTCC) raised collateral requirements overnight; tribal knowledge about how to calculate and dispute requirements created chaos in brokers' ability to process trades. **F6:** authoritative knowledge concentrated in a few operators. When stress hit, normal handoffs broke.
**RAC lesson:** the recipe (I10) must survive stress; resumability (I9) matters under load.

Pattern: each is a case where a RAC *could* have been built and wasn't — not an impossible problem.

## Smallest possible RACs

### Software — monthly invoice send

- **L1 Contract:** `Customer { id, email, amount_due, invoice_pdf }` → `{ customer_id, send_status, delivery_confirmed_at | bounce_reason }`.
- **L2 Orchestration:** monthly cron; retry 3× with 24h backoff; skip already-sent via output table.
- **L3 Execution:** `compose_invoice` → `send_via_ses` → `record_delivery`.
- **L4 Observability:** row per attempt in `invoice_send_log`, keyed `(customer_id, send_date)`.
- **L5 Verification:** every customer with `amount_due > 0` has either `delivery_confirmed_at` OR an escalation row within 7 days; no customer billed twice in a month.
- **Budget:** ≤1 email per customer per day; ≤$50 SES spend per month.
- **Recipe:** one-page — how to run, how to diagnose bounces, how to adapt to a new company's chart of accounts.

Five files, ~200 lines. Fully RAC-compliant.

### Non-software — monthly fire extinguisher inspection (commercial building)

- **L1 Contract:** `Extinguisher { id, location, last_inspected, pressure_reading, status: ok|expired|damaged }` → `InspectionRecord { extinguisher_id, inspector, timestamp, outcome, photos[] }`.
- **L2 Orchestration:** monthly schedule; failed extinguishers trigger work order; work order completion re-verifies.
- **L3 Execution:** walk the floor → scan QR codes → record pressure + visual check → photograph → submit.
- **L4 Observability:** paper/digital log; every extinguisher has an inspection history; missing this-month record = alert.
- **L5 Verification:** audit — every extinguisher has an inspection record within the last 30 days; expired units have a work order raised.
- **Budget:** ≤1 inspector-day per 100 extinguishers.
- **Recipe:** one-page training doc — what to check, how to record, how to escalate.

A building manager with no tech background can run this. A fire marshal can audit the RAC-ness of the process directly by asking: "show me your invariant (record within 30 days); show me your contract (what each inspection captures); show me your observability (log)."

**Same methodology. Different field. Same power.**

## When to apply

Use RAC discipline when any is true:
- Process will run 2+ times.
- Different operators will run it.
- Failures are expensive (regulatory, financial, reputational).
- Process must be auditable.
- You plan to port the pattern to another project / domain.
- You need to scale.

## When NOT to apply

Skip ceremony when:
- Genuinely one-off exploratory work.
- Process is already a standard primitive handled by a mature tool.
- Cost of ceremony exceeds value.

**Heuristic:** if RAC structure feels like overkill, check — will this run again? Will someone else run it? Both "no" → one-off, fine. Either "yes" → you are paying the cost of chaos by skipping RAC.

## Anti-patterns

| Anti-pattern | Seems OK because | Actual cost |
|---|---|---|
| "Just run it again" repeatability | Easy / free | No invariants; re-running rediscovers old bugs |
| Untyped interfaces | Less ceremony | "Compatible" is a debate |
| Implicit ordering | "Obviously A before B" | Scales to race |
| Silent retries | Hides transient errors | Masks systemic issues |
| Single-action monolith "chain" | Less code | Can't test actions independently |
| Config-only abstraction | "Portable" | Portable to one other thing; breaks on second transfer |
| Tests without invariants | Green CI | Production surprises |
| Pattern-as-library without recipe | "Just import it" | Consumer still rediscovers usage |

## State-of-mind checklist

Before building any multi-step process:

- If this runs 1000 times, what's true about every run?
- What's the observable proof each action ran correctly?
- If a new team member takes this over tomorrow, what do they need?
- If a regulator asks "prove this happened on day X," can I?
- If the primary author leaves, is this still operable?
- If I need this in another project, what's the minimum diff?
- Where is the budget cap?
- What breaks if action N silently corrupts data for action N+1?
- What's the resumption story if action N fails mid-run?
- Which of the 7 failure modes is this most vulnerable to?

## How to build a RAC from scratch

1. **Write the contract (L1) first.** Before any code.
2. **Decompose into actions.** Each ≤1 sentence of responsibility. "And" → split.
3. **Draw the chain.** Boxes and arrows. Label each arrow with its contract.
4. **Wire orchestration (L2).** Sequencing + retry + timeout + resumability.
5. **Implement actions (L3).** Typed in, typed out. ≤50 lines each. No shared mutable state.
6. **Instrument observability (L4).** Every action emits.
7. **Write invariant tests (L5).** At least one per invariant.
8. **Define the budget.** Cap, alert at 75%, block at 100%.
9. **Live-smoke.** Real external services. Watch for F3 and F4.
10. **Write the recipe (I10).** Full Markdown with standard sections.
11. **Have someone else run it cold.** Update the recipe where they stumble.

## How to audit an existing process for RAC-fitness

Score each question 0–10. Thresholds below are **heuristic** — calibrate against your own baseline by scoring 3–5 known-good processes to see where they land.

1. Can I draw the chain unambiguously?
2. Can any single action be re-run?
3. Does each action emit observability?
4. Tests assert invariants, not just no-exception?
5. Budget cap with pre-flight check?
6. Can a new operator execute from only the documentation?
7. Is a temporal invariant DB-queryable?
8. Does downstream corroborate upstream?
9. Are fallbacks explicit, typed, logged?
10. Is there a transfer recipe?

Suggested interpretation (calibrate to taste):
- **Below 60/100** → process running on luck; rewrite as RAC.
- **60–85** → mostly sound; targeted improvements on lowest-scoring items.
- **85+** → RAC-fit; maintain discipline on new additions.

## Compounding value (lived experience, not measured)

Claim drawn from lived experience across multiple projects, not from controlled measurement. Observed pattern:

- **First run** costs more than a one-off script — setup overhead.
- **Tenth run** is indistinguishable from the first — same observability, invariants, recipe.
- **Hundredth run** is automated — structure exposed enough for operators to build tooling.
- **Thousandth run** has dashboards, SLOs, runbook — infrastructure built by others around the stable base.
- **Second domain port** takes ~30 min — recipe transfers with 3–5 domain-specific changes.
- **Third domain port** takes ~15 min — author learns which parts to parameterize.
- **Fifth domain port** is near-free — the pattern IS the default for that problem class.

The compounding only works if discipline is maintained. One "just this once" exception resets the compounding: the next operator makes their own exception; the pattern rots.

If you have measured data on this, I'd love to see it.

## Related disciplines (keep-close)

Four disciplines that directly reinforce RAC thinking:

- **Scientific method** — observe → hypothesize → experiment → peer review. The archetype; every RAC is a specialization.
- **Chain of custody (legal)** — every step logged; gaps invalidate evidence. Contributes I5 (corroboration) and I4 (append-only).
- **Event sourcing (software)** — append-only log as source of truth; state is derived. Contributes I4.
- **Lean manufacturing (Toyota Production System)** — value streams, Andon cord (stop-the-line on defect), kanban. Contributes I3 (failure loudness) and L2 (orchestration thinking).

## Trigger

When the user says **`RAC`** or references a "pipeline / chain / repeatable workflow," this protocol activates. Self-invocation required whenever designing a multi-step process.

Minimum action on trigger: walk the state-of-mind checklist.
Full action: apply the "How to build from scratch" sequence.

## Related

- `~/.claude/rules/pipelines/voice-image-video-asset-generation.md` — worked example (multi-model asset generation, winacard Wave 4.8)
- `~/.claude/rules/pipelines/README.md` — pipelines index
- `docs/GNGM/protocols/SDP.md` — Standard Development Protocol (single-wave discipline that uses RAC at the architecture level)
- `docs/GNGM/protocols/NLF.md` — No-Lie-Fix (truth discipline that makes RAC observability trustworthy)
- `docs/GNGM/protocols/TDD.md` — Test-Driven Development (atomic-change discipline within RAC's L5)

## Docs

- Worked examples in `~/.claude/rules/pipelines/`
- Project-specific RAC instances in `docs/waves/*/SUMMARY.md` (each wave is typically a RAC instance)
- Failure-mode catalog in this file, §"The 7 failure modes"
- Case-study references in this file, §"Famous RAC failures"

## Changelog

- 2026-04-24 — **v1.** First full draft. 10 invariants, 5 layers, 12-field gallery, 7 failure modes, 3 case studies (Boeing 737 MAX, Theranos, GameStop), 2 smallest-possible examples (software invoice + non-software fire inspection), non-negotiable 4 subset, calibration-required audit heuristic, DAG clarification ("chain" includes branching), compounding value framed as lived experience. Written alongside two concrete winacard applications (voice/image/video asset pipeline, compliance audit trail).

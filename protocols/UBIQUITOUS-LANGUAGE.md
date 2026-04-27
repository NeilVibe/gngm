---
name: UBIQUITOUS-LANGUAGE — Domain Glossary Protocol
description: Extract a DDD-style ubiquitous language glossary from the current conversation, codebase, or PRD. Flags ambiguities (one word for many concepts, many words for one concept) and proposes canonical terms with aliases-to-avoid. Saves to UBIQUITOUS_LANGUAGE.md. Hooks into NSH so each session-close refreshes the project glossary; downstream protocols (PRD, SDP, NSH) reuse the canonical vocabulary.
type: gngm-protocol
version: 1
last_verified: 2026-04-27
trigger: UBIQUITOUS-LANGUAGE / UL (explicit) OR user says "build a glossary" / "what does X mean here?" / "let's pin down the terminology" OR auto-fires inside NSH if glossary is stale
---

# UBIQUITOUS-LANGUAGE — Domain Glossary Protocol

> **Purpose.** Most cross-session confusion comes from terminology drift, not from logic bugs. "User" means three different things in three different files. "Order" and "Purchase" both appear; one is the canonical, the other is alias rot. This protocol pins down the vocabulary so PRDs, code reviews, handoffs, and post-mortems all share the same nouns.

## Why this exists

Without an explicit glossary, the failure modes compound silently:

1. **PRD says "User."** Codebase has `User` (auth identity), `Customer` (billing identity), `Account` (ownership identity). Three concepts, one word. PRD interpretation depends on who's reading.
2. **Two engineers (or two AI agents) use synonyms.** One writes `Order`, another writes `Purchase`. Future-search misses half the relevant code.
3. **NeuralTree lessons drift from current vocabulary.** Symptom-match queries fail because lessons use 2024 terms; codebase uses 2026 terms.
4. **Post-mortems contradict.** Same incident described in two terms; root-cause analysis splits.

Fix: extract the canonical glossary explicitly. Be opinionated. Mark aliases-to-avoid. Re-run when terms drift.

## When UBIQUITOUS-LANGUAGE fires

Use UL when **any** are true:

- Starting a new project / new domain area (greenfield glossary)
- Mid-PRD when terminology is ambiguous (e.g., "wait, do we mean Customer or Account?")
- During code review when the same concept appears under different names
- During a post-mortem to disambiguate the incident narrative
- **Inside NSH** if the project's `UBIQUITOUS_LANGUAGE.md` is stale (>30 days since last refresh AND new domain terms surfaced this session) — see "NSH integration" below
- When migrating code (the rename PR is a great moment to canonicalize)

**Skip UL when:**

- Session is purely technical (refactor, infra, tooling) with no new domain terms
- Glossary already exists and was refreshed this session
- One-off bug fix that touches no domain concepts
- The project is ≤1 person ≤1 week — overhead exceeds value

## The 5 steps

### Step 1 — Scan the corpus

Identify the source(s) to extract from:

| Source | When |
|---|---|
| **Current conversation** | Default — extract from the last N messages (user + Claude) |
| **PRD** | If running inside PRD protocol — extract from the PRD draft |
| **Codebase** | If running standalone for greenfield glossary — Viking + Graphiti search for domain terms |
| **Existing glossary + new diff** | Re-running — read existing UBIQUITOUS_LANGUAGE.md, find new terms surfaced since last run |

Look for **domain-relevant nouns and verbs**. Skip generic programming concepts (array, function, endpoint, route) unless they have project-specific meaning.

### Step 2 — Identify problems

Three failure shapes to flag:

1. **Ambiguity** — same word used for different concepts. Example: "User" meaning auth identity AND billing identity AND profile owner.
2. **Synonyms** — different words used for the same concept. Example: "Order" vs "Purchase" vs "Transaction" all referring to the same lifecycle event.
3. **Vague / overloaded terms** — words so generic they carry no information. Example: "data," "manager," "service," "handler" without a domain qualifier.

Each problem becomes a Flagged Ambiguity in the output, with an opinionated recommendation.

### Step 3 — Propose canonical terms

**Be opinionated.** When multiple words exist for the same concept:

- Pick the **best one** (clearest, most specific, most aligned with domain experts' usage)
- List the others as "aliases to avoid"
- Don't hedge — the whole point of UL is to remove ambiguity, not catalog it

When a single word maps to multiple concepts:

- Split into 2+ canonical terms
- Each term gets its own definition
- Cross-reference: "Customer (the billing entity) — distinct from User (the auth identity)"

### Step 4 — Write the glossary

Create or update `UBIQUITOUS_LANGUAGE.md` in the project root using the format below. Group terms into multiple tables when natural clusters emerge (e.g., by subdomain, lifecycle, or actor). Each group gets its own heading + table.

If all terms belong to a single cohesive domain → one table is fine. Don't force groupings.

### Step 5 — Pin the commitment

After writing the file, state explicitly:

> "I've written/updated UBIQUITOUS_LANGUAGE.md. From this point forward I will use these terms consistently. If I drift from this language or you notice a term that should be added, let me know."

This is load-bearing. The output isn't just the file — it's the **commitment to use the canonical vocabulary in all future text** (commits, code, PRDs, handoffs, NeuralTree lessons, Graphiti episodes).

## Output Format

```markdown
# Ubiquitous Language

## <Subdomain or cluster name>

| Term | Definition | Aliases to avoid |
|------|-----------|------------------|
| **Order** | A customer's request to purchase one or more items | Purchase, Transaction |
| **Invoice** | A request for payment sent to a customer after delivery | Bill, Payment Request |
| **Fulfillment** | The act of preparing and dispatching ordered items | Shipment (use only for the dispatch event) |

## People

| Term | Definition | Aliases to avoid |
|------|-----------|------------------|
| **Customer** | A person or organization that places orders | Client, Buyer, Account |
| **User** | An authentication identity in the system | Login, Profile (for auth context only) |

## Relationships

- An **Invoice** belongs to exactly one **Customer**
- An **Order** produces one or more **Invoices**
- A **Fulfillment** generates one **Shipment**; multiple Fulfillments per Order are possible
- A **User** may or may not represent a **Customer** (admin Users have no Customer record)

## Example dialogue

> **Dev:** "When a **Customer** places an **Order**, do we create the **Invoice** immediately?"
> **Domain expert:** "No — an **Invoice** is generated only once a **Fulfillment** is confirmed. A single **Order** can produce multiple **Invoices** if items ship in separate **Shipments**."
> **Dev:** "So if a **Shipment** is cancelled before dispatch, no **Invoice** exists for it?"
> **Domain expert:** "Exactly. The **Invoice** lifecycle is tied to the **Fulfillment**, not the **Order**."

## Flagged ambiguities

- **"account"** was used to mean both **Customer** and **User** in 4 places. These are distinct: a **Customer** places orders; a **User** is an authentication identity that may or may not represent a **Customer**. Recommendation: deprecate "account" entirely; use the precise term per context.
- **"order"** appears as both noun (the entity) and verb (the act of placing). Keep both, but capitalize the noun (`Order`) in code/docs to disambiguate.
```

## Rules

- **Be opinionated.** Pick the best term; list the rest as aliases.
- **Flag conflicts explicitly.** Ambiguous terms go in the "Flagged ambiguities" section with a clear recommendation.
- **Tight definitions.** One sentence max. Define what a thing IS, not what it does.
- **Show relationships + cardinality.** "An X belongs to exactly one Y" / "A Z produces zero-or-more W's."
- **Domain terms only.** Skip generic programming concepts unless they have domain-specific meaning here.
- **Group naturally.** Multiple tables by subdomain when clusters emerge; one table when the domain is cohesive. Don't force groupings.
- **Write a dialogue.** A 3-5 exchange dev/domain-expert conversation that shows the terms being used precisely. The dialogue clarifies boundaries between related concepts.

## Re-running (incremental updates)

When invoked again in the same conversation OR in a later session:

1. Read the existing `UBIQUITOUS_LANGUAGE.md`
2. Incorporate any new terms from subsequent discussion
3. Update definitions if understanding has evolved
4. Mark changed entries with `(updated)` and new entries with `(new)` for one cycle so the diff is visible
5. Re-flag any new ambiguities surfaced since last run
6. Rewrite the example dialogue to incorporate new terms
7. Save + restate the commitment

## NSH integration (the auto-refresh hook)

UL hooks into NATURAL-STOP-HANDOFF to keep the glossary fresh without operator nagging.

**During NSH Step 3 (GNGM post-fix sweep)**, check:

```python
# Pseudocode for the NSH-side check
glossary = read_if_exists("UBIQUITOUS_LANGUAGE.md")

if not glossary:
    # First time — only fire UL if this session introduced ≥3 new domain terms
    if new_domain_terms_count >= 3:
        suggest_ul_run()
elif glossary_age_days > 30 and new_domain_terms_this_session:
    suggest_ul_run()
elif terms_used_this_session_not_in_glossary >= 2:
    suggest_ul_run()
else:
    skip_ul()  # glossary is fresh and aligned
```

If the check fires, NSH proposes:

> "Glossary refresh recommended — N new terms surfaced this session that aren't in UBIQUITOUS_LANGUAGE.md. Run UL now (~3 min) to keep the glossary current?"

The operator can accept or defer. If accepted, UL runs as Step 3.5 inside NSH. If deferred, NSH continues; the next NSH will re-check.

**Skip the auto-suggest entirely** if the operator already ran UL in this session.

## Anti-patterns

| Anti-pattern | Why bad |
|---|---|
| Hedging with "X or Y" as canonical | Defeats the purpose; pick one and list the other as alias |
| Including generic programming terms (`function`, `module`) | Bloats the glossary; obscures domain signal |
| Multi-sentence definitions | Definition becomes a tutorial; people stop reading |
| Skipping the example dialogue | Glossary entries feel academic; dialogue grounds them in usage |
| Skipping the commitment statement | Future-Claude doesn't know to use the canonical terms; drift continues |
| Re-running without marking `(new)` / `(updated)` | Diff invisible; collaborators don't notice the changes |
| Only flagging ambiguities (no recommendations) | Surfaces problems without resolving them; UL is supposed to BE the resolution |
| Forcing arbitrary groupings | Tables become noise; one table is fine if the domain is small |
| Running UL on a session with zero domain terms | Pure overhead; skip and run later when warranted |

## Relationship to other protocols

| Protocol | Relationship |
|---|---|
| **PRD** | UL runs before / during PRD interview if domain is ambiguous; PRD reuses canonical glossary |
| **PRD-TO-ISSUES** | Issue titles + acceptance criteria use canonical terms |
| **SDP** | Plan, TDD certificate, code review all use canonical terms; reviewers check for alias-to-avoid usage |
| **NSH** | Auto-suggested as Step 3.5 if glossary is stale (see "NSH integration" above) |
| **NLF** | UL claims about current usage are GNGM-verified, not memory-asserted |
| **GNGM** | UL is itself a knowledge artifact; Graphiti episodes after UL runs reference the canonical terms |
| **NeuralTree** | Lessons should use canonical terms so symptom-matching is consistent |

## Calibration

A first-time UL run on a non-trivial project produces **15-50 terms** across 3-8 tables. Less than 15 = the project's domain is too small for UL (skip). More than 50 = the glossary is becoming a wiki; consider splitting per-subdomain.

Subsequent re-runs add **1-5 new terms** per cycle. If a re-run adds 10+ new terms, you missed terms in the prior run OR a major domain shift happened (note it in the changelog of the file).

UL run takes **3-10 minutes** of operator-visible work. Quick refreshes (re-runs) closer to 3; first-time greenfield closer to 10.

## Related

- [PRD.md](PRD.md) — Upstream consumer; PRD interviews use canonical vocabulary
- [PRD-TO-ISSUES.md](PRD-TO-ISSUES.md) — Issue titles + acceptance criteria use canonical terms
- [SDP.md](SDP.md) — Plan + review steps reference canonical glossary
- [NATURAL-STOP-HANDOFF.md](NATURAL-STOP-HANDOFF.md) — Auto-suggests UL refresh during session close
- [NLF.md](NLF.md) — Truth discipline applies to glossary claims about current usage
- [IMPROVE-ARCHITECTURE.md](IMPROVE-ARCHITECTURE.md) — Module names should follow canonical vocabulary

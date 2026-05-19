# KCP — Knowledge Continuity Protocol

> **Pronounced** "K-C-P". Three letters, one law: knowledge must survive the
> session that created it.

## The law

**Comprehension is not complete until it is transmitted.**

Every session that meaningfully deepens understanding MUST update the persistent
knowledge layers before it ends. Understanding that lives only in the current
context window is a leak — when the session closes, it is gone, and the next
session starts blind on everything this one learned.

You did the investigation. You traced the call chain. You understood WHY the bug
existed, WHICH design was chosen and which was rejected, WHAT the non-obvious
constraint is. If that understanding is not written down — into memory, docs,
the graph, the lessons — then you did the hard part and threw the result away.

**KCP is the reflex that prevents that.** It is the dual of NLF: NLF says never
ship a lie; KCP says never end with un-transmitted truth.

## Why this is a protocol, not a nicety

The mechanics already exist — GNGM post-fix mode, the `knowledge-system.md` §4
POST-FIX / §4bis EXPLORE pipelines, NSH's session-close sweep. They are all
**triggered**: they fire when the user types "GNGM", or when a natural-stop is
detected and offered.

The gap KCP closes: **transmission must be a SELF-INVOKED REFLEX, not an opt-in
the user has to remember to ask for.** If the user has to say "make the docs
follow", the protocol has already failed. Like NLF self-invokes when you drift
toward a bandage, KCP self-invokes the moment you have comprehended something
non-obvious.

## When KCP fires (self-invocation triggers)

KCP fires — without being asked — at the end of any unit of work where you:

- **Fixed a non-trivial bug** — the root cause and the fix are knowledge.
- **Shipped a feature** — the design, the why, the file map are knowledge.
- **Made an architecture / design decision** — especially one with a rejected
  alternative ("I did NOT do X because Y").
- **Explored or researched and reached a conclusion** — even "we should NOT do
  this" is knowledge that stops the next session re-exploring the dead end.
- **Discovered a non-obvious fact** about the codebase, tooling, infra, or
  environment — a gotcha, a parity gap, a stale file, a config quirk.

The test: **"If I `/clear` right now, would the next session have to re-derive
what I just understood?"** If yes → KCP fires. Transmit before you end.

It also fires on the explicit trigger word **`KCP`** (any casing).

## The transmission channels

Comprehension routes to the layer that fits it. Pick the right one(s) — you do
not have to hit all of them every time.

| Channel | Carries | Use when |
|---|---|---|
| **Memory** (`memory/`, `MEMORY.md`) | Durable cross-session facts + behavioral rules | A fact/rule the next session must know on load — the FIRST thing it reads. |
| **Docs** (project docs, handoffs) | The canonical project record | A feature/change users or maintainers need documented. NewScript handoffs → `<project>/docs/HANDOFFS/`. |
| **GRAPH — Graphiti** | Causal chains, decisions, "why / when / who" | Connections grep can't find; the rationale behind a choice. `add_episode` with a `Connects:` chain. |
| **WIKI-LLM — NeuralTree** | Atomic lessons (symptom → root cause → fix), distilled wikis | A bug pattern a future session could `lesson_match`. |
| **WIKI-DOCS — Viking** | Semantic index over docs | After writing/changing docs — re-index so they stay retrievable. |
| **AST — Graphify** | The deterministic code-graph | After code changes — `graphify update` so "what calls X" stays true. |
| **NLF** | (not a store — the discipline) | Transmit TRUTH. A lie written into memory poisons every future session that trusts it. KCP without NLF spreads rot. |

The detailed mechanics of each — exact commands, signatures, keep_alive
discipline — live in `knowledge-system.md` (§4 POST-FIX, §4bis EXPLORE, §5
SHIP-PHASE) and `gngm_protocol.md` (post-fix mode). **KCP is the WHY and WHEN;
those are the HOW.** KCP does not re-document them — it makes invoking them
non-optional.

## The KCP close-out (run before you consider work done)

1. **Name what you understood.** State, to yourself, the non-obvious thing(s)
   this session surfaced.
2. **For each — is it obvious from the code + git history alone?** If yes →
   nothing to transmit (don't bloat). If no → continue.
3. **Route it.** Memory for a durable fact/rule; a handoff/doc for a
   feature/change; Graphiti for a causal chain or decision; a NeuralTree lesson
   for a fix pattern; `graphify update` for code changes; Viking re-index for
   new docs.
4. **Transmit.** Actually write it. A plan to "document later" is a leak.
5. **Verify it landed.** Memory file readable; Graphiti episode retrievable via
   search; lesson returns `added: true`.
6. **Only now is the work done.** A unit of work that comprehended something and
   did not transmit it is INCOMPLETE — regardless of whether the code shipped.

## What NOT to transmit (anti-bloat — KCP is not hoarding)

KCP demands transmission of *comprehension*, not stenography. Do **not**:

- Re-state what the code already says plainly, or what git history records.
- Write a memory entry / episode / lesson for a trivial rename, typo, or
  one-line config change.
- Duplicate the same fact into all of memory + graph + lessons. Pick the layer
  it best belongs to; link from the others if needed.
- Pad a handoff with narration. Transmit the *non-obvious* — the why, the
  rejected alternative, the gotcha, the constraint.

The test for transmit-worthiness is the fire test inverted: would a competent
fresh reader of the code get this for free? If yes, skip it. If no, it is
exactly what KCP exists to capture.

## Relationship to the other protocols

- **GNGM** — the 4-tool knowledge pass. KCP is *why* GNGM post-fix mode is
  mandatory, not optional. "GNGM post-fix" is one way to satisfy KCP.
- **NSH** (Natural-Stop Handoff) — the session-close ceremony. NSH's Step 3 is a
  GNGM post-fix sweep; KCP is the standing duty that makes that step
  non-skippable. KCP fires per *unit of work*; NSH fires per *session*.
- **NLF** — the truth discipline. KCP transmits; NLF guarantees that what is
  transmitted is true. Run them together.
- **knowledge-system.md** — the 6-layer mechanics. KCP is the enforcement layer
  on top of it.

## Anti-patterns

| Anti-pattern | Why it fails |
|---|---|
| "I'll document it if the user asks" | The user having to ask = KCP already failed. It is a reflex. |
| "It's in my head, I'll remember next session" | There is no next-session memory except the persistent layers. The context window does not survive `/clear`. |
| "The commit message covers it" | A commit records *what changed* — not *why*, not *what was rejected*, not *the gotcha discovered along the way*. |
| Transmitting only on `GNGM` / `NSH` triggers | Those are explicit triggers; KCP is the self-invoked reflex that does not wait for them. |
| Writing the fact into every layer identically | Bloat. One home, links from the rest. |
| Transmitting a guess as a fact | NLF violation — poisons every future session. Transmit only verified comprehension. |

## Trigger

Self-invoked at the end of every non-trivial unit of work (see "When KCP
fires"). Also fires on the literal word **`KCP`** (any casing).

Minimum action on trigger: run the 6-step close-out.

## Related

- `NLF.md` — No Lie Fix (transmit truth, not lies — KCP's twin)
- `NATURAL-STOP-HANDOFF.md` — session-close ceremony (KCP per session)
- `~/.claude/rules/knowledge-system.md` — the 6-layer transmission mechanics
- `memory/rules/gngm_protocol.md` — the 4-tool knowledge pass
- `~/.claude/rules/graphiti-protocol.md`, `neuraltree-protocol.md` — channel references

## Changelog

- 2026-05-19 — **v1.** Codified after a QuickTranslate feature session where deep
  comprehension (KR-vs-ENG transfer parity, the failure-report architecture, a
  stale-duplicate trigger-file gotcha) would have evaporated on `/clear` had the
  user not explicitly asked for the documentation to follow. The mechanics
  (GNGM post-fix, knowledge-system §4, NSH) already existed but were
  trigger-gated; KCP makes transmission a self-invoked reflex.

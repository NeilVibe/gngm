---
name: GNGM Doc 09 — /goal Autonomous Mode
description: Claude Code's /goal command as the GNGM autoloop — a bounded, measured loop that keeps Claude working until the job is done (including unattended / overnight), with the GNGM gates (NLF + TDD + wave + knowledge feed) encoded into the completion condition so discipline is never skipped. Stack-agnostic; bakable into any repo.
type: gngm-doc
last_verified: 2026-05-21
---

# 09 — `/goal` Autonomous Mode

> **The GNGM autoloop.** Use Claude Code's `/goal` command to keep Claude
> working — turn after turn, autonomously, including while you sleep — until
> the job is *genuinely* done. The discipline is not lost in the loop: the
> GNGM gates (NLF, TDD, the wave protocol, the knowledge feed) are encoded
> into the goal's **completion condition**, and the loop is **bounded** so it
> finishes a defined job rather than running forever.
>
> Verified against the official docs (https://code.claude.com/docs/en/goal.md)
> on 2026-05-21. Requires Claude Code **v2.1.139+**.

## What `/goal` is

`/goal <condition>` sets a completion condition. After **every turn**, a small
fast model (default Haiku) checks whether the condition holds against *what
Claude has surfaced in the conversation*. Not met → Claude starts another turn
automatically, no re-prompt. Met → the goal clears and an "achieved" entry is
recorded in the transcript.

It is a session-scoped wrapper around a prompt-based Stop hook. One goal can be
active per session.

| Command | Effect |
|---|---|
| `/goal <condition>` | Set the goal; a turn starts immediately — the condition IS the directive |
| `/goal` | Status — condition, turns evaluated, duration, token spend, evaluator's last reason |
| `/goal clear` | Clear an active goal early (aliases: `stop` `off` `reset` `none` `cancel`) |

`◎ /goal active` shows in the UI while it runs. An active goal survives
`--resume` / `--continue` (the turn count, timer, and token baseline reset).
Non-interactive: `claude -p "/goal <condition>"` runs the loop to completion in
one invocation (Ctrl+C to interrupt).

`/goal` vs the alternatives: `/loop` re-runs on a **time interval**; a Stop hook
re-runs after every turn with **your script** deciding; `/goal` re-runs after
every turn until **a model verifies the condition**. For "keep working until
the job is genuinely done," `/goal` is the right muscle — and the GNGM autoloop.

## The use case: finish the job unattended

The point of `/goal` is to remove babysitting. You define a job, set the goal,
and step away — to another task, or to sleep — and Claude keeps turning until
the condition is met. A multi-feature backlog, a migration, draining an issue
queue: set the done-condition once, and the loop carries it to completion.

Two things make that safe rather than reckless, and they are the rest of this
doc: the **completion condition** carries the discipline, and the **bound**
keeps the loop finite. Neither is optional.

## Why it keeps discipline — the load-bearing idea

`/goal` does not, by itself, make Claude disciplined. **The completion
condition is the discipline contract.** The evaluator only judges what Claude
has *surfaced in the transcript* — it does not run commands or read files on
its own, and it does not police *how* the work was done.

- If the condition says *"the feature works"* → Claude can satisfy it with a
  bandage. The gate is blind.
- If the condition says *"the test command exits 0 with the output shown in the
  transcript, the type-checker reports 0 errors, the wave is CLOSED with a
  SUMMARY commit, and no test file was weakened"* → the only way to satisfy
  the goal is to **do the disciplined work and show the proof.**

> **Loaded ≠ enforced.** The protocols (GNGM, NLF, TDD, the wave protocol) load
> from `CLAUDE.md` + `.claude/rules/` (or `AGENTS.md` / `GEMINI.md`) **every
> turn**, and `/goal` does not strip them — so a `/goal` loop has the protocols
> *in context* the whole way, with no wiring needed. But "in context" is not
> "enforced": the evaluator checks the *condition*, not the methodology. A loop
> under pressure to satisfy a loose condition can still cut a corner. The
> protocols being visible reduces drift; the **condition** is what makes the
> discipline non-optional. Encode the gates INTO the condition.

## Writing a GNGM-disciplined condition

The official docs say a durable condition has three parts: **one measurable end
state**, **a stated check**, **constraints that must not change**. Layer the
GNGM gates on top:

- **NLF gate** — demand the *proof artifact*, not the claim:
  `"...with the passing test output shown in the transcript"`, never just
  `"...with tests passing"`.
- **TDD gate** — `"each change landed RED→GREEN: a failing test was shown
  before the fix"`.
- **Wave gate** — `"each unit CLOSED per the wave protocol — SUMMARY written,
  lesson recorded, atomic commits pushed"`.
- **Knowledge gate** — `"the knowledge feed ran: graphify update + a Graphiti
  episode + the active index updated"` (see [02-PROTOCOL.md](02-PROTOCOL.md)
  and the [NSH protocol](../protocols/NATURAL-STOP-HANDOFF.md)).
- **Verification gate** — for visual work: `"a vision review was run on every
  visual change and its verdict pasted into the transcript"`.
- **Constraints** — `"no test weakened, no skip/xfail added, no
  catch-and-ignore bandage, no --no-verify"`.
- **The bound** — `"or stop after N turns and write an NSH handoff if not
  done"`. Mandatory. See the next section.

### Example — the multi-unit pattern

```
/goal Features A, B, and C are all shipped. Done means, for EACH feature: a
failing test was shown before the fix (TDD); the project's test command runs
green with the output in the transcript; the type-checker / build is clean; the
unit is CLOSED per the wave protocol — a SUMMARY committed and pushed; and the
knowledge feed ran (graphify update + a Graphiti episode). Constraints: no test
weakened, no catch-and-ignore, no --no-verify, no schema change without a
migration. Or stop after 60 turns and write an NSH handoff if not done.
```

That single condition is the whole engineering contract. `/goal` then just
supplies the muscle to keep turning until every clause is true.

## Bounding the loop — measure it, never run to infinity

`/goal` keeps turning until the condition is met. That is the power — and the
risk. An unbounded or unsatisfiable goal loops indefinitely, burning tokens,
time, and energy with nothing to show. **Every `/goal` MUST be bounded and
measured before you launch it.** Three guards, all mandatory:

1. **A turn cap, always.** End every condition with `"or stop after N turns and
   write an NSH handoff if not done."` N is not decoration — it is the hard
   ceiling. Size it deliberately: estimate turns-per-unit × number of units,
   add ~30% slack. A 3-feature job at ~15 turns each → N ≈ 60, not 500.
2. **A reachable condition.** Every clause must be something Claude can
   actually make true and *show* in the transcript. A clause that depends on an
   unavailable service, a human decision, or an external event is
   unsatisfiable — the loop will spin to the turn cap achieving nothing. If a
   clause is not Claude-completable, it does not belong in the condition.
3. **Measured, not hopeful.** Before launching, do the arithmetic:
   turns × per-turn cost ≈ the spend. Decide that number is acceptable
   *before* you step away. If you can, check `/goal` mid-run — it reports turns
   evaluated and token spend, so a runaway is visible early.

The healthy mental model: `/goal` is "finish this **bounded, well-defined**
job while I'm away" — never "work forever." A loop that hits its turn cap and
writes an honest NSH handoff is a **success** of the bounding discipline. An
unbounded loop grinding all night on an unsatisfiable clause is wasted
energy — and the exact failure this section exists to prevent.

## Where `/goal` fits — and where it does NOT

`/goal` is an **executor**, not a replacement for the protocols:

- **Good fit** — running an already-planned unit of work (a wave's EXECUTE +
  VERIFY stages) to a measurable, NLF-hardened, knowledge-feed-inclusive
  done-condition, without per-step babysitting.
- **Not for the gates** — brainstorming, plan review, and final code review are
  human / review checkpoints. Point `/goal` at the grind *between* gates, not
  at the gates themselves.
- **Not a "never stop" mode** — the turn cap, genuine ambiguity, and
  irreversible actions still hand control back. `/goal` removes babysitting of
  *obvious* steps; it does not remove judgment.

## Caveats

- **The evaluator sees only the transcript.** If proof is not surfaced — test
  output, commit SHAs, verdicts — the gate cannot see it, and a vague condition
  passes too easily. Be concrete; make Claude show its work.
- **Context limits** — a very long goal still hits context compaction; for
  large work, have the condition require an NSH-style checkpoint partway.
- **Requirements** — the workspace trust dialog must be accepted; `/goal` is
  unavailable when `disableAllHooks` or `allowManagedHooksOnly` is set.
- The condition can be up to 4,000 characters — long enough to spell out every
  gate. Use the room.

## Related
- [02-PROTOCOL.md](02-PROTOCOL.md) — the GNGM 4-tool mechanics the condition's knowledge gate refers to
- [06-WAVE-PROTOCOL.md](06-WAVE-PROTOCOL.md) — the wave the condition should require CLOSED
- [../protocols/NLF.md](../protocols/NLF.md) — the truth discipline the condition must demand proof of
- [../protocols/TDD.md](../protocols/TDD.md) — RED→GREEN, the per-change gate
- [../protocols/NATURAL-STOP-HANDOFF.md](../protocols/NATURAL-STOP-HANDOFF.md) — what the turn-cap fallback should trigger

## Docs
- Official `/goal` documentation: https://code.claude.com/docs/en/goal.md (verified 2026-05-21)
- Requires Claude Code v2.1.139+
- `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` — project governance + trigger phrases

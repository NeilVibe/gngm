---
name: Natural Stop Handoff (NSH) Protocol
description: When work reaches a clean, natural stopping point — wave done, commit batch shipped, tests green, tree clean, clarity high — Claude proactively commits, pushes to origin/main, writes an extremely detailed handoff, and signals /clear-ready. Designed so the next session lands soft after a context wipe.
type: gngm-protocol
version: 1
last_verified: 2026-04-25
trigger: NSH (explicit) OR Claude-initiated when criteria met
---

# Natural Stop Handoff (NSH) Protocol

> **Purpose.** When the cognitive arc finishes — a wave commit lands clean, tests green, tree clean, no half-thoughts mid-flight — Claude wraps the session for the operator without being asked. Future-Claude (after `/clear`) lands on a runway built deliberately for cold-start, not a stack of tabs.

## Core idea

Most session-end pain comes from one of three failures:

1. **Discovery rot** — a real insight from this session lives only in the operator's working memory; after `/clear` it's gone.
2. **State drift** — `SESSION_CONTEXT.md` / `active/_INDEX.md` lag behind reality; cold-Claude reads stale claims.
3. **Off-machine gap** — local commit not pushed, so `gh repo view` doesn't reflect truth.

NSH closes all three at every natural stop, not only at the very end of a session.

## When NSH fires

NSH fires when **all four** are true:

1. **Logical-unit complete.** A wave commit / atomic batch / migration-to-green just landed; you're not mid-thought.
2. **Tree clean.** `git status -s` empty (or about to be empty after the handoff commit itself).
3. **Tests green.** Whatever test surface was touched this session is green (unit + integration + live E2E if applicable).
4. **Clarity high.** You can articulate "what shipped, what's next" in one breath.

Do **not** fire NSH when:
- You're mid-debugging and a hypothesis is still live in your head.
- Tests are red.
- Working tree has uncommitted exploratory edits.
- The unit is "done" but you suspect a regression you haven't checked.

If criteria fire ambiguous, **ask the operator** "natural stop here?" rather than auto-executing.

## Trigger phrases

| Operator says | NSH does |
|---|---|
| `NSH` | full sequence, push to origin, write handoff, commit, push, signal ready |
| `NSH dry` | execute steps 1-4 only (verify + GNGM); skip commit/push/signal |
| `NSH no push` | execute through commit, but skip the push (operator pushes manually) |
| `NSH minimal` | only update `SESSION_CONTEXT.md` + push existing commit; skip lessons / episodes |

If the operator says nothing but criteria fire AND the conversation has been long enough that `/clear` is plausible, Claude **may proactively offer** "natural stop — should I run NSH?" rather than auto-execute.

## The 7-step sequence

### Step 1 — Verify clean state (≤30s)

```bash
git status -s        # must be empty OR contain only files about to be committed
git log --oneline -3 # confirm what just landed
```

If anything stranger than expected files appears, **stop** and surface to the operator. Don't sweep stray files into the handoff commit.

### Step 2 — Verify tests green (depends on what changed)

| Touched | Run |
|---|---|
| `app/src/**` | `cd app && pnpm test` (vitest) |
| `app/scripts/wave*-verify.mjs` | `cd app && node scripts/wave*-verify.mjs` |
| `server/app/**` or `server/tests/**` | `cd server && uv run pytest <touched test files> -q` |
| `server/alembic/versions/**` | `cd server && uv run alembic current` (head matches) |
| Mixed | both |

If any test red, **stop**. NSH is for clean stops only.

### Step 3 — GNGM post-fix sweep

Execute when this session shipped real product work (not pure docs):

a. **Graphiti episode** — capture WHY + causal chain for what just landed.
   ```python
   await g.add_episode(
       name='wave-N-cM-<short-verb>-<YYYY-MM-DD>',
       episode_body="""
       Commit <sha> shipped <what>. Files touched: A, B.
       Connects: <Component1> → <Component2> → <Component3>.
       Why: <motivation in one sentence>.
       """,
       source_description='Wave N c<M> close',
       reference_time=datetime.now(timezone.utc),
       group_id='winacard',
   )
   ```

b. **NeuralTree lesson_add** — for any NOVEL pattern surfaced this session.
   Skip if it duplicates an existing lesson (use `lesson_match` first).

c. **Update `memory/active/_INDEX.md`** — current wave, what shipped, blockers, next action. Drop stale carry-over.

### Step 3.5 — Glossary refresh check (UBIQUITOUS-LANGUAGE hook)

Check whether the project's `UBIQUITOUS_LANGUAGE.md` needs a refresh. The check fires UL only when warranted — most NSH sweeps skip this entirely.

```python
# Pseudocode for the check
glossary = read_if_exists("UBIQUITOUS_LANGUAGE.md")
new_domain_terms_this_session = scan_session_for_domain_terms_not_in_glossary()

if not glossary:
    # First-time — only suggest UL if this session introduced ≥3 new domain terms
    if len(new_domain_terms_this_session) >= 3:
        suggest_ul_run(reason="no glossary exists yet; N new domain terms surfaced")
elif glossary_age_days > 30 and new_domain_terms_this_session:
    suggest_ul_run(reason="glossary >30 days old; N new domain terms surfaced")
elif len(new_domain_terms_this_session) >= 2:
    suggest_ul_run(reason="N new domain terms not in glossary")
else:
    skip_ul()  # glossary is fresh and aligned, OR session was non-domain
```

If the check fires, NSH proposes (does not auto-execute):

> "Glossary refresh recommended — N new terms surfaced this session that aren't in `UBIQUITOUS_LANGUAGE.md`. Run UBIQUITOUS-LANGUAGE protocol now (~3 min) to keep the glossary current?"

| Operator response | NSH does |
|---|---|
| `yes` / `run UL` | Execute UBIQUITOUS-LANGUAGE protocol inline as Step 3.5; include the updated glossary in the Step 7 commit |
| `no` / `defer` | Continue NSH; the next NSH will re-check (no nagging mid-session) |
| `skip` | Continue NSH; suppress the check for the rest of this session |

**Skip the auto-suggest entirely** if:
- The operator already ran UBIQUITOUS-LANGUAGE in this session
- This session was purely technical (refactor, infra, tooling) with no domain terms
- `NSH minimal` was the trigger (minimal mode skips Step 3.5)

See [UBIQUITOUS-LANGUAGE.md](UBIQUITOUS-LANGUAGE.md) for the full protocol.

### Step 4 — Push the existing work commit

If a product commit (e.g. c17) exists locally but isn't on `origin/main`:

```bash
git push origin main 2>&1 | tail -5
```

Confirm `... main -> main` line. Track-branch reports.

### Step 5 — Write extremely-detailed handoff

`docs/current/SESSION_CONTEXT.md` — overwrite with cold-start-friendly content. Future-Claude has zero conversation context, so spell out:

| Section | Must contain |
|---|---|
| **Frontmatter** | name, description (1-line + commit hash), type, last_verified, last_updated, originSessionId |
| **TL;DR for next session** | What to read first; what `go` means; commit hashes; baseline numbers |
| **What shipped this session** | Per-commit narrative, file-level diff, test deltas, screenshots |
| **Bugs/discoveries** | Anything the live run revealed; meta-lessons |
| **Services at handoff** | Process table: `name`, `port`, `pid`, `status`, log path |
| **DB state** | `alembic current`, key seeded data, budget, baseline counts |
| **Test state** | numbers (`133/133`, `14/14`, etc.) + how to re-run |
| **Wave commit sequence progress** | the 1..N table, marking what's done, what's next |
| **Next concrete action** | scope, pre-reading list with **absolute paths**, expected file deltas |
| **Outstanding follow-ups** | carry-overs from prior handoffs + new ones from this session |
| **Resume-from-cold-start commands** | exact bash to bring services up if they died between sessions |
| **Wave continuity** | the broader wave-N..wave-M roadmap with state |
| **Meta** | session ID, branch, last commit, episodes recorded, lessons added |

**Cold-start test for the doc:** read it as if you've never seen this project. Can you start work in 10 minutes?

### Step 6 — Update `memory/active/_INDEX.md`

Append the latest session as the "Most recent" block. Do NOT delete prior recents — they're audit trail. Trim only if active/_INDEX exceeds 300 lines.

### Step 7 — Atomic handoff commit + push

```bash
git add docs/current/SESSION_CONTEXT.md \
        memory/active/_INDEX.md \
        lessons/<touched>.md \
        docs/GNGM/protocols/<any new>.md \
        ...
git commit -m "$(cat <<'EOF'
docs: NSH handoff <short-summary>

<expanded summary — 5-15 lines>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

Confirm push success. Print commit hash + delta stat to operator.

### Step 8 — Signal /clear-ready

Print clearly:

```
NSH complete. Branch main on origin/main, tree clean.
Handoff at docs/current/SESSION_CONTEXT.md.
Ready for /clear.
```

This is the operator's cue.

## What NSH does NOT do

- Does not write a wave SUMMARY.md (that's the wave-close commit, separate from session-close).
- Does not extract skills or update `MEMORY.md` trunk (that's `self-improving-agent` skill).
- Does not run E2E if E2E was already run in the session — re-running is wasted; NSH trusts what already passed.
- Does not amend the work commit. Handoff is a separate commit. Always.
- Does not push to origin if the operator said `NSH no push`.
- Does not prompt for a new feature, debug, or refactor. NSH is exit, not entry.

## Anti-patterns

| Anti-pattern | Why bad |
|---|---|
| Firing NSH while a hypothesis is still live in working memory | Loses the insight; future-Claude can't recover it |
| Bundling work + handoff in one commit | Mixes domain change with state-snapshot; harder to revert |
| Skimping on the handoff because "I just wrote a similar one last session" | Drift accumulates; cold-Claude reads stale info |
| Skipping push because "I'll do it next session" | Off-machine gap = real backup risk; only takes ~5s |
| Writing handoff as `last_verified: 2026-04-23` when today is 2026-04-25 | Time-stamps drive freshness signals; lying breaks them |
| Calling NSH on red tests | NSH is "things are good" — fix red first, OR write a different protocol-aware handoff that names what's broken |
| Using relative dates ("Friday", "yesterday") | Cold-Claude doesn't know when it's reading; absolute ISO dates only |

## Calibration

NSH should add 5-10 minutes of operator-visible work. If it ever takes more than 15 minutes for a routine close, something's wrong — either too much in step 3 (lesson explosion) or step 5 (handoff bloat). Trim. The handoff is a runway, not a memoir.

## Relationship to other protocols

| Protocol | Relationship |
|---|---|
| **NLF** | NSH inherits NLF — every claim in the handoff is verified with a tool call from THIS session. |
| **SDP** | NSH is what fires AFTER an SDP cycle reaches step 7 (close). |
| **TDD** | NSH includes the test-state numbers TDD produced in step 2. |
| **GNGM** | NSH step 3 IS the GNGM post-fix sweep, scoped to session-close. |
| **UBIQUITOUS-LANGUAGE** | NSH step 3.5 auto-suggests UL refresh if the glossary is stale or new domain terms surfaced this session. |
| **DEBUG** | If a `DEBUG R<n>` runbook fired this session and produced a WC-NNN, NSH carries that case study into the handoff. |
| **STRESS** | If `STRESS <feature>` ran this session, NSH's handoff records the stress-test numbers and falsifiable invariants. |
| **PRD** | If a multi-session PRD interview is mid-flight, NSH preserves interview state in the handoff so the next session resumes cleanly. |
| **PRD-TO-ISSUES** | If decomposition spans sessions, NSH preserves the in-progress slice list. |
| **IMPROVE-ARCHITECTURE** | If an IA audit spans sessions, NSH preserves the candidate list + chosen designs. |
| **wave-protocol** | NSH is the SESSION close, not the WAVE close. A wave often spans multiple NSHs. |

## Why NSH at all

The cost of `/clear` is real: future-Claude reads the project map cold. The cost of writing a 30-line handoff is small. The asymmetry is where the value is.

NSH lets the operator say "ok, that's a good place to stop" without having to dictate the post-flight checklist. Claude knows the checklist; operator just signals the moment.

Compounding effect: every NSH adds one more session-handoff to the corpus, future-Claude reads them as part of `git log` history and learns the project's rhythm without being trained on it.

## Related
- [SDP.md](SDP.md) — Standard Development Protocol (NSH is SDP step 7's session-close form)
- [NLF.md](NLF.md) — No-Lie-Fix (NSH inherits the truth discipline)
- [LOGGING.md](LOGGING.md) — log standards (NSH's handoff includes log-event names if relevant)
- [UBIQUITOUS-LANGUAGE.md](UBIQUITOUS-LANGUAGE.md) — Glossary protocol auto-suggested by NSH Step 3.5
- [PRD.md](PRD.md) — Multi-session PRD interviews preserve state via NSH
- [PRD-TO-ISSUES.md](PRD-TO-ISSUES.md) — Multi-session decomposition preserves state via NSH
- [IMPROVE-ARCHITECTURE.md](IMPROVE-ARCHITECTURE.md) — Multi-session IA audits preserve state via NSH
- `~/.claude/rules/organization-master.md` — `docs/current/` ≤3 files convention NSH respects
- `~/.claude/rules/knowledge-system.md` — 6-tier Pentology that step 3 walks through
- [`../../current/SESSION_CONTEXT.md`](../../current/SESSION_CONTEXT.md) — the artifact NSH writes

## Docs
- `winacard/CLAUDE.md` — `NSH` trigger row
- `winacard/MASTER_PLAN.md` — wave roadmap NSH references for "Wave continuity" section
- `~/.claude/projects/-home-neil1988-winacard/memory/active/_INDEX.md` — NSH step 6 target

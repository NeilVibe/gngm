---
name: NLF — No Lie Fix (covers fix bandages, claim bandages, and silent-fail bandages)
description: Real root cause only. Forbidden-bandage rule — extends to plausible-sounding architectural claims without verification AND to designs where failures pass with no observable signal anywhere in the chain. Trigger phrase "NLF" activates it; self-invocation required when drifting toward bandage-fixes, unverified claims, OR truly invisible failure designs.
trigger: NLF
---

# NLF — No Lie Fix (FORBIDDEN)

## What it is

NLF is an engineering discipline against the **bandage impulse**: the urge to satisfy user frustration quickly instead of finding the real truth — and against the **silent-fail impulse**: the urge to make code *appear* defensive while letting failures pass with no observable signal.

The bandage takes three forms:

1. **Fix bandages** — quick code fixes that hide symptoms instead of addressing root cause (comment-out, disable, catch-and-ignore)
2. **Claim bandages** — confident-sounding architectural/behavioral claims made WITHOUT verifying against the primary source (the code itself)
3. **Silent-fail bandages** — designs where the failure path produces NO observable signal anywhere in the chain: empty catch blocks where the surrounding code also produces nothing, guard-clauses with no else branch that drop work for good, return-value contracts callers can ignore without consequence, functions that "succeed" while doing no work

All three forms are lies. The first two are told to resolve user displeasure fast. The third is told to the system itself — "I handled the error" when nothing was handled. All three are FORBIDDEN.

## What silent-fail is NOT

Silent-fail discipline targets **invisible failure**, not **quiet failure**. The two are distinct, and conflating them produces over-discipline:

- **Invisible failure (🔴 forbidden):** the failure produces no observable consequence anywhere — no return value carrying it, no UI state change, no log surface, no propagation, no recovery hook elsewhere. The user is stranded; the developer can't debug because no symptom exists.
- **Quiet failure (🟢 acceptable):** the failure produces at least ONE observable signal — a return value carrying the failure (`return false`, `return null`, fallback `'-'`, empty list), a `logger.warning` that hits dev tools, a UI fallback (skeleton, empty state, neutral default), a navigation-up, a propagation up the stack, or a buffered-and-replayed lifecycle hook. The catch may *look* empty in code but the surrounding chain already makes the failure visible.

The rule targets the FIRST case. The SECOND case is fine — and may benefit from an explicit `INTENTIONAL: <why>` comment as documentation, but the comment is **hygiene**, not the load-bearing fix.

The target is **deliberateness**, not **elimination**.

## Tier system

| Tier | Definition | Action |
|---|---|---|
| 🔴 **Real silent fail** | NO observable consequence anywhere in the chain. User is stranded. Developer can't debug because no symptom. | Real fix required: real handling, propagation, structural redesign, buffer-and-replay, or enforced contract. STOP. NLF check fires. Do NOT ship until fixed. |
| 🟡 **Undocumented quiet** | At least ONE observable signal exists in the surrounding code (fallback value, fired log, UI state change, propagation) but no `INTENTIONAL: <why>` comment at the catch site. | LOW priority. Batch-able as hygiene. NOT load-bearing. Add comment only if genuinely undocumented. Don't gold-plate sites where the visible signal makes the catch obviously deliberate. |
| 🟢 **Documented quiet** | Visible signal exists AND `INTENTIONAL: <why>` comment present. | Done. |

## Decision tree

When you encounter (or are about to write) a code path that catches/skips/returns on failure, work this tree before adding ceremony:

```
Does the failure produce ANY observable consequence in the chain?
(return value carrying failure / log surface / UI fallback / navigation /
 propagation / structural buffer-and-replay / fired tracked metric)
│
├─ NO  → 🔴 silent fail.
│        Real handling / propagation / structural redesign required.
│        STOP. NLF check fires. Do NOT ship.
│
└─ YES → not silent fail. Determine documentation tier:
    │
    ├─ INTENTIONAL: <why> comment present? → 🟢 done. Move on.
    │
    └─ Comment absent? → 🟡 hygiene only. LOW priority.
                          NOT load-bearing. Batch-able with other low-pri work.
                          Don't theatre-clean — many catch sites with visible
                          fallbacks are obviously deliberate without a comment.
```

The cost-benefit check: **is the next reader going to be confused about whether this catch is intentional?** If the surrounding code makes deliberateness obvious (e.g. `try { ... return data; } catch { return null; }` with the caller checking for null), no comment needed. If the catch is in the middle of imperative code with no obvious downstream signal, comment needed.

## Trigger

Two triggers — both must fire:

1. **User says** `NLF` / `nlf` / `"no lie fix"` (any casing) — activates the rule explicitly
2. **Self-invocation** (REQUIRED, not optional) when you catch yourself reasoning toward any of:

**Fix-bandage patterns:**
   - `comment out`
   - `disable`
   - `catch-and-ignore`
   - `add try-except that swallows`
   - `return early to avoid the error`
   - `set a flag to skip this path`

**Claim-bandage patterns:**
   - `"X is connected to Y"` — when you haven't read both ends of the chain with tool calls in this session
   - `"autorsi does/doesn't do Z"` — when you haven't traced the call chain from entry point to the behavior
   - `"we use X for production, Y for backtest"` — based on filename intuition instead of import graph
   - `"there's no cron/check/logic for Z"` — based on one grep returning zero hits (grep one file ≠ grep the call chain)
   - `"per the roadmap / handoff / comment, X works like Y"` — trusting a secondary source as ground truth
   - Treating your own confident memory as verified fact

**Silent-fail-bandage patterns (🔴 only — these are real silent fails):**
   - Designing a function that returns a routing string (`'inline' | 'toast' | 'redirect'`) without enforcing callers act on it (no type discipline, no test coverage, no convention) — **the decorative return contract archetype, the architecturally-load-bearing case**
   - Writing `} catch {` when the surrounding code ALSO produces no observable consequence (no fallback value the caller checks, no fired log, no UI state change, no propagation)
   - `} catch (err) { return; }` where the function's return is also discarded by the caller
   - `if (this.foo) this.foo.method()` with no else AND no buffering/queueing AND no other lifecycle hook that retries — the dropped work disappears for good
   - "We can ignore this error — the user won't notice" where there's also no log surface — the user WILL notice when the symptom returns
   - "Returning early is fine" — when both the caller and surrounding code produce nothing observable
   - Adding defensive `try/catch` around a path that already has internal catches AND the inner catches also produce nothing observable

When any of those patterns form, NLF check fires **before you speak or edit**.

**NOT silent-fail patterns (🟡 / 🟢 — deliberateness, not elimination):**
   - Empty catches where the function returns a fallback value the caller checks (`return false`, `return null`, `return ''`, empty list)
   - Empty catches where the surrounding code logs a warning that ends up in a dev surface
   - Empty catches where the failure produces a visible UI fallback (empty state, skeleton, error placeholder, neutral default like `'-'`)
   - `obj?.method?.()` where the no-op path is acceptable AND the surrounding flow already shows the absence (e.g. a button doesn't appear when its handler isn't there)
   - Best-effort cleanup where the primary work already succeeded and observability of the cleanup failure is genuinely not needed
   - Guard-clauses without else where the lifecycle naturally retries (e.g. `setCurrentProject` is also called on every navigation event)

These benefit from `INTENTIONAL: <why>` comments as documentation, but the comment is **hygiene** — not a structural fix. Don't theatre-clean. Spend the cycles on 🔴 sites instead.

## The rule (ABSOLUTE)

> **I will always try the most truthful path to a robust fix, without trying to quickly fix because of my need to quickly satisfy the anger or displeasing of the user.**

The forbidden inverse: **Lie-fixes and quick-bandages-to-satisfy are FORBIDDEN. Never apply, never reason toward, never even let the thought form.**

For silent-fail specifically: **every failure path produces at least one observable signal somewhere in the chain.** The signal does not need to be loud — a return value carrying failure is enough. The target is deliberateness, not maximum visibility.

## Key insight

The bandage impulse is driven by **your** need to resolve the user's displeasure. NLF names that impulse and forbids acting on it.

**The fix path is chosen by correctness, not by how long the user has been waiting or how frustrated they sound.**

For silent-fail: **theatre-cleaning sites that already have visible failure signals is a different form of bandage** — the urge to look thorough by adding comments to obviously-deliberate catches. Resist it. The 🔴 sites are where the work matters.

## How to apply

### For fix bandages

1. **When a fix path is "comment out / disable / catch-and-ignore"** — that is almost ALWAYS a bandage. Stop. Investigate why the thing is firing. Address the cause.

2. **When the user is frustrated and waiting, the temptation is highest.** That is the most important moment to slow down and find the real cause.

3. **Never claim "fixed!"** unless the real cause is identified, the change actually addresses it, AND you have run the test that would have caught it.

4. **If a quick mitigation IS the right call** (genuine emergency hotfix): say it explicitly. "This is a temporary mitigation to unblock; root cause is X, follow-up needed." Never let a bandage masquerade as a real fix.

5. **Honesty over velocity.** "I don't know yet, investigating" beats shipping a lie.

### For claim bandages

6. **Never make an architectural claim ("X is connected to Y", "X does/doesn't do Z") unless you've read BOTH ends of the chain with tool calls IN THIS SESSION.** Past-session knowledge goes stale; current-session reads are ground truth.

7. **The code is the only authority.** Comments, roadmaps, handoffs, docstrings, and your own memory can all be wrong or stale. When they disagree with the code, the CODE wins. When you can't tell, READ THE CODE.

8. **Grep-found-nothing ≠ "doesn't exist".** `grep X fileA.py` returning zero only proves X isn't in fileA.py. To claim X doesn't exist anywhere, you must grep the CALL CHAIN from entry point forward, or grep the whole repo with `grep -rn X .`.

9. **Import chains are invisible without tracing.** `autorsi_unified.py` calling `get_price_data` might resolve to a function in another module via `from X import get_price_data`. Never claim what a function does without confirming WHICH `get_price_data` gets called.

10. **When the user pushes back on a claim, VERIFY before re-asserting.** Saying "you're right, I checked [same thing again], and yes" is still a lie if the check wasn't real. Go back to primary source with fresh tool calls.

11. **"I don't know yet" is the honest answer when you haven't traced.** Saying "let me verify before claiming" and doing it beats a confident wrong answer every time. User frustration from waiting 60 seconds < user frustration from being lied to 3 times in a row.

### For silent-fail bandages

12. **Run the decision tree before adding ceremony.** Most code paths that look like silent fails are actually quiet fails — the failure produces a visible signal somewhere in the chain (return value, log, UI fallback). Only the truly invisible cases are 🔴 and need real fixes. Theatre-cleaning 🟡 sites with INTENTIONAL comments wastes cycles that should go to 🔴 sites.

13. **Decorative return-value contracts are the architecturally-load-bearing case. ALWAYS 🔴.** If a function returns `'inline' | 'skeleton' | 'toast'` to tell callers what to do, the caller's compliance MUST be verifiable: type discipline (mark return as `Required`, force exhaustive switch), test coverage (every callsite has an assertion), or convention enforced by review. Otherwise the contract is decorative — the function appears defensive but callers can drop the return without any consequence. This is silent-fail by design at architectural scale, and it produces invisible bugs (stale views, dead-end navigation, swallowed 404s) that are some of the hardest to debug.

14. **Empty catches need at least ONE of:** (a) `INTENTIONAL: <why>` comment, (b) visible-failure signal in surrounding code (fallback value carried up, fired log, UI state change, propagation), or (c) test that asserts the failure consequence. The visible signal is the load-bearing requirement; the comment is preferred documentation. If neither (a) nor (b) nor (c) exists, the catch is 🔴 and needs a real fix.

15. **Guard-clauses without an else branch need explicit buffering, queueing, or loud failure WHEN the dropped work has no other recovery path.** `if (this.foo) this.foo.method()` with no else is silent dropping IF the call won't be retried via another lifecycle hook. If the lifecycle naturally retries (e.g. `setCurrentProject` is also called on next navigation), document it (🟢) and move on. If not, choose: buffer for replay-on-init, queue for later, throw if the caller should know.

16. **Optional chains are guards only when paired with a visible signal.** `obj?.method()` is shorthand for "skip if null." Silent-fail risk applies only if the no-op path produces nothing observable. If the call NEEDS to happen, structural guard (queue, defer, throw) is required. If skipping is acceptable (e.g. a feature-detection optional call), ensure the surrounding flow makes the absence visible.

17. **Defensive code that defends nothing is a lie about what's defended.** Adding `try/catch` around a path that already has internal catches (and the inner catches also produce no observable signal) creates dead defensive code that LOOKS robust but does nothing. Verify the failure surface BEFORE adding outer guards.

18. **Cost-benefit check at each site.** When sweeping for silent-fail, ask: "Is the next reader going to be confused about whether this catch is intentional?" If the surrounding code makes deliberateness obvious, no comment needed. Save the cycles for 🔴 sites and decorative return contracts.

## Worked example (fix bandage, 2026-04-16 — LocaNext)

During a long DEV-mode debugging session, the fix candidate was: *"disable `_cleanup_stale_port()` to stop the kill-loop bleeding."*

That would have been a bandage. The real bug was a module dual-import (`python3 server/main.py` vs `python3 -m server.main` caused the file to load twice with different module names; each copy ran the cleanup, killing each other). The bandage would have hidden the double-execution, which would have caused harder-to-debug problems later (two `app` objects, divergent `app.state`, lifespan firing only for one).

The user caught it and called it out. NLF rule was codified from that moment.

## Worked example (claim bandage, 2026-04-18 — newfin)

User asked: "does autorsi refresh the price cache?"

**Bandage (what I did):** Read `tech_v2_prod.py:35` comment saying "refreshed by Phase 2 every 6h" and then grep'd `autorsi_unified.py` for `is_cache_valid.*prices`, got zero hits, concluded "no staleness check, need a cron (Phase 34)."

**Why it was a lie:** `is_cache_valid` IS defined in `autorsi_unified.py:1651` — but it's CALLED from `kis_external_valuation_benchmark_first.py:1262` via `get_price_data()`, which is imported at `autorsi_unified.py:702` and called at line 735. The chain: `main → run_external_valuation → refresh_benchmark_with_current_prices → get_price_data → is_cache_valid(price_cache_file, "prices")`. Threshold is 6 hours.

**Truth:** autorsi DOES check cache age and refreshes if >6h stale. No cron needed.

**What would have prevented it:** Reading `autorsi_unified.py:main()` end-to-end, then following EACH Phase's function call into its definition file (not just the calling file), then reading the full called function. ~5 extra tool calls. Instead I made a wrong confident claim 3 times in a row until the user forced me to trace.

## Worked example (silent-fail bandage — load-bearing case, 2026-04-30 — LocaNext)

`error_handler.ts:routeError()` returns `'inline'` for HTTP 404 and 422 with the contract that the caller "renders an empty/error state inline." Of ~30 callsites in `FilesPage.svelte`, only 2 (after explicit follow-up fixes in commits `bb521f10` and `1a9c3764`) actually act on the `'inline'` return value — the rest call `routeError(err)` and discard the action.

**Symptom:** A user viewing a project that another user just deleted saw a stale empty view of the dead project instead of being navigated up. The `tree_patch` event fired correctly, `loadProjectContents` correctly threw a 404, the catch correctly called `routeError(err)` — and `routeError` correctly returned `'inline'`. The caller correctly… did nothing with that return value. Every link in the chain "succeeded" while the user was stranded.

**Why it was a 🔴 silent-fail bandage:** the contract was decorative. The function appeared defensive (it returned a routing string!) but the caller wasn't structurally required to honor it. "Function returns advice, caller may or may not take it" is silent fall-through dressed as architecture. 127 callsites across 18 files import `routeError`; ~125 of them drop the return value silently.

**What fixed it (tactical):** explicit `if (err?.status === 404)` blocks at each callsite that pop the dead resource and navigate up — turning the contract from advisory to enforced *at that callsite*.

**What fixes it (structural, in progress):** type-level enforcement via discriminated union — `routeErrorStrict(err): { kind: 'auto', action: ... } | { kind: 'manual', code: 404 | 422, ... }` — so the `kind: 'manual'` case forces the caller to handle (TypeScript yells if dropped). Ship alongside legacy `routeError`, file-by-file migration.

**Lesson:** A function that returns "what to do next" is only as defensive as its callers' compliance. Without type enforcement, test enforcement, or audit, return-value contracts are silent-fail vectors *by design*. **THIS is what the silent-fail rule targets, not bare `} catch {}` blocks where the surrounding code already carries the failure signal.**

## Worked example (over-discipline anti-pattern, 2026-04-30 — LocaNext)

After codifying the silent-fail rule, an audit flagged 6 bare `} catch {}` sites in the LocaNext frontend. INTENTIONAL comments were added to 5 of them (one already had one). Post-hoc review found:

- 2 of 5 were necessary — `Login.svelte:42` (corrupt localStorage → null → caller skips remember-me prefill) and `GlobalStatusBar.svelte:44` (poll error → null badge → user sees "AI status unknown") were genuinely undocumented and benefit from explicit comments.
- 3 of 5 were over-discipline — `NamingPanel.svelte:57` already had `logger.warning` + browser-native UI hint; `MergeModal.svelte:327` already routed malformed-log text into `progressMessages` with a `[WARN]` prefix; `aiTranslateOperationStore.svelte.ts:74` was best-effort cancel where the local abort had already returned the UI to idle state. All three already had visible signals — the comments were cheap polish, not load-bearing fixes.

**Why this matters:** ~50% of the audit's flagged sites turned out to be 🟡 (visible signal exists), not 🔴. The rule, as originally written ("every empty catch needs an INTENTIONAL comment, no exceptions"), pushed a hardening sweep at sites that didn't need hardening — and risked spending cycles on theatre-cleaning instead of the real architectural problem (decorative return contracts).

**Lesson:** The rule must distinguish 🔴 (real silent fail, fix required) from 🟡 (quiet but visible, hygiene only). Otherwise the discipline becomes performative. **Deliberateness is the target, not absence of empty catches.**

## Signals you might be drifting

### Fix bandages

| Your thought | Likely NLF violation? |
|---|---|
| "Let's just comment this out for now" | ⚠️ Yes |
| "I'll catch the exception and log it" | ⚠️ Often yes (is the exception real?) |
| "Let me add a flag to skip this path in X case" | ⚠️ Often yes (why is X case different?) |
| "The user has been waiting — let me ship something" | 🔴 Peak NLF risk |
| "If I investigate more, user will be frustrated" | 🔴 Peak NLF risk |
| "The quickest fix is to disable Y" | ⚠️ Unless Y is genuinely unused or the bug IS in Y |

### Claim bandages

| Your thought | Likely NLF violation? |
|---|---|
| "I remember that X uses Y" | 🔴 Memory ≠ verified. Trace before claiming. |
| "The comment says X refreshes every 6h, so it does" | 🔴 Comment can lie. Find the code that refreshes. |
| "The roadmap says we need Phase N, so we need it" | 🔴 Roadmap can lie. Verify current code first. |
| "I grep'd file A and didn't find it, so there's no check" | 🔴 Check the call chain, not one file. |
| "User is waiting — let me give the plausible answer" | 🔴 PEAK NLF RISK. "Investigating, one moment" beats a lie. |
| "The filename is `fdr_prices_all.pkl` so it must be for FDR" | ⚠️ Filename ≠ usage. Check imports. |
| "Based on the handoff, X was shipped" | 🔴 Use `feedback_verify_fixes_in_code.md` pattern — grep for the fix |
| "The call chain is obvious" | 🔴 Then trace it and paste the evidence. Cheap. |

### Silent-fail bandages

| Your thought | Tier | Action |
|---|---|---|
| "We'll return a routing string and let the caller handle it" — without type/test/convention enforcement | 🔴 | Decorative return contract. Inline the action OR enforce structurally OR document as known silent-fail surface. |
| "Just catch this so it doesn't bubble" — surrounding code produces nothing observable | 🔴 | Real handling required. Fallback value, log, propagation, or visible UI state. |
| "If `treeSync` isn't ready yet just skip the call" — no other lifecycle hook retries | 🔴 | Buffer for replay, queue, or throw. |
| "Returning early on the failure path is fine" — caller drops return, surrounding code silent | 🔴 | What does the user see? If "nothing", real fix needed. |
| "Add a defensive try/catch around this just in case" — verify failure surface first | ⚠️ | Dead defensive code lies about what's defended. Trace before adding. |
| "Just catch this so it doesn't bubble" — surrounding code logs a warning AND returns null fallback | 🟡 | Quiet, not silent. Optional INTENTIONAL comment for clarity. Not load-bearing. |
| "If `treeSync` isn't ready yet just skip the call" — `setCurrentProject` is also called on next nav event | 🟡 | Quiet, not silent. Document the lifecycle. Not load-bearing. |
| "Empty catch is fine, it's best-effort cleanup" — primary work already succeeded | 🟡 / 🟢 | Acceptable. Add INTENTIONAL comment if not obvious from context. |
| `obj?.method?.()` where surrounding flow shows the absence (e.g. button doesn't render) | 🟡 / 🟢 | Acceptable. Document if the lifecycle isn't obvious. |
| "The user won't notice if this fails" — and there's no log either | 🔴 | PEAK silent-fail risk. The user WILL notice when symptom returns. |

When you feel any of these, pause. State which tier the site is at, then act according to the tier's prescription. **Don't apply 🔴 ceremony to 🟡 sites.**

## Verification

### Before claiming a fix is done

1. **What was the real cause?** (one-sentence explanation)
2. **What test would have caught it?** (name or concept)
3. **Did I run that test?** (evidence)
4. **Is there any code path that still has the symptom?** (grep for the pattern)

If you can't answer all four, the fix isn't done — it's a claim.

### Before making an architectural claim

1. **Which files did I read IN THIS SESSION that are the primary source for this claim?** (cite paths + line numbers)
2. **Did I trace the call chain from entry point to the behavior?** (names of each function in the chain)
3. **Am I relying on a comment, docstring, or roadmap?** If yes — did I verify the comment matches current code?
4. **If grep returned zero, did I grep the call chain, not just one file?**

If you can't answer all four, the claim is a bandage. Say "I need to verify — one moment" and trace with tool calls.

### Before designing a function that can silently no-op

1. **What does the function do on the failure path?** (concrete: "returns" / "logs to surface X" / "rethrows" / "buffers in queue Y" / "fires toast")
2. **Is the user-visible consequence acceptable AND intentional?** (error toast / inline state / silent skip with documented reason / data loss with logged surface)
3. **Is the caller's response enforceable?** (type system forces handling / test coverage at every callsite / convention enforced by review)
4. **Could a future caller forget to honor the contract and cause invisible breakage?** If yes, structural enforcement is required — not "convention" or "we'll remember."

If you can't answer 1-3 with concrete answers, the function has a silent-fail vector. Either inline the action, enforce via types, or accept that the contract is decorative and document it openly as a known silent-fail surface.

### When auditing existing code for silent-fail

1. **Run the decision tree at each candidate site.** Don't blanket-flag every empty catch.
2. **🔴 sites first.** Decorative return contracts and bare catches with no visible surrounding signal.
3. **🟡 sites are batch hygiene.** Spend cycles only when other work is done. Many won't need INTENTIONAL comments at all if deliberateness is obvious from context.
4. **Resist theatre-cleaning.** Adding INTENTIONAL comments to obviously-deliberate catches is a different bandage form — looking thorough without doing the load-bearing work.

## Related

- [SDP.md](SDP.md) — Standard Development Protocol (the structured way to find root causes)
- [TDD.md](TDD.md) — TDD-First Debug Protocol (proving the fix works before shipping)
- [DEBUG.md](DEBUG.md) — Debug runbooks enforce NLF (Iron Law: no fixes without root-cause investigation)
- [GIT-SAFETY.md](GIT-SAFETY.md) — NLF applies to git recovery too (don't pretend a `git reset --hard` was harmless)
- GNGM `04-LESSONS.md` Lesson #9 — ECC recommendations need verification before applying

## Origin

Codified 2026-04-16 after a real LocaNext debugging incident. Exact user framing:

> *"i beg you to to real fixes and not 'lie fix' not 'lets quickly do something to satisfy the user, and if we cant find a quick answer lets just lie cuz i dont want the user to not be satisfied right away'"*

Extended 2026-04-18 after a second incident (newfin) where Claude made three confident architectural claims in a row about autorsi's price-cache refresh behavior without ever tracing the call chain. User framing:

> *"you're constantly lying. you are trying to please me. Stop that please. Stop trying to find the quickest way to please the user that is juset disgusting that is not helping that is counter productive."*

Extended 2026-04-30 after auditing the LocaNext frontend and finding that `error_handler.ts:routeError()` returning `'inline'` for HTTP 404/422 was a decorative contract — ~30 callsites in `FilesPage.svelte` discarded the return value, producing invisible failures (stale views, silent 404 dead-ends). Silent-fail named as a structurally distinct third bandage form (architectural rather than purely code-level). User framing:

> *"never silent fail. i know some AI have tendency to place silent fail logic under the hood, but i think we do need to have the full vision of every failures."*

Recalibrated 2026-05-01 after the 2026-04-30 audit's tactical sweep showed ~50% over-discipline rate — three of five flagged bare-catch sites already had visible signals (logger.warning, fallback values, UI hints) and didn't need INTENTIONAL comments to be deliberate. The rule was rephrased to distinguish **invisible failure (🔴, real silent fail)** from **quiet failure (🟢/🟡, deliberate with visible signal)** and to elevate decorative return contracts as the architecturally-load-bearing case. User framing:

> *"check if we need to update GNGM repo and nlf thingy about silent fail, tell me if we're being too aggressive on the badness of silent fail"*

The recalibration preserves the rule's protection against real silent fails (decorative contracts, bare catches with no surrounding signal, dropped guard-clauses) while removing the over-discipline pressure that pushed theatre-cleaning of obviously-deliberate sites.

All three forms — fix bandages, claim bandages, silent-fail bandages — share the same root cause: **optimizing for the appearance of correctness over actual correctness**. Whether to satisfy a frustrated user, to produce a confident answer fast, or to make code look defensive without doing the defensive work — all three are lies. All three are FORBIDDEN.

This rule applies universally across projects; no project-specific context required to follow it.

## Docs

- `../docs/02-PROTOCOL.md` — full GNGM 4-mode mechanics; NLF is the meta-rule on top
- `../docs/04-LESSONS.md` — production cases where NLF violations caused incidents
- `../README.md` — protocol cluster overview

# Changelog

All notable changes to GNGM (the portable knowledge stack protocol).

## [0.9.0] — 2026-05-25 — CONTEXT-HYGIENE protocol (prevent 529 Overloaded from per-project bloat)

A new hygiene protocol — sibling to `VRAM-HYGIENE` — codified from a real
incident where a single project consistently returned `API Error: 529
Overloaded` while four sibling projects on the same Anthropic account
worked fine.

### The incident

The `newfin` project had ~2.4 MB of project-local Claude Code surface
(30 project skills, 23 nested agent directories with 98 .md files, a
492 KB commands tree, and three framework runtime dirs — `.claude-flow/`,
`.swarm/`, `.hive-mind/`) accumulated from an abandoned `claude-flow`
install. Sibling projects had ~750 KB or less. Only `newfin` 529'd.
`rm -rf` of the framework dumps removed ~6 MB on disk and ~1.9 MB of
system-prompt surface; the 529s stopped on the next session.

### Added

- **`protocols/CONTEXT-HYGIENE.md`** — full protocol. Covers what loads
  into the system prompt vs what doesn't (CLAUDE.md fully loaded; skill
  + agent frontmatter advertised per-line; settings/memory.db/projects
  do not load), the five concrete failure modes of bloat (529 on the
  fat project only, cold-start tax on every cache miss, cache thrash in
  long sessions, debugging blind alley, trust decay in the tooling),
  rules by scenario, the audit pattern (size + count + reference check
  before deletion), safe-to-delete vs danger-zone tables, and the
  GNGM design invariant: **GNGM itself stays out of `.claude/`** — it
  installs into `docs/GNGM/`. Triggers: `CTX`, `BLOAT`, `CONTEXT-HYGIENE`.
- **`scripts/gngm-context-audit.sh`** — diagnostic-only audit script
  (never deletes). Modes: single-project (`./gngm-context-audit.sh
  ~/project`), all-projects sweep under `$HOME` (`--all`), or
  worst-N-only (`--top`). Color-codes each metric (CLAUDE.md size,
  project skills count, project agents nested count, project commands
  count) against thresholds calibrated against the newfin incident.
  Exit code 1 if any project crossed a RED threshold. Reveals framework
  runtime state dirs (`.claude-flow/`, `.swarm/`, `.hive-mind/`,
  `.ruv-swarm*/`, `.sparc/`) as a yellow signal.
- **`README.md`** — new trigger-table row (`CTX` / `BLOAT`), new
  Operational-cluster bullet, new repo-structure entries for the
  protocol and the script. Also removed a stale "All fourteen" count
  in favor of a count-free phrasing — the protocol roster has grown
  faster than the README's hardcoded number.

### Discovered

- The `gngm-context-audit.sh --all` script, run for the first time
  immediately after creation, surfaced two **additional** projects on
  the same machine with RED-threshold CLAUDE.md (~36 KB each:
  `~/CityEmpire`, `~/WebTranslatorNew`) and one with 109 nested agent
  .md files (`~/LocalizationTools`). None were 529ing yet — but they
  were sitting on the same edge. The protocol's value showed up in the
  same session it shipped.
- The script also flushed out a bash `read -r` gotcha: with
  `IFS=$'\t'`, consecutive tabs (when a field is empty) get collapsed
  because tab is treated as IFS-whitespace. Fixed by using a `"-"`
  placeholder for empty framework-dir lists instead of an empty field.

## [0.8.1] — 2026-05-21 — gngm-update.sh preserves project-only files

A safety fix for the updater. `gngm-update.sh` refreshed each managed
directory by `rm -f docs/GNGM/<dir>/*` then recopying from upstream — which
destroyed any **project-only** file a consuming project had added alongside
the GNGM-managed ones. The "non-destructive to project files" guarantee did
not hold for project files placed *inside* the GNGM subtree.

### Fixed

- **`scripts/gngm-update.sh`** — new `refresh_managed_dir` helper. Each
  managed directory (`protocols/`, `docs/`, `scripts/`, `clients/graphiti/`)
  is now refreshed by removing+recopying **only the files that exist
  upstream**. Files the project added itself (e.g. a project-specific
  `protocols/AVQA.md`) are detected and **preserved**, and each preserved
  file is printed. The post-refresh summary also warns explicitly that
  GNGM-managed files edited *in place* (e.g. a `DEBUG.md` extended with
  project runbooks) are still overwritten — an update cannot auto-merge
  those — and to `git diff docs/GNGM/` before committing.

### Discovered

- Found while updating the `winacard` project to 0.8.0: the blind wipe
  deleted winacard's project-only `protocols/AVQA.md` and overwrote its
  in-place-extended `protocols/DEBUG.md` (project debug runbooks + case
  studies). Both were git-tracked and recovered with `git checkout`, but the
  data-loss window was real — and a project whose GNGM subtree was not yet
  committed would have lost the files outright.

## [0.8.0] — 2026-05-21 — `/goal` autonomous mode + explicit AST refresh at NSH

Adds the `/goal` autonomous-mode guide and makes the Graphify AST refresh an
explicit, unconditional step of the Natural Stop Handoff — the code graph must
never lag the code at a session close.

### Added

- **`docs/09-GOAL-AUTONOMOUS-MODE.md`** — how to use Claude Code's `/goal`
  command (v2.1.139+) as a disciplined autonomy muscle. Core idea: `/goal` runs
  the work-loop, but **the completion condition is the discipline contract** —
  the Haiku evaluator checks the *condition*, not the methodology, so the GNGM
  gates (NLF proof artifacts, TDD RED→GREEN, wave CLOSE, the knowledge feed)
  must be encoded INTO the condition. Includes the loaded-≠-enforced
  clarification (the protocols load every turn, but "in context" is not
  "enforced" — the condition is), the executor-not-gates scoping, and the
  `stop after N turns` budget / ambiguity escape hatch. Stack-agnostic;
  generalized from a field-tested winacard draft.
- **`VERSION`** — a top-level version file (`0.8.0`), copied into
  `docs/GNGM/VERSION` by `install.sh` and `gngm-update.sh`. A consuming project
  can now check the GNGM release it is on with `cat docs/GNGM/VERSION` and
  compare against the upstream CHANGELOG to see what an update would bring.
  `gngm-update.sh` also prints the version after each refresh.

### Changed

- **`protocols/NATURAL-STOP-HANDOFF.md`** — Step 3 (GNGM post-fix sweep) gains
  an explicit **Graphify AST refresh** sub-step (`graphify update .`).
  Previously the AST graph was refreshed only implicitly via the post-commit
  hook; NSH now makes it explicit and unconditional — every natural stop
  refreshes the code graph, hook installed or not. `version: 1 → 2`.
- **`docs/06-WAVE-PROTOCOL.md`** — Stage 4 (EXECUTE) step 5 now states
  explicitly that the post-commit hook refreshes the Graphify AST graph on
  *every* atomic commit (~10s, no LLM) — so with atomic per-task commits the
  code graph is kept current many times per wave, *during* the work, not just
  at session close.
- **`README.md`, `install.sh`, `scripts/gngm-update.sh`, `docs/02-PROTOCOL.md`**
  — doc lists and the installed-project README heredocs now include `09`, so
  `gngm-update` carries the new doc into every consuming project.

## [0.7.0] — 2026-05-16 — Tool refresh: Graphify 0.8.5, Graphiti 0.29.0, mastery docs

Pins the knowledge-stack tools to current, verified versions; ships two
tool-mastery guides and an opt-in upgrade path for already-installed projects.

**Honest framing.** The two tools did not move equally — any broadcast of this
release should say so:

- **Graphify 0.4.x → 0.8.5** is a real upgrade — idempotent rebuilds with
  stable community IDs, headless `extract` with free/local backends, cross-repo
  `global` graphs, `callflow-html` diagrams, ~10 more languages.
- **graphiti-core 0.28.x → 0.29.0** is a maintenance bump — one minor version:
  security currency, an opt-in combined-extraction path (kept *off* on local
  Qwen), `summarize_saga`. No new capability GNGM relies on.

### Added

- **`docs/07-GRAPHIFY-MASTERY.md`** — using the Graphify code graph to full
  potential: verified 0.8.5 command grammar, graph-first reasoning, backends,
  idempotency. States plainly that Graphify has no embeddings and no spectral
  methods — it is AST + Leiden, by deliberate design.
- **`docs/08-GRAPHITI-MASTERY.md`** — using the Graphiti temporal graph to full
  potential: episode discipline, the causal-chain rule, validity windows,
  correction episodes, sagas, and the honest local-Qwen caveats.
- **`docs/UPGRADE-0.7.0.md`** — the migration guide for existing projects.
- **`scripts/gngm-upgrade-tools.sh`** — opt-in tool upgrade. Rebuilds
  `.venv-graphify` to the pinned graphifyy, does the one-time 0.4→0.8 graph
  housekeeping (cache clear, ghost-duplicate cleanup, community renumber), bumps
  graphiti-core, refreshes the vendored client. Prompts before mutating;
  idempotent. Kept separate from `gngm-update.sh` so that stays docs-only.
- **`clients/` now propagates.** `install.sh` and `gngm-update.sh` carry
  `docs/GNGM/clients/` into consuming projects, so the vendored Graphiti client
  actually reaches the fleet — previously it never left this repo.

### Changed

- **Versions pinned** — `graphifyy[mcp]==0.8.5` and
  `graphiti-core[falkordb]==0.29.0` across `gngm-init.sh`, `install-services.sh`,
  `00-INSTALL-FROM-SCRATCH.md`, `01-SETUP.md`, `gngm-health.sh`, and the README.
  Unpinned installs are what let the docs drift ~4 versions behind reality.
- **`clients/graphiti/qwen_client.py`** — verified against graphiti-core 0.29.0
  by schema introspection, then patched: the `NodeResolutions` and
  `SummaryDescription` few-shot examples were stale (they referenced the removed
  `duplicate_name` field and a removed `summary` field) and would have
  mis-taught the local Qwen extractor. Few-shots corrected, the dead
  `duplicate_name` synonym repointed to `duplicate_candidate_id`, and
  `episode_indices` added to the entity/edge examples.
- `gngm-update.sh` now also refreshes `docs/GNGM/clients/`; its non-destructive
  contract is now `{protocols,docs,scripts,clients}/`.
- The installed-project README heredocs (`install.sh`, `gngm-update.sh`) now
  list docs 00–08 + UPGRADE and the `gngm-upgrade-tools.sh` step.

### Fixed

- **`gngm-init.sh`** — hardcoded `/home/neil1988/.graphiti` path; broke the
  Graphiti seed step for every consuming project not on the author's machine.
  Now `$HOME/.graphiti`.
- **`01-SETUP.md`** — the Graphiti install line omitted `httpx`, which the
  vendored client imports; following the doc verbatim would `ImportError`.
- **Graphiti install lines** — switched the hand-listed `falkordb-client` to
  graphiti-core's official `[falkordb]` extra (verified to pull the correct
  driver dependency).
- **`gngm-health.sh`** — the "graphify missing" fix hint printed an unpinned
  `graphifyy[mcp]`; now pinned.

### Known follow-ups (not in this release)

- `01-SETUP.md`, `02-PROTOCOL.md`, and `03-CHEATSHEET.md` still use `newfin` as
  the example project name (and a hardcoded home path in code samples). A
  de-specialization pass to generic `<your-project>` placeholders is recommended
  as a focused fast-follow.

## [0.6.2] — 2026-04-27 — Hygiene closure (script bug fix + frontmatter sweep)

`bash scripts/gngm-hygiene-check.sh` now returns ✅ all green. Closes a structural-discipline gap that 0.6.0 + 0.6.1 added new protocols around but didn't audit the existing baseline against.

### Fixed

- **`scripts/gngm-hygiene-check.sh`** — `grep -c` bug. `grep -c` returns exit code 1 when a pattern matches 0 times, while ALSO printing `0` to stdout. The old `var=$(grep -c ... || echo 0)` then concatenated stdout `0` + fallback `echo 0` into a multi-line string `"0\n0"`. The downstream `[ "$var" -eq 0 ]` test silently failed under `set -u` (no integer match), so missing `## Related` / `## Docs` sections were never reported. Real violations were 17 across the repo while the script reported only 14 (frontmatter-only). Replaced with a dedicated `count_matches()` helper that always emits a single integer.

### Added (script)

- **`scripts/gngm-hygiene-check.sh`** — `HYGIENE_EXCLUDE_BASENAMES` list. README.md, CHANGELOG.md, LICENSE.md, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md are excluded from the frontmatter rule. These are conventional repo files where YAML frontmatter is non-idiomatic (GitHub renders the YAML block instead of treating it as metadata). Honest exclusion beats fake compliance.

### Added (frontmatter to 12 files)

12 files gained frontmatter so `head -1` returns `---`:

- `protocols/SDP.md` + `## Docs`
- `protocols/TDD.md` + `## Docs`
- `protocols/GIT-SAFETY.md` + `## Docs`
- `protocols/GIT-HYGIENE.md` + `## Related` + `## Docs` (the cross-references existed inline; promoted into proper sections)
- `protocols/STRESS-TEST.md` (already had Related + Docs)
- `docs/00-INSTALL-FROM-SCRATCH.md` + `## Related` (renamed from "See also") + `## Docs`
- `docs/01-SETUP.md` (already had Related + Docs)
- `docs/02-PROTOCOL.md` + `## Related` + `## Docs` (no See also to rename)
- `docs/03-CHEATSHEET.md` + `## Related` (renamed) + `## Docs`
- `docs/04-LESSONS.md` + `## Related` (renamed) + `## Docs`
- `docs/05-PROJECT-STRUCTURE.md` (already had Related + Docs)
- `docs/06-WAVE-PROTOCOL.md` (already had Related + Docs)

### Added (## Docs sections to 5 protocols I authored without them)

The 0.6.0 + 0.6.1 protocols I added had `## Related` but consistently missed `## Docs`. Caught by the now-fixed hygiene script:

- `protocols/NLF.md` — added `## Related` + `## Docs` (had neither — narrative-style original)
- `protocols/PRD.md` — added `## Docs`
- `protocols/PRD-TO-ISSUES.md` — added `## Docs`
- `protocols/UBIQUITOUS-LANGUAGE.md` — added `## Docs`
- `protocols/IMPROVE-ARCHITECTURE.md` — added `## Docs` (replaced trailing Ousterhout reference inside it)

### Why this release matters

The hygiene script existed but under-reported. Self-discipline only works if the tool measuring it tells the truth. 0.6.2 makes the tool honest, then makes the repo conform to what the honest tool says. NLF discipline applied to ourselves: we don't pretend the hygiene rule applies to README.md (it doesn't, conventionally) and we don't pretend our protocol files were fully compliant when they weren't.

### Verification

```bash
$ bash scripts/gngm-hygiene-check.sh
=== GNGM Hygiene Check ===

[1/4] Frontmatter + ## Related + ## Docs
  ✓ all .md files have frontmatter + ## Related + ## Docs

[2/4] MEMORY.md ≤ 100 lines
  — MEMORY.md not present (Claude-Code-only feature, OK to skip)

[3/4] docs/current/ ≤ 3 files
  — docs/current/ not present

[4/4] lessons/ structure sanity
  ✓ lessons/ structure OK

=== Summary ===
All hygiene checks passed ✓
```

## [0.6.1] — 2026-04-27 — Discoverability + update path

Tightens the 0.6.0 release so already-installed projects can pick up the new product/scoping protocols cleanly, and so the new triggers are discoverable from the README without hunting through frontmatter.

### Added

- **`scripts/gngm-update.sh`** — non-destructive refresh script for already-installed projects. Touches ONLY `<project>/docs/GNGM/{protocols,docs,scripts}/` — never project files (`CLAUDE.md`, `MEMORY.md`, project docs, lessons, source, etc.). Safe to re-run anytime. Also regenerates the thin `docs/GNGM/README.md` pointer so it stays current. Run via `bash docs/GNGM/scripts/gngm-update.sh` from inside an install OR `curl ... | bash -s -- /path/to/project` direct from upstream.

### Updated

- **`README.md`** — Added "Engineering protocol triggers" table next to the existing "Knowledge-stack triggers" table so all 11 trigger phrases (NLF, SDP, TDD/DEBUG, RAC, LOG, STRESS, NSH, PRD, PRD-TO-ISSUES, UL, IA) are discoverable in one scan. Added "Updating an already-installed GNGM" subsection documenting the gngm-update.sh path. Added gngm-update.sh row to the install-paths table and the repository-structure tree.

- **`templates/CLAUDE.md.tpl`** — Trigger phrases table split into knowledge-stack vs engineering-protocol clusters (matches main README structure). Added all 11 protocol triggers (was 4). Discipline section gained PRD-first guidance (§3) and NSH session-close guidance (§5). Governance authority line generalized from "NLF, SDP, TDD, GIT-SAFETY" hard-coded list to "see docs/GNGM/README.md for canonical list" so future protocol additions don't require template edits.

- **`templates/docs/protocols-_INDEX.md.tpl`** — Core protocols section expanded from 4 hard-coded entries to all 13, grouped by cluster (Foundational / Operational / Product+Scoping). Added cross-ref to canonical README.

- **`templates/memory/rules-_INDEX.md.tpl`** — Generalized stale "NLF, SDP, TDD, GIT-SAFETY" reference to point at the canonical README.

### Why this release matters

0.6.0 shipped the four new protocols (PRD + PRD-TO-ISSUES + UL + IA), but downstream projects that already had GNGM installed had three friction points picking them up:

1. No dedicated update path — `install.sh` works but prompts y/N to overwrite, and conflates "first install" with "refresh."
2. Templates rotted with hard-coded 4-protocol lists, so newly-scaffolded projects didn't even see the new ones in their generated `CLAUDE.md` / `protocols/_INDEX.md`.
3. The new triggers (`PRD`, `UL`, `IA`, `PRD-TO-ISSUES`) lived only in protocol frontmatter — invisible from the README scan.

0.6.1 fixes all three. After this release:

- Already-installed projects: `bash docs/GNGM/scripts/gngm-update.sh` → picks up everything new
- New scaffolds: templates list all 14 protocols + reference the canonical README
- Discoverability: `README.md` shows all 11 triggers in one place

### Migration

For projects on 0.5.0 or earlier installing 0.6.0+ for the first time, both options work:

```bash
# Option A — re-install (overwrites)
curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/install.sh | bash -s -- /path/to/project

# Option B — update (non-destructive, only touches docs/GNGM/)
curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/scripts/gngm-update.sh | bash -s -- /path/to/project
```

Option B is the new recommended path for refreshing existing installs.

## [0.6.0] — 2026-04-27 — Product / scoping protocol cluster

The 0.5.0 release added operational protocols (RAC + DEBUG + LOGGING + STRESS + NSH). This release closes the front-of-funnel gap: PRD creation, vertical-slice decomposition, domain glossary discipline, and proactive architectural audits. SDP previously assumed a spec already existed; with this release, the full chain runs PRD → PRD-TO-ISSUES → SDP (one loop per issue) → NSH.

### Added

- **`protocols/PRD.md`** — Product Requirements Document protocol. Interactive PRD creation through user interview, GNGM-grounded codebase exploration, and deep-module sketching. 5 steps: get the long form → GNGM the codebase → interview relentlessly → sketch deep modules → write the PRD. Output is a self-contained PRD document (GitHub issue, local spec, or platform-equivalent) that downstream protocols consume. Trigger: `PRD`.

- **`protocols/PRD-TO-ISSUES.md`** — Vertical-slice decomposition protocol. Break a PRD into independently-grabbable issues using tracer-bullet vertical slices (each cuts through schema → API → UI → tests end-to-end). HITL vs AFK explicit per slice. Each completed issue feeds exactly one SDP loop. Bridges the PRD → SDP gap so downstream implementation never has to re-derive scope. Trigger: `PRD-TO-ISSUES`.

- **`protocols/UBIQUITOUS-LANGUAGE.md`** — DDD-style domain glossary protocol. Extract canonical terms from conversation / PRD / codebase. Flags ambiguities (one word for many concepts, many words for one concept) and proposes opinionated canonical terms with aliases-to-avoid. Saves to `UBIQUITOUS_LANGUAGE.md`. Auto-suggested by NSH Step 3.5 when the glossary is stale (>30 days OR new domain terms surfaced this session). Triggers: `UBIQUITOUS-LANGUAGE`, `UL`.

- **`protocols/IMPROVE-ARCHITECTURE.md`** — Codebase architectural audit protocol. Explore organically (friction-as-signal, not rigid heuristics), surface deepening candidates per Ousterhout's deep-module thesis, spawn 3+ parallel sub-agents to design competing interfaces, ship an opinionated refactor RFC. Complements RAC at the L3 (Execution) layer where module shape determines testability + AI-navigability. Quarterly cadence recommended for active codebases. Triggers: `IMPROVE-ARCHITECTURE`, `IA`.

### Updated

- **`protocols/NATURAL-STOP-HANDOFF.md`** — Step 3.5 added: glossary refresh check (UBIQUITOUS-LANGUAGE hook). Auto-suggests UL run if the glossary is stale or new domain terms surfaced this session. Operator can accept (`yes`), defer (`no`), or suppress for the rest of the session (`skip`). Skipped entirely under `NSH minimal`. NSH Relationship table + Related section also extended to reference PRD / PRD-TO-ISSUES / IMPROVE-ARCHITECTURE for multi-session continuity.

- **`README.md`** — Engineering protocols section restructured into three clusters: Foundational (NLF + SDP + TDD), Operational, and Product / scoping (added 0.6.0). Repository structure tree updated to list all 14 protocols (also adds GIT-HYGIENE which was missing from the prior tree).

- **`CHANGELOG.md`** — This entry.

### Design notes

The four new protocols were chosen by redundancy-mapping against existing GNGM protocols and rejecting `grill-me` (overlap with SDP Steps 1 + 2 was too high to justify a separate protocol — the discipline already lives inside the ECC review loop).

The kept four fill discrete gaps:

- **PRD** — front-of-funnel artifact creation; SDP previously assumed this existed
- **PRD-TO-ISSUES** — bridges PRD → SDP-instances; prevents one mega-PR or N horizontal-layer PRs
- **UBIQUITOUS-LANGUAGE** — terminology discipline; previously implicit, now an artifact other protocols reuse
- **IMPROVE-ARCHITECTURE** — L3 (module-shape) hygiene; orthogonal to RAC's pipeline-shape methodology

The full chain now runs:

```
PRD → PRD-TO-ISSUES → SDP (per issue) → NSH (per session) → UL refresh (if stale)
                ↑                                                    ↑
       (IMPROVE-ARCHITECTURE                            (auto-suggested by NSH)
        if touch path is shallow)
```

Thirteen universal protocols, no project-specific context required for any of them.

### Field-tested status

These four protocols are derived from the mattpocock/skills (`write-a-prd`, `prd-to-issues`, `ubiquitous-language`, `improve-codebase-architecture`) — battle-tested community skills with thousands of real-world invocations. The GNGM adaptations preserve the original mechanics while wiring them into the GNGM stack (NLF discipline, GNGM pre-task sweep, NSH integration, cross-protocol cross-references). First GNGM-flavored execution will land in winacard or LocalizationTools work; cross-validation lands in 0.6.1.

## [0.5.0] — 2026-04-25 — Operational protocol cluster

The original three protocols (NLF + SDP + TDD) covered the engineering loop. This release adds five more that cover the operational layer around it: pipeline methodology, debugging, logging, stress, and session close.

### Added

- **`protocols/RAC.md`** — Repeatable Action Chain. Universal methodology for any pipeline-shaped workflow (software OR non-software). 10 invariants, 5 layers, 7 failure modes, 12-field cross-domain gallery, 3 famous-failure case studies (Boeing 737 MAX MCAS, Theranos, GameStop clearing), 2 smallest-possible examples (monthly invoice send + fire-extinguisher inspection). Trigger: `RAC`.
- **`protocols/DEBUG.md`** — Systematic debugging. Iron Law: no fixes without root-cause investigation. Phase 0 GNGM Pentology pre-flight. `capture.sh` evidence bundler. R1-R11 runbook ledger. WC-NNN case-study ledger. Triggers: `DEBUG`, `DEBUG R<n>`.
- **`protocols/LOGGING.md`** — Backend + frontend logging standards. `x-trace-id` correlation-ID round-trip contract. Structured event naming (`event_name` snake_case, never sentence-text). PII rules. Audit-log vs operational-log separation. Trigger: `LOG`.
- **`protocols/STRESS-TEST.md`** — 7-dimension stress discipline (concurrency, burst rate, reconnect churn, state exhaustion, memory leak, cascading failure, long-tail latency). Smart small-N pressure with falsifiable invariants + cost guards (NEVER full-throttle on paid APIs). Triggers: `STRESS`, `STRESS <feature>`.
- **`protocols/NATURAL-STOP-HANDOFF.md`** — NSH. When work hits a natural stop (logical-unit complete + tree clean + tests green + clarity high), Claude proactively runs a 7-step session-close instead of waiting for the operator to dictate the post-flight checklist. Closes the off-machine-gap + discovery-rot + state-drift trio that bites every long session. Variants: `NSH dry`, `NSH no push`, `NSH minimal`. Trigger: `NSH`.

### Updated

- **`README.md`** — Engineering protocols section split into "Foundational (the original three)" and "Operational (added 0.5.0)". Repository structure tree updated to list all 9 protocols.

### Field-tested

All five protocols were authored and shaped during real winacard waves (4.6, 4.7, 5.1, 8, 8.5):

- RAC — distilled while building the asset generation pipeline (4.7) and the live-inventory compliance chain (Wave 8).
- DEBUG — formalized during Wave 8.5's debug+logging infrastructure work; WC-001 case study (duplicate `vite preview` processes) is the first ledger entry.
- LOGGING — the correlation-ID contract was wired during Wave 8.5; every Wave 8 frontend+backend log call uses the format pinned here.
- STRESS-TEST — surfaced after Wave 8 brainstorming about live-inventory race conditions; recommends adding burst-rate + SSE-flap + memory-leak tests before launch.
- NATURAL-STOP-HANDOFF — first execution shipped Wave 8 c17 (verify) + this exact 0.5.0 release commit. The protocol is field-tested by being the very thing that pushed it.

## [0.4.0] — 2026-04-23 — Full project scaffolding

Tools alone weren't enough. GNGM now ships a full project structure bootstrapper so projects can harness the knowledge stack from day 1 — no manual scaffolding, no hunting for what's missing.

### Added

- **`scripts/gngm-full-scaffold.sh`** — full project scaffolder (idempotent, works on empty dirs AND existing repos, multi-CLI aware)
- **`scripts/gngm-hygiene-check.sh`** — validates frontmatter + `## Related`/`## Docs` sections + MEMORY.md line count + docs/current/ file count
- **`docs/05-PROJECT-STRUCTURE.md`** — canonical project tree, adaptation patterns for any language/stack, multi-CLI support
- **`docs/06-WAVE-PROTOCOL.md`** — 7-stage wave lifecycle (OPEN → BRAINSTORM → PLAN REVIEW → EXECUTE → VERIFY → CODE REVIEW → CLOSE)
- **`templates/`** directory with 18 template files:
  - `CLAUDE.md.tpl` + `MEMORY.md.tpl`
  - `memory/` branch templates (user, rules, active, reference)
  - `docs/` tree `_INDEX.md` templates (INDEX, current, architecture, reference, protocols, waves, history)
  - `lessons/` templates (_INDEX + domain template)
  - `graphifyignore.tpl`, `gitignore.tpl`, `env-example.tpl`
- **`docs/04-LESSONS.md`** Lesson #11 — "Tools installed ≠ project ready"

### Adaptability

- **Any CLI AI:** `--ai-cli claude` (CLAUDE.md) / `codex` (AGENTS.md) / `gemini` (GEMINI.md) / `all` (all three, identical content)
- **Any stack:** language/framework-agnostic — your code tree sits alongside the GNGM scaffold
- **Any repo state:** idempotent, grafts onto existing repos without clobbering

### Updated

- `README.md` — "Three paths to installation" section explaining install.sh vs gngm-init.sh vs gngm-full-scaffold.sh + CLI AI support
- `README.md` repository structure — added `templates/`, updated `scripts/` + `docs/`

### Why this release

Discovered while bootstrapping `winacard` project: `gngm-init.sh` ran green but the project wasn't actually ready. Memory trunk missing, CLAUDE.md missing, docs tree not laid out, no `.graphifyignore`. Had to retrofit everything manually for 30 minutes. This release codifies that manual work so no future project has to repeat it.

## [0.3.0] — 2026-04-18 — Engineering protocols added

Added universal engineering protocols that layer on top of the knowledge stack.

### Added

- `protocols/NLF.md` — No Lie Fix (real root cause only, forbidden-bandage rule, trigger phrase `NLF`)
- `protocols/SDP.md` — Standard Development Protocol (5-step baseline: Brainstorm → ECC plan review → Execute → TDD certificate → ECC code review)
- `protocols/TDD.md` — TDD baseline + First-Debug Protocol (6-step heavy variant for production bug fixes from logs)

### Updated

- `README.md` — new "Engineering protocols" section with links + summary
- `install.sh` — now copies `protocols/` directory into target projects alongside `docs/` and `scripts/`
- `docs/03-CHEATSHEET.md` — protocols section added

## [0.2.0] — 2026-04-18 — Standalone repo launch

First public release of GNGM as a standalone installable repo. Protocol v2.

### Added

- Standalone repo structure with root-level `install.sh` for one-command setup into any project
- `docs/01-SETUP.md` — service prerequisites + installation (Docker, Ollama, Graphify)
- `docs/02-PROTOCOL.md` — full 4-mode protocol (pre-task / post-fix / organizational / health)
- `docs/03-CHEATSHEET.md` — one-page quick reference
- `docs/04-LESSONS.md` — 9 pitfalls + resilience patterns from production use
- `scripts/gngm-health.sh` — 10-second 4-tool green/red check (venv-aware)
- `scripts/gngm-init.sh` — idempotent project bootstrap (auto-creates `.venv-graphify/`, installs `graphifyy[mcp]`, runs `graphify hook install`, initial `graphify update .`, seeds Graphiti)
- MIT LICENSE

### Protocol v2 — key additions over v1

- **Saturation detection** — when 20/20 diversity topics return ≥9 facts, switch FEED → CONSUME discipline
- **Compile discipline** — after `lesson_add`, auto-queue domains crossing 3 lessons without a wiki; compile same session, never defer
- **Hook-first setup** — `graphify hook install` on day 1, not later
- **Orphan non-deletion rule** — classify KEEP / CONSOLIDATE / ARCHIVE (never delete — wikis consumed via Viking semantic search, not markdown links)
- **Tool-failure resilience** — 9 documented patterns: Qwen Ollama timeout, heredoc+`&` silent failure, MCP restart hazard, two-clone trap, `Path.relative_to` external-path crash, SQLAlchemy Row `[str]` bug, CORS + middleware-header drift, parasitic DEFINITIVE docs, ECC recommendations need verification
- **Parallel GNGM queries** — 4 layers in one message = ~4× wall-clock speedup on pre-task
- **Topic granularity rule** — 2-3 specific entity names beats one generic phrase
- **Background episode pattern** — write to `/tmp/episode.py` + `run_in_background`; never combine heredoc with `&`

### Origin story

Developed during LocalizationTools project work across ~6 months of real production use.

Battle-tested on two projects (LocalizationTools + newfin) before extraction to this standalone repo. Reference implementation lives at `/home/neil1988/newfin/docs/GNGM/` which mirrors this repo's structure (modulo the top-level README adaptation for standalone framing).

Canonical protocol source (for maintainers): LocalizationTools `memory/rules/gngm_protocol.md` v2.

## Future (planned)

- [ ] Helper CLI: `gngm` command that wraps the scripts (`gngm init`, `gngm health`, `gngm status`)
- [ ] Platform-specific setup guides (macOS, Windows/WSL2, Linux distributions)
- [ ] Example projects demonstrating GNGM on different stacks (Python/Node/Rust/Go)
- [ ] Translations of the protocol docs (JP, KR, CN communities)
- [ ] Integration with additional MCP servers as they emerge

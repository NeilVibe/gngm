# Changelog

All notable changes to GNGM (the portable knowledge stack protocol).

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

# Changelog

All notable changes to GNGM (the portable knowledge stack protocol).

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

# GNGM — Knowledge Stack Protocol for AI Coding Agents

**GNGM** = **G**raphiti + **N**euralTree + **G**raphify + **M**emoryMCP.

A portable 4-layer knowledge stack that gives Claude Code (or any AI coding agent) persistent, cross-session intelligence about a project. Four overlapping knowledge layers — where overlap is a feature, not a bug: corroboration catches LLM extraction failures, code drift, and stale rules.

## The four layers

| Layer | Tool | Answers | Cost |
|---|---|---|---|
| **G**₁ | **Graphiti** (Qwen 3.5 9B + FalkorDB) | "Why did we choose X? When did Y change? Who decided?" | ~5s search / ~30s add_episode |
| **N** | **NeuralTree** (lessons → wikis) | "Have we fixed this exact symptom? What's the rule for this domain?" | Free |
| **G**₂ | **Graphify** (AST + Leiden code graph) | "What calls X? What's the path A→B? Show me the code graph." | ~10s update / ~3s query |
| **M** | **MemoryMCP** (cross-session entity graph) | "What does the user prefer here? What durable rule applies?" | Free |

One keystroke ("GNGM") activates all four simultaneously. See [docs/02-PROTOCOL.md](docs/02-PROTOCOL.md) for mechanics.

## Why it matters

Without a knowledge stack, every AI coding session re-derives knowledge that already exists. With GNGM, every session builds on every prior one:

- **Why did we weight X=10, Y=80 in the scoring system?** → Graphiti episode
- **How do we handle edge case Z?** → NeuralTree lesson
- **What's the structure of `main.py`?** → Graphify code-graph
- **What did the user say about their workflow?** → MemoryMCP rule

Agents stop rediscovering and start remembering.

## Full install from scratch

New to the stack? See **[docs/00-INSTALL-FROM-SCRATCH.md](docs/00-INSTALL-FROM-SCRATCH.md)** — 8-phase comprehensive guide for Docker, Ollama, Qwen, FalkorDB, Viking, NeuralTree MCP, Memory MCP, Graphiti client, Graphify venv, and Claude Code wiring. Everything is open-source; total install ~30-60 min.

Or run the one-shot services installer (review before running — makes system-wide changes):

```bash
git clone https://github.com/NeilVibe/gngm.git ~/gngm
cd ~/gngm
bash scripts/install-services.sh
```

## Three paths to installation

| Path | What it does | When to use |
|---|---|---|
| `install.sh` | Copies GNGM docs + protocols + scripts into `<project>/docs/GNGM/` | Minimal — just want the reference docs |
| `gngm-init.sh` | Tools bootstrap: Graphify venv + hooks + Graphiti seed + health check | Just want the TOOLS |
| **`gngm-full-scaffold.sh`** | **Full project structure: memory trunk + CLAUDE.md/AGENTS.md + docs tree + lessons + tools** | **Recommended — new projects OR grafting onto existing repos** |

### Full scaffold (recommended, ~1 minute)

```bash
# 1. Install GNGM files into target project
curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/install.sh | bash -s -- /path/to/your/project

# 2. Full scaffold (structure + tools, in one go)
cd /path/to/your/project
bash docs/GNGM/scripts/gngm-full-scaffold.sh
```

The full scaffold is **idempotent** — safe to re-run, never clobbers existing files. It works in empty dirs AND existing repos (grafts GNGM on without touching your code).

### CLI AI support

GNGM works with any CLI AI. The scaffold script supports:

```bash
bash gngm-full-scaffold.sh --ai-cli claude   # CLAUDE.md (default)
bash gngm-full-scaffold.sh --ai-cli codex    # AGENTS.md (Codex CLI / Cursor / many)
bash gngm-full-scaffold.sh --ai-cli gemini   # GEMINI.md (Gemini CLI)
bash gngm-full-scaffold.sh --ai-cli all      # all three — multi-CLI project
```

Content is identical — only filename differs per CLI convention.

### Tools only (no project scaffolding)

```bash
cd /path/to/your/project
bash docs/GNGM/scripts/gngm-init.sh
```

`gngm-init.sh` just does tooling — Graphify venv + hooks + Graphiti seed + health check. Use when you've already got your own project structure and just want the knowledge-stack tools.

### Full structure documentation

- **[docs/05-PROJECT-STRUCTURE.md](docs/05-PROJECT-STRUCTURE.md)** — canonical file tree, adaptation patterns for any language/stack, multi-CLI support
- **[docs/06-WAVE-PROTOCOL.md](docs/06-WAVE-PROTOCOL.md)** — how waves/phases run against the structure (7-stage lifecycle)

## Prerequisites (shared across all projects)

GNGM depends on these services running on your machine:

| Service | Purpose | Install |
|---|---|---|
| **FalkorDB** (Docker) | Graphiti backend | `docker run -d --name falkordb -p 6379:6379 falkordb/falkordb:edge` |
| **Ollama + Qwen 3.5 9B** | Graphiti LLM (entity extraction) | `ollama pull qwen3.5:9b` |
| **Viking** (semantic search) | Document search | See [docs/01-SETUP.md](docs/01-SETUP.md) |
| **NeuralTree MCP server** | Lesson/wiki tools in Claude Code | See [docs/01-SETUP.md](docs/01-SETUP.md) |
| **Memory MCP** | Cross-session entity graph | Built into Claude Code |

Full setup: [docs/01-SETUP.md](docs/01-SETUP.md)

## Canonical trigger phrases (say in Claude Code chat)

| You say | Mode | What happens |
|---|---|---|
| `GNGM` | full stack | Pre-task, post-fix, or cleanup depending on context |
| `GNGM pre-task` / `GNGM before` | pre-task | Parallel search all 4 layers before investigating |
| `GNGM post-fix` / `GNGM after` | post-fix | Feed all 4 layers with fresh learnings |
| `GNGM cleanup` / `GNGM audit` | organizational | Saturation check + compile queue + orphan audit |
| `GNGM health` / `GNGM status` | health | 10-second 4-tool green/red check |
| `full GNGM` / `mega GNGM` | everything | Pre-task → work → post-fix → quick org pass |

## Engineering protocols (complement to GNGM)

GNGM is the knowledge stack. These are the engineering disciplines that use it:

- **[protocols/NLF.md](protocols/NLF.md)** — **No Lie Fix.** Real root cause only, forbidden-bandage rule. Self-invoked when drifting toward `comment out / disable / catch-and-ignore`. Trigger: user says `NLF`.
- **[protocols/SDP.md](protocols/SDP.md)** — **Standard Development Protocol.** Baseline for ALL code changes: Brainstorm → ECC Plan Review → Execute → TDD Certificate → ECC Code Review → Learn.
- **[protocols/TDD.md](protocols/TDD.md)** — **TDD baseline + First-Debug Protocol (heavy).** RED → GREEN per change; for production bugs, the 6-step discipline (read logs → trace → grill → simulate → RED tests → plan with exact code).

All three are universal across projects; no project-specific context required.

## Repository structure

```
gngm/
├── README.md              (this file)
├── LICENSE                MIT
├── CHANGELOG.md           version history
├── install.sh             one-command installer for any project
├── docs/
│   ├── 00-INSTALL-FROM-SCRATCH.md  (8-phase install guide)
│   ├── 01-SETUP.md                 prerequisites + installation
│   ├── 02-PROTOCOL.md              full 4-mode protocol mechanics
│   ├── 03-CHEATSHEET.md            one-page quick reference
│   ├── 04-LESSONS.md               11 pitfalls + resilience patterns
│   ├── 05-PROJECT-STRUCTURE.md     canonical project tree + adaptation patterns
│   └── 06-WAVE-PROTOCOL.md         wave lifecycle (7 stages) — works for any stack
├── protocols/
│   ├── NLF.md                      No Lie Fix — real root cause only
│   ├── SDP.md                      Standard Development Protocol
│   ├── TDD.md                      TDD baseline + First-Debug Protocol
│   └── GIT-SAFETY.md               git safety rules
├── templates/
│   ├── CLAUDE.md.tpl               project-level instructions template
│   ├── MEMORY.md.tpl               memory trunk template
│   ├── memory/                     memory branch templates
│   ├── docs/                       docs/ tree _INDEX templates
│   ├── lessons/                    lesson domain templates
│   ├── graphifyignore.tpl          standard exclusions
│   ├── gitignore.tpl               standard gitignore
│   └── env-example.tpl             env.example baseline
├── clients/graphiti/
│   ├── qwen_client.py              vendored (Qwen 4-stage salvage pipeline)
│   └── feed_project.py             project seeding helper
└── scripts/
    ├── gngm-health.sh              10-second 4-tool health check
    ├── gngm-init.sh                tool bootstrap (graphify + Graphiti)
    ├── gngm-full-scaffold.sh       FULL project scaffold (structure + tools)
    ├── gngm-hygiene-check.sh       validate frontmatter + cross-refs
    └── install-services.sh         one-shot services installer
```

## Three design principles behind portability

### 1. Parameterize project identity

Default `GRAPH_NAME=$(basename $(pwd))` — every project gets its own Graphiti graph automatically. No hardcoding.

### 2. Venv-first, PATH fallback, auto-create

Scripts resolve Graphify in three steps:

```bash
if [ -x ".venv-graphify/bin/graphify" ]; then
    GRAPHIFY_BIN=".venv-graphify/bin/graphify"         # 1. project venv
elif command -v graphify >/dev/null 2>&1; then
    GRAPHIFY_BIN="$(command -v graphify)"              # 2. global install
else
    python3 -m venv .venv-graphify                     # 3. auto-create
    .venv-graphify/bin/pip install "graphifyy[mcp]"
fi
```

Matches Python tool-isolation norms. Survives across machines without global-install assumptions.

### 3. Idempotent bootstrap

`gngm-init.sh` checks whether each artifact already exists before creating. Safe to re-run during onboarding, after a fresh clone, or when debugging a broken install.

## What GNGM is NOT

- **Not a replacement** for existing tools (it coordinates them)
- **Not project-specific** (the whole point is cross-project portability)
- **Not magic** — it still needs you to run `GNGM` triggers during work

## When to use GNGM

Use it when:
- You work on projects across multiple sessions and lose context between them
- You have a long-running codebase where "why did we do X" questions are common
- You want AI agents to learn from past fixes instead of re-deriving them
- You want auto-maintained knowledge that stays current with code via git hooks

Don't bother when:
- One-off scripts or prototypes
- Single-session projects
- Projects where you always have full context in your head

## License

MIT — see [LICENSE](LICENSE). Use it freely; attribution appreciated.

## Contributing

This is an opinionated tool. If you have improvements or a different project structure that works better, please open an issue — especially:

- New resilience patterns discovered in production use
- Additional integration points with other MCP servers
- Platform-specific setup adaptations (Windows, macOS variations)
- Translations of the protocol docs

## Attribution

Developed during LocalizationTools project work (2026-04). Exported and generalized based on real production use. Battle-tested on two projects (LocalizationTools + newfin) before extracting to this standalone repo.

See [docs/04-LESSONS.md](docs/04-LESSONS.md) for the 10 production pitfalls that shaped this design.

---

**Start here:** [docs/01-SETUP.md](docs/01-SETUP.md) if you're on a fresh machine, otherwise run `install.sh` into your project and go.

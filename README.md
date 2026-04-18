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

## Install in a new project (30 seconds)

```bash
# One-liner from anywhere — drops GNGM into target project
curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/install.sh | bash -s -- /path/to/your/project

# Then bootstrap the target project
cd /path/to/your/project
bash docs/GNGM/scripts/gngm-init.sh
```

Or manually:

```bash
git clone https://github.com/NeilVibe/gngm.git ~/gngm
cp -r ~/gngm/docs ~/gngm/scripts /path/to/your/project/docs/GNGM/
cd /path/to/your/project
bash docs/GNGM/scripts/gngm-init.sh
```

The `gngm-init.sh` script is idempotent — safe to re-run. It:

1. Creates `lessons/` + `.neuraltree/wiki/` directories with `_INDEX.md` templates
2. Auto-creates `.venv-graphify/` and installs `graphifyy[mcp]` if not already installed
3. Installs `graphify` post-commit + post-checkout hooks (auto-refresh graph on every commit)
4. Runs initial `graphify update .` AST build
5. Seeds the Graphiti graph with a bootstrap episode (using current directory name)
6. Runs the health check

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

## Repository structure

```
gngm/
├── README.md              (this file)
├── LICENSE                MIT
├── CHANGELOG.md           version history
├── install.sh             one-command installer for any project
├── docs/
│   ├── 01-SETUP.md        prerequisites + installation
│   ├── 02-PROTOCOL.md     full 4-mode protocol mechanics
│   ├── 03-CHEATSHEET.md   one-page quick reference
│   └── 04-LESSONS.md      9 pitfalls + resilience patterns
└── scripts/
    ├── gngm-health.sh     10-second 4-tool health check
    └── gngm-init.sh       idempotent project bootstrap
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

See [docs/04-LESSONS.md](docs/04-LESSONS.md) for the 9 production pitfalls that shaped this design.

---

**Start here:** [docs/01-SETUP.md](docs/01-SETUP.md) if you're on a fresh machine, otherwise run `install.sh` into your project and go.

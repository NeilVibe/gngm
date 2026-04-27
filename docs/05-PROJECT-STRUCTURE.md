---
name: GNGM Project Structure — Harnessing the Full Power of GNGM
description: GNGM is only half the story; the other half is the project structure the knowledge stack lives inside. Canonical project tree, adaptation patterns for any language/stack, multi-CLI support (CLAUDE.md / AGENTS.md / GEMINI.md), and the rules that make the structure compound rather than rot.
type: gngm-doc
last_verified: 2026-04-27
---

# Project Structure — Harnessing the Full Power of GNGM

> GNGM is only half the story. The other half is the **project structure** the knowledge stack is embedded into. This doc describes the canonical structure, why it exists, and how to adapt it to any project or CLI AI.

## Why this doc exists

GNGM gives you powerful tools (Graphiti, NeuralTree, Graphify, MemoryMCP). But tools without structure turn into noise. Without:

- **Memory trunk** at `~/.claude/projects/<id>/memory/` — no cross-session continuity
- **Project-level instructions file** (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md`) — no session-start context
- **docs/ tree convention** — people invent random layouts
- **Lesson domain planning** — lessons accumulate chaotically, never compile
- **`.graphifyignore`** — Graphify indexes `.venv/`, `node_modules/`, generated assets, junk
- **Wave protocol** — work without structure = no clean commits, no lesson capture

`gngm-init.sh` bootstraps the TOOLS. `gngm-full-scaffold.sh` bootstraps the STRUCTURE.

## Universal — works with ANY project + ANY CLI AI

GNGM's scaffolding convention is intentionally stack-agnostic and CLI-agnostic:

**Any language / stack:** Python, Node, Rust, Go, Java, Kotlin, Swift, C/C++, Ruby, PHP, web, mobile, embedded — the structure is language-neutral. Code lives where idiomatic for that stack (`src/`, `lib/`, `server/`, etc.). The GNGM structure wraps around it.

**Any CLI AI:** project-level instructions file is named by convention per CLI:

| CLI AI | Canonical filename |
|---|---|
| Claude Code | `CLAUDE.md` |
| Codex CLI / Cursor CLI / many others | `AGENTS.md` |
| Gemini CLI | `GEMINI.md` |
| Multi-CLI project | all three (identical content) |

The scaffold script prompts which one(s) to create. They're equivalent — same content, just different filename conventions.

**Any repo state:** scaffold is idempotent — works in empty dirs AND existing repos. Never clobbers existing files.

## The canonical project tree

```
<project>/
├── CLAUDE.md    (or AGENTS.md / GEMINI.md — per CLI convention)
├── MASTER_PLAN.md                (optional — vision + roadmap)
├── README.md                     (public-facing)
├── .gitignore
├── .graphifyignore
├── .env.example                  (template, committed)
├── .env                          (secrets, gitignored)
│
├── docs/
│   ├── INDEX.md                  (master doc index)
│   ├── GNGM/                     (knowledge stack protocols — from install.sh)
│   │   ├── docs/                 (00-INSTALL … 06-WAVE-PROTOCOL)
│   │   ├── protocols/            (14 universal protocols — see GNGM/README.md for the full list grouped by cluster)
│   │   └── scripts/              (gngm-init, gngm-health, gngm-full-scaffold, gngm-update)
│   ├── current/                  (active handoffs — MAX 3 files)
│   │   └── _INDEX.md
│   ├── architecture/             (system design — populated as built)
│   │   └── _INDEX.md
│   ├── reference/                (external APIs, SDKs, legal refs)
│   │   └── _INDEX.md
│   ├── protocols/                (project-specific SOPs)
│   │   └── _INDEX.md
│   ├── waves/                    (per-wave PLAN.md + SUMMARY.md)
│   │   └── _INDEX.md
│   └── history/                  (archived summaries, incident reports)
│       └── _INDEX.md
│
├── lessons/                      (NeuralTree atomic, one .md per domain)
│   ├── _INDEX.md
│   └── <domain>.md               (pre-seeded with frontmatter + format guide)
│
├── .neuraltree/
│   └── wiki/                     (compiled canonical docs)
│       └── _INDEX.md
│
├── graphify-out/                 (gitignored — AST graph JSON)
├── .venv-graphify/               (gitignored — Graphify venv)
│
└── <your code tree>              (src/, server/, app/, lib/, etc. — whatever your stack uses)
```

Plus Claude's auto-memory trunk (separate tree under user's home — **Claude Code only**):

```
~/.claude/projects/<PROJECT-ID>/memory/
├── MEMORY.md                     (<100 lines — trunk INDEX, auto-loaded every session)
├── user/profile.md               (user/collaborator profile)
├── rules/                        (project-specific rules, domain-grouped)
│   └── _INDEX.md
├── active/                       (current wave/phase + blockers)
│   └── _INDEX.md
├── reference/                    (stable factual refs)
│   └── _INDEX.md
└── archive/                      (compressed post-wave summaries)
```

Where `<PROJECT-ID>` is the project path slugified (e.g. `/home/neil/myproject` → `-home-neil-myproject`).

## The hygiene rules (enforced by `gngm-hygiene-check.sh`)

Every `.md` file in the project:
1. Has YAML frontmatter: `name`, `description`, `type`, `last_verified`
2. Has `## Related` section linking to adjacent files
3. Has `## Docs` section linking to external resources

Special file rules:
- `MEMORY.md` ≤ 100 lines (trunk INDEX, never dump content)
- `docs/current/` ≤ 3 files (`SESSION_CONTEXT.md`, `ISSUES_TO_FIX.md`, optional active plan)
- `lessons/<domain>.md` — one per domain, not per fix; lessons formatted with symptom/root-cause/fix/chain

## Adaptation patterns

### "I already have a repo — how does this graft in?"

Run `gngm-full-scaffold.sh` in your existing repo. It will:
1. Detect existing files (CLAUDE.md, .gitignore, etc.) and skip them — no clobber
2. Create only what's missing
3. Add the GNGM tree alongside your code without moving anything
4. Leave your `src/`, `lib/`, whatever-you-have untouched

Result: GNGM layer grafted onto your existing project. Your code is unchanged; GNGM wraps around it.

### "I use Cursor / Codex / Gemini CLI, not Claude Code"

Run scaffold with `--ai-cli cursor` (or `codex` / `gemini`). It creates `AGENTS.md` (or `GEMINI.md`) instead of `CLAUDE.md`. Content is identical — the filename is what differs per CLI convention.

The memory trunk at `~/.claude/projects/<id>/memory/` is Claude Code specific. For other CLIs, either:
- Skip the memory trunk (set `--memory-trunk off`)
- Adapt path for your CLI (e.g., Cursor stores context differently — consult your CLI's docs)

The rest of the structure (docs/, lessons/, .neuraltree/wiki/) is universal and works with every CLI AI.

### "I want multi-CLI project (works with Claude AND Cursor AND Gemini)"

Run scaffold with `--ai-cli all`. Creates `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` — all with identical content. Each CLI picks up its own convention.

### "My project is X language"

The scaffold doesn't care about language. Your code tree sits alongside GNGM's scaffolding:

```
# Python project
<project>/
├── CLAUDE.md
├── src/myapp/  ← your Python code here
├── tests/
├── pyproject.toml
└── docs/ lessons/ .neuraltree/ .graphifyignore  ← GNGM layer
```

```
# Node project
<project>/
├── CLAUDE.md
├── src/  ← your TypeScript code here
├── package.json
└── docs/ lessons/ .neuraltree/ .graphifyignore  ← GNGM layer
```

```
# Rust project
<project>/
├── CLAUDE.md
├── src/
├── Cargo.toml
└── docs/ lessons/ .neuraltree/ .graphifyignore  ← GNGM layer
```

Etc. The `.graphifyignore` template ships with sensible defaults for common stacks — you can extend it for anything exotic.

## Three paths to installation

| Path | What it does | When to use |
|---|---|---|
| `install.sh` | Copies GNGM docs into `<project>/docs/GNGM/` | Minimal — just want the reference docs |
| `gngm-init.sh` | Installs Graphify + hooks + Graphiti seed | Just want the TOOLS (scripts-only bootstrap) |
| **`gngm-full-scaffold.sh`** | Full project scaffolding: memory trunk + CLAUDE.md + docs tree + lessons + config files + tools | **Recommended for new projects — or adding GNGM to existing ones** |

## The power formula

> **GNGM tools + canonical structure + wave protocol + hygiene gate = compound knowledge that survives sessions and scales across projects.**

Each component alone is useful. Together they compound. Skip any component and the others work at 60%.

## Related
- [01-SETUP.md](01-SETUP.md) — prerequisites + installation
- [02-PROTOCOL.md](02-PROTOCOL.md) — GNGM mechanics
- [06-WAVE-PROTOCOL.md](06-WAVE-PROTOCOL.md) — how waves run against this structure
- [04-LESSONS.md](04-LESSONS.md) — pitfalls

## Docs
- `scripts/gngm-full-scaffold.sh` — the scaffolder
- `scripts/gngm-hygiene-check.sh` — validates frontmatter + cross-refs
- `templates/` — all the file templates the scaffolder uses

---
name: {{PROJECT_NAME}} doc index
description: Master doc tree for {{PROJECT_NAME}}. Keep this accurate — add new docs here.
type: doc-index
last_verified: {{DATE}}
---

# {{PROJECT_NAME}} — Documentation Index

## Master artifacts
- `../MASTER_PLAN.md` — vision + waves (if present)
- `../CLAUDE.md` — project-level Claude Code instructions (auto-loaded)
- `../README.md` — public-facing project intro

## Tree

```
docs/
├── INDEX.md (this file)
├── GNGM/                         (knowledge stack — do not modify)
├── current/                      (live handoffs — max 3 files)
├── architecture/                 (system design, populated as built)
├── reference/                    (external APIs, SDKs, legal refs)
├── protocols/                    (project-specific SOPs)
├── waves/                        (per-wave PLAN.md + SUMMARY.md)
└── history/                      (archived summaries, incident reports)
```

## Quick links

- **GNGM cheatsheet:** [GNGM/docs/03-CHEATSHEET.md](GNGM/docs/03-CHEATSHEET.md)
- **Project structure:** [GNGM/docs/05-PROJECT-STRUCTURE.md](GNGM/docs/05-PROJECT-STRUCTURE.md)
- **Wave protocol:** [GNGM/docs/06-WAVE-PROTOCOL.md](GNGM/docs/06-WAVE-PROTOCOL.md)
- **NLF / SDP / TDD:** [GNGM/protocols/](GNGM/protocols/)

## Related
- `../CLAUDE.md`
- `~/.claude/projects/-<project-id>/memory/MEMORY.md`

## Docs
- `../MASTER_PLAN.md` (if present)

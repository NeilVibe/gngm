---
name: {{PROJECT_NAME}} lessons index
description: Atomic lessons organized by domain. 3+ lessons in a domain → wiki compile. Use neuraltree_lesson_add / neuraltree_lesson_match.
type: lesson-index
last_verified: {{DATE}}
---

# Lessons Index

## Conventions
- One lesson file per domain (not per fix)
- Each lesson: `## <short headline> (YYYY-MM-DD)` inside the domain file
- Every lesson includes: symptom, root cause, fix, chain (A→B→C), key_file (path, never None), commit
- Domain accumulates 3+ lessons → queue wiki compile to `.neuraltree/wiki/<domain>.md`
- Use `neuraltree_lesson_add` / `neuraltree_lesson_match` MCP tools

## Planned domains

_(seeded at scaffold time if requested, otherwise added as needed)_

## Related
- `~/.claude/rules/neuraltree-protocol.md` — full tool reference
- `../.neuraltree/wiki/_INDEX.md` — compiled wiki index

## Docs
- `../docs/GNGM/protocols/` — protocols that feed into / consume lessons

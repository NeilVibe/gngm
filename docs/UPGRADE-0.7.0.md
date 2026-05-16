---
name: GNGM 0.7.0 Upgrade Guide
description: How to move an existing GNGM project to release 0.7.0 — the Graphify 0.4.x to 0.8.5 and graphiti-core 0.28.x to 0.29.0 version bumps, the new opt-in tool-upgrade command, and the one-time Graphify graph housekeeping. The artifact to hand to agents managing GNGM-consuming projects.
type: gngm-doc
last_verified: 2026-05-16
---

# GNGM 0.7.0 — Upgrade Guide

GNGM 0.7.0 pins the knowledge-stack tools to current, verified versions and
ships a way for existing projects to pick them up. This guide is for the agent
or developer upgrading a project that already runs GNGM.

## Honest summary — read this first

The two tools did **not** move equally. Communicate this accurately:

- **Graphify 0.4.x → 0.8.5 — a real upgrade.** Genuinely new capability:
  idempotent rebuilds + stable community IDs, headless `extract` with
  free/local backends, cross-repo `global` graphs, `callflow-html` diagrams,
  ~10 more languages. Worth adopting.
- **graphiti-core 0.28.x → 0.29.0 — a maintenance bump.** One minor version:
  security currency, an opt-in combined-extraction path (which GNGM keeps
  *off* on local Qwen), and `summarize_saga`. No new capability GNGM relies on.
  Safe and worth taking — but not a headline.

Do not describe the Graphiti step as a major upgrade. It is housekeeping.

## What 0.7.0 contains

- Tool versions **pinned**: `graphifyy[mcp]==0.8.5`, `graphiti-core[falkordb]==0.29.0`.
- New script **`gngm-upgrade-tools.sh`** — opt-in; rebuilds `.venv-graphify`
  and bumps graphiti-core.
- The vendored Graphiti client **verified and patched** against graphiti-core
  0.29.0 (stale few-shot examples corrected — they would otherwise mis-teach
  the local Qwen extractor).
- `clients/` now **propagates** into consuming projects (`install.sh` and
  `gngm-update.sh` carry it), so the patched client actually reaches you.
- New mastery docs **07-GRAPHIFY-MASTERY.md** and **08-GRAPHITI-MASTERY.md**.

## How to upgrade a project (two steps)

```bash
# 1. Refresh the GNGM docs + scripts + client (non-destructive — touches only docs/GNGM/)
bash docs/GNGM/scripts/gngm-update.sh

# 2. Upgrade the actual tool binaries (opt-in — rebuilds the venv, prompts first)
bash docs/GNGM/scripts/gngm-upgrade-tools.sh
```

Step 1 alone gives you the new *docs* but leaves you on the old tool
*versions*. Step 2 is what actually moves graphifyy and graphiti-core. **Both
steps are needed** — and step 1 must run first, because it is what delivers the
`gngm-upgrade-tools.sh` script that step 2 runs.

## What `gngm-upgrade-tools.sh` does

1. Upgrades `.venv-graphify` to `graphifyy[mcp]==0.8.5`.
2. **One-time graph rebuild.** The 0.4.x→0.8.x jump changes the cache layout
   and the node-ID format. The script clears `graphify-out/cache/`, removes the
   stale `graph.json`, and runs a clean `graphify update .` — AST-only, no LLM
   and no API key required. This regenerates the graph in 0.8.x format and
   clears any ghost-duplicate nodes from the old ID scheme.
3. Bumps the shared `graphiti-core` install to 0.29.0.
4. Refreshes `~/.graphiti/qwen_client.py` from the verified 0.7.0 client,
   backing up the previous version with a timestamp.

It prompts before mutating anything and is idempotent — safe to re-run.

## Expected one-time effects (not bugs)

- **Community IDs renumber once.** The first 0.8.x rebuild reassigns community
  numbers; subsequent rebuilds are stable. Re-sync anything externally keyed on
  old community IDs.
- **graphiti-core is a shared install.** Bumping it in one project affects
  every GNGM project on the machine. 0.29.0 is API-compatible with 0.28.x
  (verified), and the step is idempotent across projects, so this is safe.
- If a project ran *semantic* Graphify extraction (not just AST), re-run
  `graphify extract . --backend ollama` afterward to rebuild semantic edges.

## graphiti-core 0.29.0 — the local-Qwen caveat

0.29.0 rewrote the entity-extraction prompt to be stricter. On a local 9B Qwen
this can make extraction slightly more conservative. Keep
`use_combined_extraction` **off** (the default) — the combined single-call path
emits a larger nested JSON object that small local models handle worse than the
two-call default. The vendored 0.7.0 client is already verified against 0.29.0;
no client changes are needed beyond what `gngm-upgrade-tools.sh` refreshes.

## Verify

```bash
bash docs/GNGM/scripts/gngm-health.sh          # expect all four layers green
.venv-graphify/bin/graphify --version          # expect 0.8.5
```

## Rollback

The upgrade is reversible:

- **Graphify** — `.venv-graphify/bin/pip install 'graphifyy[mcp]==<old-version>'`,
  then `graphify update .`.
- **graphiti-core** — `pip install 'graphiti-core[falkordb]==0.28.2'`.
- **Vendored client** — restore the timestamped `.bak` the upgrade script left
  in `~/.graphiti/`.

## Related

- [07-GRAPHIFY-MASTERY.md](07-GRAPHIFY-MASTERY.md) — using Graphify 0.8.x to full potential
- [08-GRAPHITI-MASTERY.md](08-GRAPHITI-MASTERY.md) — using Graphiti to full potential
- [00-INSTALL-FROM-SCRATCH.md](00-INSTALL-FROM-SCRATCH.md) — fresh-machine install

## Docs

- `scripts/gngm-upgrade-tools.sh` — the opt-in tool-upgrade command
- `scripts/gngm-update.sh` — the docs-only refresh
- [../CHANGELOG.md](../CHANGELOG.md) — full 0.7.0 release notes

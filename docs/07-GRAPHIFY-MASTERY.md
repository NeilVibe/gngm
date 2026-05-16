---
name: Graphify Mastery — Using the Code Graph to Full Potential
description: How to use Graphify (the G2 layer of GNGM) at full power — the verified 0.8.x command grammar, graph-first reasoning, AST extraction, Leiden communities, headless and zero-cost backends, idempotent rebuilds, and cross-repo graphs. States plainly what Graphify is and what it deliberately is not.
type: gngm-doc
last_verified: 2026-05-16
---

# Graphify Mastery

Graphify is the **G₂ layer** of GNGM — the code graph. It answers *structural*
questions that grep cannot: what calls X, what is the path from A to B, what is
the shape of this module, which nodes are load-bearing. This guide is how to
use it to full potential.

> **Pinned version: graphifyy 0.8.5.** Every command below is verified against
> that release. Install: [00-INSTALL-FROM-SCRATCH.md](00-INSTALL-FROM-SCRATCH.md)
> Phase 6. Per-project bootstrap: [01-SETUP.md](01-SETUP.md).

---

## 1. What Graphify is

A **deterministic AST code graph** with community detection. Three passes:

1. **AST extraction** — tree-sitter parses 31 languages (Python, JS/TS, Go,
   Rust, Java, C/C++, Ruby, C#, Kotlin, Bash, JSON, SQL dialects, Astro, …)
   into nodes (functions, classes, files, SQL tables) and edges (calls,
   imports, references). **No LLM. Fast. Fully local.**
2. **Leiden clustering** — the graph is partitioned into communities
   (subsystems) by the Leiden algorithm (`graspologic`, Louvain fallback).
   **Deterministic since v0.7.0** — same code in, same community IDs out.
3. **Semantic pass (optional)** — an LLM extracts concept-level edges from
   docs / PDFs / images. Runs only on `graphify extract`, never on `update`.

Output lands in `graphify-out/`: `graph.json` (the graph, NetworkX
node-link format), `GRAPH_REPORT.md` (human summary), `graph.html`
(interactive view).

## 2. What Graphify is NOT

**Graphify has no vector embeddings and no semantic vector search.** This is a
deliberate design choice, not a missing feature. "Similarity" in Graphify is a
*graph edge* the LLM extracts (`semantically_similar_to`), never a cosine
distance over embeddings. Graphify's own documentation states it directly:
*"the graph structure is the similarity signal — there is no separate
embedding step or vector database."*

That design is exactly *why* Graphify is fast, fully local, and reproducible.
Do not describe it as a "vector", "spectral", or "embedding" tool — it is an
AST + graph-topology tool. Embedding-based semantic search in the GNGM stack is
**Viking's** job, not Graphify's. Keeping these layers distinct is the point of
a four-layer stack.

## 3. Graph-first reasoning — the mental model

The single highest-value habit: **before you grep, query the graph.** The graph
already knows the call structure, the module boundaries, and the load-bearing
nodes. Grep finds strings; the graph finds *structure*.

| You want to know… | Don't | Do |
|---|---|---|
| What calls `process_order`? | grep `process_order` across the repo | `graphify query "what calls process_order"` |
| How do auth and billing connect? | read 8 files guessing | `graphify path "AuthService" "BillingService"` |
| What is this unfamiliar module? | open every file | `graphify explain "PaymentRouter"` |
| What's the blast radius of a change? | hope | `query` the target, read its community + callers |

Reach for the graph **first** in the GNGM pre-task pass. It is a code-aware
lens, and on a large repo it returns a structural answer in ~3s that a manual
sweep would take many file-reads to assemble.

## 4. Command grammar (verified, 0.8.5)

### The five GNGM-core commands

These are the commands the GNGM protocol leans on. All are stable and
backward-compatible with the 0.4.x era.

| Command | Purpose |
|---|---|
| `graphify update .` | Re-extract the AST graph (no LLM). The everyday refresh. |
| `graphify query "<question>"` | BFS the graph to answer a structural question. `--budget N` caps output tokens (default 2000); `--dfs` for depth-first; `--context` to filter edge types. |
| `graphify path "A" "B"` | Shortest path between two nodes. |
| `graphify explain "X"` | Plain-language explanation of a node and its neighbours. |
| `graphify hook install` | Install the git post-commit hook (auto-refresh on every commit). |

### New in 0.8.x — worth adopting

| Command | Why it matters |
|---|---|
| `graphify extract . --backend <b>` | Headless full extraction (AST + semantic) for CI / scripts — no IDE in the loop. |
| `graphify update . --no-cluster` | Skip reclustering; write the raw AST graph only (fast). |
| `graphify cluster-only .` | Re-run Leiden on an existing `graph.json` without re-extracting. |
| `graphify export callflow-html` | Self-contained interactive Mermaid architecture diagram, per community. |
| `graphify export obsidian \| graphml \| neo4j \| svg` | Hand the graph to other tools. |
| `graphify global add <graph.json>` | Register a project in `~/.graphify/global-graph.json` — query many repos as one. |
| `graphify merge-graphs g1 g2` | Merge multiple repo graphs into a cross-repo graph. |
| `graphify watch .` | Rebuild on file change (live). |
| `graphify benchmark graph.json` | Measure the token reduction the graph buys vs a naive corpus dump. |

## 5. The GNGM workflow with Graphify

| GNGM phase | Graphify action |
|---|---|
| **Pre-task** | `query` / `path` / `explain` the entities you are about to touch. Build the mental map *before* reading code. |
| **During work** | `explain` unfamiliar nodes as you reach them. |
| **Post-fix** | Nothing manual — the post-commit hook runs `update` automatically (~10s, AST-only). |
| **Idle / drift** | If you committed a large refactor and the hook was skipped (markdown-only commit), run `graphify update .` once. |

Install the hook on day one (`graphify hook install`, done by `gngm-init.sh`).
A graph that silently goes stale is worse than no graph.

## 6. Backends — `update` vs `extract`

- **`graphify update`** is **AST-only**. No LLM, no API key, no network. This
  is what the hook runs and what you run 99% of the time. It is idempotent
  (see §7).
- **`graphify extract`** adds the **semantic pass** (concept edges from
  docs/PDFs/images) and therefore needs an LLM backend:

| Backend | Cost | Notes |
|---|---|---|
| `--backend ollama` | **Free** | Local inference. Nothing leaves the machine. The default choice for GNGM projects. |
| `--backend claude-cli` | **No API key** | Routes through your installed `claude` CLI — billed to your Claude plan quota, not pay-as-you-go API credit. Forced single-concurrency. |
| `--backend openai \| gemini \| kimi \| bedrock` | Paid API | Faster; requires the relevant key. |

For a pure code graph you never need `extract` — `update` is enough. Use
`extract` only when you want docs/PDFs/media folded into the graph.

## 7. Idempotency — why a committed `graph.json` works

Since **v0.7.18**, `graphify update`:

- **Only rewrites `graph.json` when content actually changed** — an unchanged
  repo produces a true no-op (no spurious git diff).
- **Stable community IDs across rebuilds** — Leiden runs with a fixed seed and
  a greedy overlap remapper, so community numbers (and any labels you hand-edit
  onto them) survive a rebuild.

This is what makes committing `graph.json` to the repo viable: the post-commit
hook refreshes it, and diffs reflect real structural change only. (`graph.json`
and `graphify-out/` are gitignored by the GNGM template by default — commit it
deliberately only if your team wants the shared graph.)

## 8. Reading the graph

`graph.json` is NetworkX node-link format. Each **node**: `id`, `label`,
`file_type`, `source_file`, `source_location`, `community`. Each **edge**:
`source`, `target`, `relation`, `confidence` (`EXTRACTED` / `INFERRED` /
`AMBIGUOUS`), `confidence_score`, `weight`.

- **Communities** = subsystems. Nodes sharing a `community` id form a module
  cluster — a natural unit for "what is the shape of this area".
- **God nodes** = the highest-degree nodes (most-connected). Surfaced in
  `GRAPH_REPORT.md`. A god node is a refactor risk and a good place to start
  understanding a codebase.
- **Surprising connections** = edges that cross communities / file-types /
  languages — often where coupling hides.
- **Confidence tags** — trust `EXTRACTED` (AST-derived) edges fully; treat
  `INFERRED` / `AMBIGUOUS` (LLM-derived semantic edges) as hints.

## 9. Anti-patterns

| Don't | Do |
|---|---|
| grep for structure ("what calls X") | `graphify query` — grep finds strings, the graph finds callers |
| Call Graphify a vector / embedding / spectral tool | It is AST + Leiden. Vectors are Viking's layer. |
| Run `graphify .` (full rebuild) every change | `graphify update .` — incremental, idempotent |
| Skip `hook install` | The hook is what keeps the graph honest; install it day one |
| Let `graph.json` go stale after a big refactor | `graphify update .` once after refactors the hook skipped |
| Reach for `extract` for a code-only question | `update` (AST-only) already answers it — no backend needed |

## Related

- [08-GRAPHITI-MASTERY.md](08-GRAPHITI-MASTERY.md) — the temporal-facts layer (G₁)
- [02-PROTOCOL.md](02-PROTOCOL.md) — the four-mode GNGM protocol Graphify plugs into
- [03-CHEATSHEET.md](03-CHEATSHEET.md) — one-page command reference
- [00-INSTALL-FROM-SCRATCH.md](00-INSTALL-FROM-SCRATCH.md) — Phase 6 installs Graphify
- [06-WAVE-PROTOCOL.md](06-WAVE-PROTOCOL.md) — where Graphify queries sit in the wave lifecycle

## Docs

- `scripts/gngm-init.sh` — bootstraps the `.venv-graphify` venv + installs the hook
- `scripts/gngm-upgrade-tools.sh` — upgrades Graphify to the pinned version
- graphifyy on PyPI — package is `graphifyy` (double-y); the CLI binary is `graphify`
- https://github.com/safishamsi/graphify — upstream source + release notes

---
name: Graphiti Mastery — Using the Temporal Knowledge Graph to Full Potential
description: How to use Graphiti (the G1 layer of GNGM) at full power — the fully-local Qwen + FalkorDB setup, episode discipline, the causal-chain rule, temporal validity windows, correction episodes, sagas, and the honest local-Qwen caveats. Verified against graphiti-core 0.29.0.
type: gngm-doc
last_verified: 2026-05-16
---

# Graphiti Mastery

Graphiti is the **G₁ layer** of GNGM — the temporal knowledge graph. It answers
the questions code cannot: *why did we choose X, when did Y change, who decided
this, what depends on this decision.* This guide is how to use it to full
potential.

> **Pinned version: graphiti-core 0.29.0.** Verified against that release.
> Install: [00-INSTALL-FROM-SCRATCH.md](00-INSTALL-FROM-SCRATCH.md) Phases 1
> and 5. Per-project setup: [01-SETUP.md](01-SETUP.md).

---

## 1. What Graphiti is

A **temporal knowledge graph**. You feed it *episodes* (prose accounts of what
happened); it extracts entities and relationships, and stores each fact with a
**validity window** — when the fact became true, and when it stopped being
true. Facts are never destructively overwritten; superseded facts are
*invalidated*, not deleted. You can query what is true now, or what was true at
any past point.

This is the layer that turns a sequence of work sessions into institutional
memory. Code tells you *what* the system does; Graphiti tells you *why it is
that way* and *how it got there.*

## 2. The GNGM setup — fully local, zero API cost

GNGM runs Graphiti with no cloud dependency and no API key:

| Piece | GNGM choice | Why |
|---|---|---|
| Graph DB | **FalkorDB** (Docker, port 6379) | Fast, local, Redis-based |
| Extraction LLM | **Qwen 3.5 9B** via Ollama | Local, free, no key |
| Embeddings | **Model2Vec** (potion-multilingual-128M) | Local, ~29k sentences/sec |
| Client | vendored `~/.graphiti/qwen_client.py` | Adapts graphiti-core to local Qwen |

graphiti-core itself "works best" with cloud structured-output models
(OpenAI/Gemini). GNGM deliberately trades a little extraction polish for a
**fully local, free, private** stack. The vendored client is what bridges the
gap — see §8.

Entry point:

```python
import sys; sys.path.insert(0, f'{__import__("os").path.expanduser("~")}/.graphiti')
from qwen_client import create_qwen_graphiti

g = await create_qwen_graphiti(graph_name='<your-project>')
```

`graph_name` defaults to the project directory's basename — every project gets
its own isolated graph automatically.

## 3. Facts-first reasoning — the mental model

Before re-deriving *why* something is the way it is, **ask the graph.** The
answer to "why is the scoring weight 80?" or "did we try approach X before?"
is an episode someone already wrote — not something to reconstruct from a git
blame and a guess.

| You want to know… | Ask Graphiti |
|---|---|
| Why was this decision made? | `search("why did we choose <approach>")` |
| What depends on this component? | `search("what depends on <component>")` |
| What changed here recently? | `search("recent changes to <component>")` |
| Have we hit this before? | `search("past issues with <component>")` |

## 4. Core operations

### Search (the pre-task move)

```python
results = await g.search('what depends on the auth middleware',
                          group_ids=['<your-project>'])   # NOTE: plural here
for r in results[:5]:
    print(r.fact)
```

Search is **hybrid** — semantic embeddings + BM25 keyword + graph traversal,
fused. **No LLM call at query time**, so it is fast (~5s). Use 2–3 specific
entity names in the query; single generic words ("bug", "auth") return noise.

### Add an episode (the post-work move)

```python
from datetime import datetime, timezone

await g.add_episode(
    name='phase-12-cascade-rewrite',
    episode_body="""...""",
    source_description='Phase 12 completion handoff',
    reference_time=datetime.now(timezone.utc),
    group_id='<your-project>',                            # NOTE: singular here
)
```

> **Footgun:** `search` takes `group_ids=[...]` (plural list); `add_episode`
> takes `group_id='...'` (singular string). Mixing them up silently scopes the
> call wrong.

## 5. Episode discipline — the causal chain

The quality of what Graphiti can later retrieve is set entirely by the quality
of the episode bodies you write. One rule above all:

**Every episode body must contain an explicit `Connects:` chain.** That line is
how the LLM extractor knows which entities to create and how to link them.

```
What changed and why — in plain prose.
Files touched: server/auth/middleware.py, server/auth/session.py.
Connects: AuthMiddleware → SessionStore → Redis → token-expiry check.
Why: session lookups were O(n); the new path is O(1) via the Redis index.
```

Checklist for a good episode body:

- **Name specific entities and files** — they become graph nodes.
- **Include the `Connects: A → B → C` chain** — it becomes graph edges.
- **State the WHY** — the rationale is the fact most worth keeping.
- Keep it under ~5000 tokens — longer bodies cause partial extraction.

A one-line episode with no causal chain is nearly worthless. Don't bother
feeding the graph unless you feed it a chain.

## 6. Temporal facts — validity windows and corrections

Graphiti is **bi-temporal**: every fact carries an event-time window
(`valid_at` / `invalid_at`) and an ingestion time (`created_at`). When a new
episode contradicts an old fact, the old one is *invalidated* — preserved, not
erased. Recent facts outrank old ones automatically.

**Graphiti is append-only — you cannot delete a fact.** To correct stale
information, write a new episode that explicitly supersedes it:

```
CORRECTION: Earlier facts about <X> are OBSOLETE as of commit <sha>.
The behaviour is now <Y>.
Supersedes: facts dated before <YYYY-MM-DD> referencing <old approach>.
```

The explicit "Supersedes:" wording gives the temporal layer a strong signal to
down-weight the old facts. Always write a correction episode after a refactor
that invalidates how the graph describes the code.

## 7. Sagas — narrative threads

A **saga** groups related episodes into one narrative (a debugging session, a
multi-phase feature). Tag episodes with `saga='<name>'`; in graphiti-core
0.29.0, `g.summarize_saga(saga_id)` rolls the thread into a single summary
node. Use sagas for work that unfolds across many episodes and you will later
want to reconstruct as one story.

## 8. The local-Qwen reality (read before you trust the graph)

GNGM extracts with a local 9B model. That has honest consequences:

- **Cold load.** The first `add_episode` after the model is evicted from VRAM
  takes 30–60s while Qwen loads. The vendored client retries once — do not
  panic on the first timeout.
- **The vendored client salvages Qwen's quirks.** Qwen 3.5 returns malformed
  structured output more often than cloud models (wrong wrapper keys, prose
  instead of JSON, naked arrays). `qwen_client.py` has a multi-stage salvage
  pipeline for exactly this. **Do not modify it** unless you understand
  `_salvage_qwen_json` / `_normalize_item` / `_salvage_prose`.
- **Keep `use_combined_extraction` OFF.** graphiti-core 0.29.0 added an opt-in
  single-call combined node+edge extraction. It emits a larger nested JSON
  object — harder for a 9B local model than two smaller calls. The default is
  off; on local Qwen, leave it off.
- **VRAM hygiene.** Qwen 9B is ~6.6 GB. The vendored client caps `keep_alive`
  at 60s and exposes `unload_qwen()` to reclaim VRAM immediately after a run.
  Never long-pin the model — see [../protocols/VRAM-HYGIENE.md](../protocols/VRAM-HYGIENE.md).

```python
from qwen_client import create_qwen_graphiti, unload_qwen
try:
    g = await create_qwen_graphiti(graph_name='<your-project>')
    await g.add_episode(...)
finally:
    await unload_qwen()   # reclaim VRAM for other GPU workloads
```

After extraction, **verify** — search for an entity you just mentioned. If it
comes back empty, the LLM missed it; re-add the episode with a clearer body.

## 9. When to feed Graphiti

Add an episode when any of these happen — not on every commit (episodes are for
meaningful change, not noise):

| Event | Episode name pattern |
|---|---|
| Phase / wave completed | `phase-N-<desc>` |
| Architecture decision made | `arch-decision-<name>` |
| Non-trivial bug fixed | `fix-<component>-<symptom>` |
| Refactor that invalidates old facts | `correction-<topic>-<date>` |
| Research / exploration concluded | `exploration-<topic>-<date>` |

## 10. Anti-patterns

| Don't | Do |
|---|---|
| `add_episode` with no `Connects:` chain | Always include the causal chain — it is the extraction signal |
| Single-word search queries (`"bug"`) | 2–3 specific entity names |
| Forget `group_ids` on search | Always scope — an unscoped query spans every project's graph |
| Try to delete a wrong fact | Write a `correction-…` episode that supersedes it |
| One episode per commit | Episodes are for meaningful change, not noise |
| Enable `use_combined_extraction` on the 9B | Leave it off — the combined JSON is harder for small local models |
| Long-pin Qwen in VRAM to "stay warm" | `unload_qwen()` after work; see VRAM-HYGIENE |
| Trust extraction blindly | Verify — search for an entity you just fed in |

## Related

- [07-GRAPHIFY-MASTERY.md](07-GRAPHIFY-MASTERY.md) — the code-graph layer (G₂)
- [02-PROTOCOL.md](02-PROTOCOL.md) — the four-mode GNGM protocol Graphiti plugs into
- [03-CHEATSHEET.md](03-CHEATSHEET.md) — one-page command reference
- [04-LESSONS.md](04-LESSONS.md) — pitfalls, including Qwen structured-output quirks
- [../protocols/VRAM-HYGIENE.md](../protocols/VRAM-HYGIENE.md) — never long-pin the model

## Docs

- `clients/graphiti/qwen_client.py` — the vendored Qwen + FalkorDB client
- `clients/graphiti/feed_project.py` — project seeding helper
- `scripts/gngm-upgrade-tools.sh` — upgrades graphiti-core to the pinned version
- https://github.com/getzep/graphiti — upstream source + release notes

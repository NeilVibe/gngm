# GNGM Cheatsheet — Quick Reference

Pin this tab. One-page reference for the full protocol.

## Four tools

```
G₁  Graphiti    why/when/who    FalkorDB @ :6379
N   NeuralTree  lessons + wikis lessons/, .neuraltree/wiki/
G₂  Graphify    what-calls-what graphify-out/graph.json
M   MemoryMCP   cross-session   mcp__memory__*
```

## Trigger phrases (say any in chat)

```
GNGM                   — full stack, Claude judges mode from context
GNGM pre-task          — parallel search before work
GNGM post-fix          — feed all 4 after shipping
GNGM cleanup           — org pass (saturation + compile + orphans)
GNGM health            — 10s services check
full GNGM              — pre-task → work → post-fix → org
```

## Pre-task (parallel, single message)

```python
# All 4 in parallel
g.search("<2-3 entity names>", group_ids=['newfin'])
neuraltree_lesson_match(symptoms=[error, component, mode])
viking_search(query="<topic>")
memory.search_nodes(query="<topic>")

# Structural (after)
graphify query "what calls <ENTITY>"
```

**Topic granularity:** 2-3 specific entity names. Never `"bug"` / `"auth"` alone.

## Post-fix (sequence)

```python
# 1. Lesson
neuraltree_lesson_add(domain="<existing>", lesson={
    "symptom": "...", "root_cause": "...", "fix": "...",
    "chain": "A → B → C", "key_file": "path.py",
    "lesson": "general principle", "commit": "<sha>"
})

# 2. Compile if domain crossed 3 lessons & no wiki
if count >= 3 and not wiki_exists:
    neuraltree_compile(topic=..., content="<claude-written>", sources=[...])
    neuraltree_viking_index(file_paths=[".neuraltree/wiki/<topic>.md"])

# 3. Episode (Connects chain REQUIRED)
await g.add_episode(
    name='verb-target-date', episode_body='... Connects: A → B → C ...',
    source_description='...', reference_time=datetime.now(timezone.utc),
    group_id='newfin',
)

# 4. Durable rule (if any)
memory.create_entities([{...}]) / add_observations([{...}]) / create_relations([{...}])
```

Graphify auto-refreshes via post-commit hook. No manual call needed.

## Organizational checklist

```
□ Saturation heatmap (15-20 topics × search, count facts)
□ Compile queue (domains ≥3 lessons w/o wiki → compile)
□ neuraltree_scan(summary_only=True) + score + find_dead + wiki_lint
□ Orphan classification (KEEP / CONSOLIDATE / ARCHIVE — never delete)
□ Graphiti backfill sparse topics + correction episodes
□ graphify benchmark (target ≥10×) + cluster-only (monthly)
□ MEMORY.md ≤100 lines, ## Related + ## Docs on every leaf
```

## Health check (10s)

```bash
bash docs/GNGM/scripts/gngm-health.sh
```

Or manual:

```bash
docker ps --filter name=falkordb | grep Up               # 🟢 Graphiti DB
ollama list | grep qwen3.5:9b                           # 🟢 Graphiti LLM
curl -s http://localhost:1933/health | grep -q ok       # 🟢 Viking
[ -f graphify-out/graph.json ] && echo ok               # 🟢 Graphify
# MemoryMCP: try mcp__memory__read_graph; should return
```

## Tool recipes

### Graphiti search shapes

```python
g.search("X Y Z", group_ids=['newfin'])                           # basic
g.search("perf", group_ids=['newfin'], center_node_uuid='<uuid>') # anchored
g.search("X", group_ids=['newfin'], num_results=50)               # deeper
```

### Graphiti search patterns

```
"What connects to <COMPONENT>?"
"What depends on <COMPONENT>?"
"recent changes to <X>"
"past bugs in <X>"
"why did we choose <approach>"
```

### NeuralTree surgery

```python
neuraltree_trace(target="path/to/file.py")       # inbound + outbound refs
neuraltree_wire(file_path="path/to/file.py")     # auto-suggest ## Related
neuraltree_plan_move(source="a.py", destination="b.py")  # dry-run
neuraltree_sandbox_create(use_git_worktree=True)         # safe trial
```

### Graphify queries

```bash
graphify query "what calls X"
graphify path "A" "B"
graphify explain "X"
graphify update .           # AST re-extract (hook auto-runs)
graphify cluster-only .     # re-Leiden (monthly)
graphify benchmark <graph>  # token reduction check
graphify save-result --question "Q" --answer "A" --type query --nodes "N"
```

### Memory MCP

```python
memory.search_nodes(query="topic")
memory.open_nodes(names=["entity_name"])
memory.read_graph()
memory.create_entities([{name, entityType, observations}])
memory.add_observations([{entityName, contents}])
memory.create_relations([{from, to, relationType}])
```

## Failure modes (quick ref)

| Symptom | Fix |
|---|---|
| Qwen 180s timeout | Retry built in; GPU reload is ~30-60s cold |
| "No such tool available" for MCP | You killed server mid-session; commit patch, restart |
| `row[str]` TypeError | Use `row._mapping[key]` (SQLAlchemy Row) |
| `add_episode` 0 entities | Qwen bad JSON; salvage pipeline retries once |
| Graphify query wrong | Query code entities, not topic phrases |
| Viking miss on clear topic | `neuraltree_diagnose` classifies gap type |
| Heredoc + `&` silent fail | Use `run_in_background: true` or temp file |

## Topic granularity examples (newfin)

| Bad | Good |
|---|---|
| `"scoring"` | `"phase 32 weights top2 ext=10 int=80"` |
| `"Discord"` | `"send_top50_to_discord color zones"` |
| `"valuation"` | `"z-score WICS sector cache threshold"` |
| `"bug"` | `"autorsi_unified insider_window 180d"` |
| `"cache"` | `"build_comprehensive_cache WICS 6Q"` |

## Context hygiene

- Parallel > sequential for independent queries
- `summary_only=True` on scan / lint (saves tokens)
- Write to `/tmp/*.py` + background for long `add_episode` calls
- Verify after background — don't trust exit 0

## When NOT to GNGM

- Trivial rename / single-line typo
- Pure conversation / exploration
- User says "skip GNGM" or "just do X"
- Emergency hotfix (run post-fix only, skip pre-task)

## Engineering protocols (layer on top of GNGM)

- **[../protocols/NLF.md](../protocols/NLF.md)** — No Lie Fix. Self-invoke on drift toward comment-out / disable / catch-and-ignore. User trigger: `NLF`.
- **[../protocols/SDP.md](../protocols/SDP.md)** — Standard Development Protocol (baseline for all code changes). 5 steps: Brainstorm → ECC Plan Review → Execute → TDD Certificate → ECC Code Review.
- **[../protocols/TDD.md](../protocols/TDD.md)** — TDD baseline + First-Debug Protocol (6-step heavy variant for production bug fixes from logs).

## See also

- [02-PROTOCOL.md](02-PROTOCOL.md) — full mechanics
- [04-LESSONS.md](04-LESSONS.md) — 9 pitfalls
- [01-SETUP.md](01-SETUP.md) — prerequisites
- [00-INSTALL-FROM-SCRATCH.md](00-INSTALL-FROM-SCRATCH.md) — full install guide

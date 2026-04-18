# GNGM Protocol — Full Mechanics

This is the canonical protocol. When you or Claude say "GNGM" in a chat, this is what fires.

## The four tools

| Letter | Tool | Source of truth | Cost |
|--------|------|-----------------|------|
| **G**₁ | **Graphiti** | LLM-extracted prose facts (Qwen 3.5 9B via FalkorDB) | ~5s search / ~30s `add_episode` |
| **N** | **NeuralTree** | Curated atomic lessons → distilled wikis | Free |
| **G**₂ | **Graphify** | AST + Leiden topology code graph | ~10s update / ~3s query |
| **M** | **MemoryMCP** | Cross-session entity graph + project rules + auto-memory trunk | Free |

## Four modes

### Mode 1 — Pre-task (search before doing)

Before investigating any task, run all 4 queries IN PARALLEL (single-message multi-tool call). Never sequential — parallel is the point.

```
[single message with 4 tool calls]
1. g.search("<2-3 specific entities>", group_ids=['newfin'])   # Graphiti
2. neuraltree_lesson_match(symptoms=[<error>, <component>, <mode>])  # NeuralTree
3. viking_search(query="<specific topic>")                      # Viking (sister tool)
4. memory.search_nodes(query="<topic>")                         # MemoryMCP
```

Then:

```
5. graphify query "what calls <ENTITY>"   # Graphify (structural)
   # OR: graphify explain "<ENTITY>"
   # OR: graphify path "<A>" "<B>"
```

**After all 5 → read code files.** Reading before GNGM = blind work.

**Topic granularity rule:** 2-3 specific entity names beats one generic phrase.

| Bad | Good |
|---|---|
| `"scoring"` | `"autorsi_unified phase 32 weights"` |
| `"valuation"` | `"z-score WICS sector_cache threshold"` |
| `"the bug"` | `"insider_window 180d Top2 hold 3month"` |

### Mode 2 — Post-fix (feed what you learned)

After any meaningful change (anything >5 lines + touches stateful system):

**Step 1 — NeuralTree lesson_add**

```python
neuraltree_lesson_add(
    domain="<existing preferred>",
    lesson={
        "symptom": "<observable failure>",          # REQUIRED
        "root_cause": "<the bug>",                  # REQUIRED
        "fix": "<what you did>",                    # REQUIRED
        "chain": "A → B → C → symptom",             # high-value
        "key_file": "<path or placeholder string>", # REQUIRED (string, never None)
        "lesson": "<general principle>",
        "commit": "<sha>"
    }
)
```

If the domain just crossed 3 lessons AND has no wiki yet, queue compile:

```python
# Claude synthesizes the wiki body from the N lessons
neuraltree_compile(
    topic="<domain>",
    content="<frontmatter + body + Sources + Related>",
    sources=[f"lessons/<domain>.md"]
)

# Then index in Viking for retrieval
neuraltree_viking_index(file_paths=[".neuraltree/wiki/<domain>.md"])
```

**Step 2 — Graphiti add_episode**

```python
await g.add_episode(
    name='<verb-target-date>',
    episode_body="""
What changed and why.
Files touched: a.py, b.py.
Connects: ComponentA → ComponentB → ComponentC.
""",
    source_description='<context>',
    reference_time=datetime.now(timezone.utc),
    group_id='newfin',
)
```

**Rules:**

- Always include `Connects: A → B → C` — that's how the LLM extracts entity edges
- Name specific files — they become nodes
- State WHY — rationale becomes retrievable facts
- For non-blocking writes: write to `/tmp/episode.py` + run in background. Verify via search later.
- Never combine heredoc + `&` — silent failure trap

**Step 3 — Graphify (automatic if hook installed)**

The post-commit hook runs `graphify update .` automatically. If you want to see the refresh before committing:

```bash
graphify update .       # incremental AST-only, ~10s
```

Save high-value Q&A for feedback:

```bash
graphify save-result --question "<Q>" --answer "<A>" --type query --nodes "<N1>" "<N2>"
```

**Step 4 — MemoryMCP writes (for durable cross-session facts)**

```python
# New entity
mcp__memory__create_entities(entities=[{
    "name": "<entity>",
    "entityType": "<type>",
    "observations": ["<fact>"]
}])

# Add to existing entity
mcp__memory__add_observations(observations=[{
    "entityName": "<existing>",
    "contents": ["<new fact>"]
}])

# Create relations
mcp__memory__create_relations(relations=[{
    "from": "<A>", "to": "<B>", "relationType": "<verb>"
}])
```

If the fact is a project-specific behavioral rule, write it to `memory/rules/*.md` instead — update `rules/_INDEX.md` + `MEMORY.md` trunk.

### Mode 3 — Organizational (cleanup, audit, health)

Run this periodically (weekly-ish, or when user says "GNGM cleanup").

**Step 1 — Saturation check (NEW in v2)**

```bash
# Diversity heatmap — search 15-20 key topics, count facts per topic
python3 <<'PY'
import asyncio, sys
sys.path.insert(0, '/home/neil1988/.graphiti')
from qwen_client import create_qwen_graphiti

TOPICS = [
    "<20 key project topics here>"
    # e.g. for newfin: "autorsi unified scoring", "phase 32 weights",
    # "z-score valuation", "WICS sector cache", "Discord integration",
    # "MA manual analysis", "external ranking", "backtest results", ...
]

async def m():
    g = await create_qwen_graphiti(graph_name='newfin')
    for t in TOPICS:
        r = await g.search(t, group_ids=['newfin'])
        flag = "🔴" if len(r) == 0 else ("🟡" if len(r) < 3 else "🟢")
        print(f"  {flag} {len(r):3d}  {t}")

asyncio.run(m())
PY
```

- **All 🟢 (≥3 facts)** = SATURATED → stop feeding, switch to consumption
- **Any 🔴 (0 facts)** = silent topic → backfill with `add_episode`
- **Any 🟡 (1-2)** = weak → add more episodes or lessons

**Step 2 — Compile-queue audit (NEW in v2)**

```bash
# Find compile-ready domains without wikis
cd /home/neil1988/newfin
for f in lessons/*.md; do
  name=$(basename "$f" .md); [ "$name" = "_INDEX" ] && continue
  n=$(grep -c '^## ' "$f" 2>/dev/null)
  [ "$n" -ge 3 ] && [ ! -f ".neuraltree/wiki/$name.md" ] \
    && echo "QUEUE COMPILE: $name ($n lessons)"
done
```

For each queued domain: Claude reads the lessons, synthesizes a wiki body (frontmatter + distilled body + Sources + Related), calls `neuraltree_compile()`, then `neuraltree_viking_index()`.

**Step 3 — NeuralTree health**

```python
mcp__neuraltree__neuraltree_scan(summary_only=True, exclude_patterns=[".planning","docs/archive"])
mcp__neuraltree__neuraltree_score()
mcp__neuraltree__neuraltree_find_dead()
mcp__neuraltree__neuraltree_wiki_lint(max_age_days=30, summary_only=True)
mcp__neuraltree__neuraltree_diagnose(failed_queries=[...])   # if any Viking misses this week
```

**Thresholds:**

| Metric | Healthy | Action if not |
|---|---|---|
| Flow score | ≥0.70 | Run Tier 4 surgery (trace / wire / sandbox) |
| Connectivity | ≥0.90 | Wire up orphans with `neuraltree_wire` |
| Dead ratio | stable | If climbing: `shrink_and_wire` archive bloat |

**Step 4 — Orphan wiki classification (NEW in v2)**

Never delete orphan wikis — they're consumed via Viking semantic search, not markdown links. Classify instead:

| Bucket | Action |
|---|---|
| **KEEP** (standalone meta-knowledge) | Leave alone |
| **CONSOLIDATE** (duplicate of newer wiki) | Add supersede banner at top |
| **ARCHIVE** (phase-specific historical) | Optionally move to `archive/` subfolder |

Authority: `investigate_before_delete.md` principle.

**Step 5 — Graphiti corrections + graph hygiene**

Backfill sparse topics with `add_episode`. For superseded facts, issue correction episode (Graphiti is append-only):

```python
await g.add_episode(
    name='correction-<topic>-<date>',
    episode_body='CORRECTION: facts about <X> before <date> are OBSOLETE. New behavior: <Y>. Supersedes: <pre-date X facts>.',
    source_description='Graphiti correction',
    reference_time=datetime.now(timezone.utc),
    group_id='newfin',
)
```

**Step 6 — Graphify drift check**

```bash
graphify benchmark graphify-out/graph.json   # target ≥10× token reduction
# If below: check .graphifyignore, consider graphify . rebuild

graphify cluster-only .   # monthly: re-Leiden after code drift
```

**Step 7 — MemoryMCP audit**

- `MEMORY.md` trunk ≤100 lines? (trunk is index, not dump)
- Every leaf has `## Related` + `## Docs`?
- `last_verified` bumped on edited files?
- Stale rules removed?

### Mode 4 — Health (10-second status)

```bash
bash docs/GNGM/scripts/gngm-health.sh
```

Equivalent manual:

```bash
docker ps --filter name=falkordb | grep -q Up || docker start falkordb
ollama list 2>/dev/null | grep -q "qwen3.5:9b"
curl -sS http://localhost:1933/health | grep -q ok
[ -f graphify-out/graph.json ] && echo "OK" || echo "MISSING"
```

All green → go. Any red → fix before work.

## Integration with SESSION workflow

### Session start (~30s)

```
1. gngm-health.sh       — are services up?
2. Read MEMORY.md       — auto-loaded, rules top-of-mind
3. Read active/_INDEX   — current phase / blockers
4. Glance docs/current/ — active handoffs
5. git status           — uncommitted work
```

### Every task (~5s decision)

Tier the task:

- **FAST:** typo / rename / single-line → skip GNGM
- **NORMAL:** multi-file or stateful → GNGM pre-task (parallel)
- **FULL:** cross-subsystem / contracts / phases → GNGM pre-task + post-fix

Upgrade tier mid-task if scope grows. Never downgrade.

### After meaningful work (~30-60s)

GNGM post-fix. Feed all 4 layers (or accept degradation if a tool is down).

### Weekly (~10min)

GNGM organizational pass. Catch drift before it compounds.

### Monthly (~30min)

Full compile cadence — synthesize new wikis, re-Leiden cluster, regenerate indices.

## Degraded modes

| Service down | GNGM becomes | Action |
|---|---|---|
| FalkorDB | NGM (skip Graphiti) | `docker start falkordb` |
| Ollama/Qwen | Graphiti search works; add_episode retries | `systemctl --user restart ollama` |
| Graphify graph missing | GNM | `graphify .` to build once |
| MemoryMCP | Rely on auto-loaded MEMORY.md | Restart Claude Code session |
| All four down | Hard stop — escalate | Should never happen |

Never skip ALL four tools. If ≥1 is responsive, run what's available.

## Signal for next session (meta-episode)

After any GNGM pass, feed Graphiti a meta-episode so next session knows what was touched:

```python
await g.add_episode(
    name=f'gngm-pass-{YYYY-MM-DD}',
    episode_body="GNGM <mode> ran. NeuralTree: N lessons, K wikis. Graphiti: M episodes. Graphify: update. MemoryMCP: J entities. Findings: ...",
    source_description=f'GNGM {mode} meta',
    reference_time=datetime.now(timezone.utc),
    group_id='newfin',
)
```

Skip if trivial. Include if patterns / rules / architecture shifted.

## Anti-patterns (DON'T)

| Anti-pattern | Why bad | Correct |
|---|---|---|
| Generic topic like `"auth"` or `"bug"` | Returns noise, hides answer | 2-3 specific entity names |
| Read files before GNGM | Blind work | GNGM first, then read right files |
| Skip post-fix because "it's just one line" | Pattern recurs, lesson lost | Quick lesson_add still valuable |
| Delete orphan wikis | Removes searchable knowledge | Classify KEEP/CONSOLIDATE/ARCHIVE |
| `lesson_add` with `key_file=None` | Validation error | Use `"(process lesson)"` placeholder |
| Kill MCP server mid-session | Tool disappears for session | Commit patch, defer to next session |
| Heredoc + `&` for background work | Silent failure with exit 0 | Use `run_in_background: true` or temp file |
| Search sequentially (G→N→V→M) | 4× slower | Parallel in one message |
| Compile a wiki without writing content | Tool doesn't auto-distill | Claude must synthesize body |
| Forget `group_ids=['newfin']` on search | Spans all projects | Always pass (PLURAL on search) |

## Why GNGM vs individual tool names

The four tools overlap BY DESIGN. Overlap lets:

- Corroboration catch LLM extraction failures (Graphiti)
- Drift detection against structural reality (Graphify)
- Lesson deduplication (NeuralTree)
- Stale rule detection (Memory MCP)

**Using one tool alone = blind spot.** GNGM forces the four-way pass.

## See also

- [03-CHEATSHEET.md](03-CHEATSHEET.md) — one-page quick reference
- [04-LESSONS.md](04-LESSONS.md) — 8 pitfalls + resilience patterns
- [scripts/gngm-health.sh](scripts/gngm-health.sh) — 10-second health check

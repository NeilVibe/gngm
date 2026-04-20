# GNGM Lessons — Pitfalls + Resilience Patterns

Ten production failure modes surfaced while building and operating GNGM across related projects (LocalizationTools, newfin, vrsmanager). Read once, internalize — they apply universally.

## 1. Saturation signal — stop feeding when 20/20 topics return 9-10 facts

**Symptom:** after months of feeding, every `g.search()` returns the full `num_results=10` cap. Adding more episodes has diminishing returns.

**How to detect:** run the saturation heatmap (see `02-PROTOCOL.md` §Mode 3 Step 1). If all 15-20 key topics return ≥9 facts, the graph is SATURATED.

**What to do:** switch from FEED discipline to CONSUME discipline. Every new task must query all 4 layers BEFORE investigating. The ROI is in retrieval, not addition.

**Operating rule:** once saturated, compile wikis (synthesis) and install automation (hooks). Don't add more episodes for the sake of adding.

## 2. Heredoc + `&` silent failure

**Symptom:** `python3 << 'PY' ... PY 2>&1 &` exits 0 but the python script NEVER runs. `add_episode` call, file write, DB insert — none happen. Bash returns 0 because backgrounding succeeded; silent failure is invisible.

**Root cause:** shell parses `&` as backgrounding the `python3` process BEFORE feeding it the heredoc on stdin. Detached python gets EOF, exits cleanly.

**Fix — three correct patterns:**

```bash
# A. Use Bash's run_in_background parameter (cleanest)
# B. Write to temp file, then background
cat > /tmp/script.py << 'PY'
...python code...
PY
python3 /tmp/script.py &

# C. Just run foreground (no &)
python3 << 'PY'
...
PY
```

**Verification rule:** ALWAYS verify background work landed via follow-up search:

```python
r = await g.search("episode name keyword", group_ids=['newfin'])
assert any("expected fact" in f.fact for f in r), "Didn't land — retry"
```

## 3. MCP server restart hazard

**Symptom:** patched an MCP tool, killed the process to "reload", every MCP tool from that server disconnects for the session.

**Root cause:** Claude Code spawns MCP servers as child processes at session start and binds stdin/stdout ONCE. Kill = drop pipe permanently. No auto-respawn, no rediscovery.

**Operating rule:** NEVER kill an MCP server mid-session. For patches:

```
1. Write the patch
2. python3 -c "from <module> import <tool>"   # verify imports
3. git commit in the MCP server's repo
4. Note in handoff: "effective next session"
5. Continue current session with workarounds (neighbor tools, bash client, file writes)
6. Next session: first tool call respawns with new code
```

**Source-patch is a git concept; tool-reload is a session concept. Never mix them mid-session.**

## 4. Two-clone MCP hazard (affects neuraltree specifically)

**Symptom:** patched the MCP tool source and committed. Tool still crashes with the pre-patch error. Debugging reveals TWO git clones on disk.

**Root cause:** auto-updater clones to one path (`~/.neuraltree-src/`), active runtime uses a different path via PYTHONPATH (`~/.neuraltree/` or `~/neuraltree/`). Patches to the wrong clone are invisible.

**Fix — verify PYTHONPATH before editing:**

```bash
python3 -c "
import json
d = json.load(open('/home/neil1988/.claude/settings.json'))
print('NeuralTree PYTHONPATH:', d['mcpServers']['neuraltree']['env']['PYTHONPATH'])
"
```

Port patches to the active clone. Commit from that git root.

## 5. Qwen Ollama timeout / GPU reload

**Symptom:** `Error in generating LLM response: Ollama did not respond within 180s. GPU may be overloaded. Model: qwen3.5:9b`

**Root cause:** GPU memory pressure OR cold model load. Qwen 9B needs ~8 GB VRAM. On first call after eviction, Ollama reloads the model (30-60s), blocking the request.

**Behavior:** `qwen_client.py` has a built-in 2-retry loop. First call may hit timeout; second usually succeeds after GPU warm-up.

**Operating rules:**

- For non-blocking episodes: write to `/tmp/*.py` + run in background. Verify with search later.
- If persistent (hours): `systemctl --user restart ollama` or `ollama serve`.
- For small prompts: consider `qwen3.5:4b` fallback (3.4 GB VRAM).
- Never retry the same call synchronously — let the background retry loop do its work.

## 6. Path.relative_to() on external paths

**Symptom:** wiki_lint, trace, or any tool that walks markdown links crashes with `ValueError: "<external-path>" is not in the subpath of "<project-root>"`.

**Root cause:** `pathlib.Path.relative_to(root)` raises on paths outside `root`. Common when wikis link to cross-project rules (`~/.claude/rules/*.md`). Unhandled exception crashes the whole tool.

**Fix pattern:**

```python
def _safe_relative_to(path, root):
    try:
        return path.relative_to(root)
    except ValueError:
        return None

# Caller
rel = _safe_relative_to(resolved, root)
if rel is None:
    continue  # skip external paths gracefully
```

External paths are out of scope for project-local tools anyway. Skip, don't crash.

## 7. Orphan wikis ≠ dead wikis

**Symptom:** `find_dead` reports 56% of knowledge files as "dead". Instinct: delete them.

**Root cause:** "dead" in link-graph terms means "nothing LINKS to it". But wikis are consumed via Viking semantic search, NOT markdown traversal. Deleting them removes searchable knowledge.

**Rule from `investigate_before_delete.md`:**

1. How is this file consumed? If Viking / framework / programmatic → NOT dead
2. Classify by origin: project-created (cleanup-safe), plugin-installed (never clean), framework-generated (never clean)
3. "Low cross-ref density" is a WIRING problem, not a deletion problem. Fix `## Related` / `## Docs`; don't delete

**Orphan wiki classification (three buckets):**

| Bucket | Action |
|---|---|
| **KEEP** (standalone meta-knowledge) | Leave alone |
| **CONSOLIDATE** (duplicate of newer canonical) | Add supersede banner at top |
| **ARCHIVE** (phase-specific historical) | Optionally move to `archive/` subfolder |

Never delete. Append-only correction pattern beats destructive edit.

## 8. Parasitic knowledge (DEFINITIVE docs that lie)

**Symptom:** a doc labelled DEFINITIVE contradicts a stated architectural principle. Earlier session wrote it. Current session reads it, reasons forward assuming it's correct, perpetuates the wrong pattern.

**Root cause:** docs drift from principles when:

1. Code compromises a principle
2. Session X documents current state as "definitive"
3. Session Y reads the doc, reasons forward assuming correctness
4. Session Y writes a handoff reinforcing the wrong pattern
5. Compound confusion across sessions

**Operating rules:**

1. When a DEFINITIVE doc contradicts a stated principle, the DOC is wrong. Trust the principle; clean the doc.
2. Internal contradictions in a single doc = signal of drift. Ask the user for the principle; never silently pick one side.
3. **Phase D (knowledge cleanup) ships with every phase.** Never deferred. Stale knowledge compounds across sessions.

## 9 (bonus) — ECC recommendations need verification

**Symptom:** an ECC subagent recommends a fix with HIGH confidence. You apply it. Production breaks.

**Root cause:** ECC agents (code-reviewer, silent-failure-hunter, etc.) recommend architectural fixes with confidence but cannot verify feasibility. A HIGH recommendation is not a guarantee the fix is valid Python / JS / etc.

**Example (from LocalizationTools, commit e0cd405f → 15683bba):** silent-failure-hunter recommended `initializer=_mark_worker_daemon` for ThreadPoolExecutor. The recommendation was architecturally IMPOSSIBLE — Python's `threading.Thread.daemon` setter raises `RuntimeError` on already-started threads. Every submitted future raised `BrokenThreadPool`. Fix: commit 15683bba removed the initializer.

**Operating rule:** for any ECC-recommended fix touching concurrency, threading, async primitives, lifecycle hooks, or framework internals — **run the exact test that exercises the modified code path locally BEFORE committing**, even when ECC declares convergence. **Reviewer-satisfied ≠ test-green.**

**Signal to watch for:** "subtle", "cross-cutting", "defense-in-depth", "robustness" framing from a reviewer + zero explicit test case to validate. Those adjectives correlate strongly with unverified recommendations.

## 10. Qwen edge extraction fails silently on long episodes — use atomic fact episodes

**Symptom:** `g.add_episode(...)` returns successfully. `FalkorDB GRAPH.QUERY` shows the Episodic node exists and even has a few Entity nodes attached via MENTIONS edges. But `g.search(query, group_ids=[...])` returns 0 facts for every query, even queries that exactly match entity names. Search stays broken across all topics.

**How to detect — direct FalkorDB inspection:**

```bash
# Episodes present?
docker exec falkordb redis-cli GRAPH.QUERY <graph> "MATCH (n:Episodic) RETURN count(n)"

# Entities present?
docker exec falkordb redis-cli GRAPH.QUERY <graph> "MATCH (n:Entity) RETURN count(n)"

# The key metric — RELATES_TO edges (what search returns):
docker exec falkordb redis-cli GRAPH.QUERY <graph> "MATCH ()-[r:RELATES_TO]->() RETURN count(r)"

# If Entity count > 0 but RELATES_TO count == 0 → this bug.
```

**Root cause:** `graphiti_core` does entity extraction and relationship extraction as separate LLM calls. Qwen 3.5 9B is **reliable at entity extraction** even on long multi-paragraph bodies — but the **relationship extraction prompt more frequently returns non-JSON, truncated JSON, or references entities that weren't recognised in the first pass**, which the client silently drops. Long narrative episodes (multi-paragraph, code-block-heavy, "Connects: A → B → C" footers) exhibit this. Short sentences with one explicit verb per fact don't.

The `qwen_client.py` salvage pipeline has retry logic for entity extraction but edge-extraction failures do not raise loudly — you just get zero RELATES_TO edges, which reads as "search broken" downstream.

**Fix — write atomic fact episodes for anything you need to retrieve via search:**

```python
# BAD — one mega-episode (entities extract, relations mostly don't):
await g.add_episode(
    name='session-summary',
    episode_body="""
    Three pages of narrative about the ISSUE-008 fix, the new logging
    infrastructure, the CI versioning migration... Connects: A → B → C.
    Connects: D → E. Connects: F → G → H.
    """,
    ...
)

# GOOD — 10–20 atomic fact episodes (both entities AND relations extract):
FACTS = [
    ('perf-fact-1', 'The ISSUE-008 block had an O(n-squared) performance bug.'),
    ('perf-fact-2', 'consumer_by_prev_idx replaces the linear scan with O(1) dict lookup.'),
    ('perf-fact-3', 'process_working_comparison contains the ISSUE-008 fix block.'),
    # ... one clean subject-verb-object sentence per episode
]
for name, body in FACTS:
    await g.add_episode(name=name, episode_body=body, ...)
```

**Observed threshold (Qwen 3.5 9B):** bodies under ~50 words with one or two explicit relational verbs extract reliably. Bodies over ~200 words extract entities but usually drop all edges.

**Verification rule — always check RELATES_TO count after any batch of episodes:**

```python
await g.add_episode(...)  # repeat N times
# then:
import subprocess
out = subprocess.check_output([
    'docker', 'exec', 'falkordb', 'redis-cli',
    'GRAPH.QUERY', GRAPH_NAME,
    "MATCH ()-[r:RELATES_TO]->() RETURN count(r)"
]).decode()
# Expect count to grow by ~1-3 edges per atomic episode. If it doesn't, edges failed.
```

**Meta-pattern match:** this is another instance of "surface-level success ≠ actual side effect" (see Meta-theme). The `add_episode()` call returns cleanly; only a post-hoc graph state check reveals the missing edges.

**Operating rule:** for any important knowledge that future sessions need to retrieve via `g.search()`, write it as **atomic fact episodes**. A narrative handoff doc (human-readable) and an atomic-fact feed (graph-retrievable) are two different artefacts — don't try to serve both from one episode.

**Source:** discovered while running the full GNGM pipeline on the vrsmanager project (2026-04-21). Two large narrative episodes (session summary + architecture backfill) produced 8 entities but zero edges; 18 atomic fact episodes immediately after produced 22 entities and 12 edges, restoring search.

## Meta-theme

Seven of the ten pitfalls share a theme: **something succeeded at the surface level (exit 0, HIGH confidence, "all green") but the actual side effect didn't happen.**

- Heredoc+`&` exits 0 but python didn't run
- ECC approves but code is impossible
- Killed MCP reloads in theory but actually breaks
- Patch commits to wrong clone
- `find_dead` flags orphans but they're alive via Viking
- Qwen returns 200 but salvage hasn't run yet
- `add_episode` returns OK but no RELATES_TO edges → search stays broken

**Defensive protocol:** for any operation you care about, verify the side effect independently. Don't trust exit codes. State-check the intended outcome, not the process that was supposed to produce it.

## Cross-references

These lessons are captured in the LocalizationTools knowledge graph. If those wikis become accessible in newfin (they're project-scoped), query:

- NeuralTree: `neuraltree_lesson_match(symptoms=["silent failure", "exit 0", "mcp restart"])`
- Graphiti: `g.search("MCP restart hazard two-clone PYTHONPATH")` on LocalizationTools graph

Or consult the LocalizationTools files directly:

- `/home/neil1988/LocalizationTools/.neuraltree/wiki/mcp-tooling.md`
- `/home/neil1988/LocalizationTools/.neuraltree/wiki/process-hygiene.md`
- `/home/neil1988/LocalizationTools/.neuraltree/wiki/graphiti-extraction.md`
- `/home/neil1988/LocalizationTools/.neuraltree/wiki/architecture.md`
- `/home/neil1988/LocalizationTools/memory/rules/feedback_no_lie_fixes.md` — NLF rule
- `/home/neil1988/LocalizationTools/memory/rules/verify_ecc_recommendations.md` — verification rule
- `/home/neil1988/LocalizationTools/memory/rules/mcp_server_restart_hazard.md` — MCP cold-start rule

## What about newfin-specific lessons?

This file starts empty of newfin-specific lessons. As you work:

1. Every non-trivial fix → `neuraltree_lesson_add(domain="<newfin domain>", ...)`
2. Every architecture decision → `g.add_episode(group_id='newfin', ...)`
3. Every cross-session rule → `memory/rules/<rule>.md` + update `MEMORY.md`
4. Domain crosses 3 lessons → `neuraltree_compile(topic, content, sources)`

The package grows organically. No gold-plating.

## See also

- [02-PROTOCOL.md](02-PROTOCOL.md) — the full protocol
- [03-CHEATSHEET.md](03-CHEATSHEET.md) — one-page reference
- [01-SETUP.md](01-SETUP.md) — prerequisites

---
name: GNGM Setup — Prerequisites + Installation
description: Sets up the four services (FalkorDB, Ollama+Qwen, Viking, NeuralTree MCP) + Memory MCP wiring for a fresh machine. Skip most if already set up for another project; jump to per-project bootstrap at bottom. Lighter alternative to 00-INSTALL-FROM-SCRATCH.md.
type: gngm-doc
last_verified: 2026-04-27
---

# GNGM Setup — Prerequisites + Installation

This document covers setting up the four services + MCP integrations for a fresh machine. If your machine has already been set up for another project (e.g. LocalizationTools), you can skip most of this and go straight to the per-project bootstrap section at the bottom.

## Service prerequisites

### 1. FalkorDB (Graphiti backend)

```bash
# Install (Docker required)
docker run -d --name falkordb -p 6379:6379 falkordb/falkordb:edge

# Verify
docker ps --filter name=falkordb --format '{{.Status}}'
# Expected: "Up X minutes"

# If already installed, just make sure it's running
docker start falkordb 2>/dev/null || true
```

### 2. Ollama + Qwen 3.5 9B (Graphiti LLM)

```bash
# Install Ollama (per platform — see https://ollama.com)
# Pull the model
ollama pull qwen3.5:9b

# Also pull the smaller fallback (useful when GPU is loaded)
ollama pull qwen3.5:4b

# Verify
ollama list | grep qwen3.5
# Expected: qwen3.5:9b + qwen3.5:4b
```

**GPU note:** Qwen 9B needs ~8 GB VRAM. On cold start, first `add_episode` can take 30-60s. That's normal. The Python client has a 2-retry loop for transient timeouts.

### 3. Graphiti Python client

Located at `~/.graphiti/qwen_client.py`. Includes multi-stage salvage pipeline for Qwen structured-output quirks (wrong wrapper keys, prose responses, naked arrays). DO NOT modify unless you understand the `_salvage_qwen_json` + `_normalize_item` + `_salvage_prose` functions.

Dependencies:

```bash
pip install graphiti-core falkordb-client aiohttp
```

Quick test:

```bash
python3 -c "
import asyncio, sys
sys.path.insert(0, '/home/neil1988/.graphiti')
from qwen_client import create_qwen_graphiti

async def m():
    g = await create_qwen_graphiti(graph_name='newfin')
    r = await g.search('test', group_ids=['newfin'])
    print(f'Graphiti OK: {len(r)} results')

asyncio.run(m())
"
```

### 4. Graphify

```bash
# Install (note: double-y in PyPI, single y in CLI)
pip install "graphifyy[mcp]"

# Verify CLI exists
which graphify
# Expected: ~/.local/bin/graphify or similar

# Initial skill registration (lightweight — just registers /graphify slash command)
graphify install --platform claude
# Do NOT run `graphify claude install` — that's the heavier integration; skip until proven valuable
```

### 5. NeuralTree MCP server

Lives at `/home/neil1988/neuraltree/` (active runtime — SSH remote). Also `/home/neil1988/.neuraltree-src/` exists (HTTPS remote, auto-updater) — DO NOT edit that one.

Verify PYTHONPATH in your Claude Code settings:

```bash
python3 -c "
import json
d = json.load(open('/home/neil1988/.claude/settings.json'))
print('NeuralTree PYTHONPATH:', d['mcpServers']['neuraltree']['env']['PYTHONPATH'])
"
# Should print: /home/neil1988/neuraltree/src
```

26 tools total. Restart Claude Code session once after install to pick up.

### 6. OpenViking (semantic search)

```bash
# Should be pre-installed at ~/.openviking
ls ~/.openviking

# Start service
~/.openviking/start_viking.sh

# Verify
curl -sS http://localhost:1933/health
# Expected: {"status":"ok","healthy":true,...}
```

### 7. Memory MCP

Pre-configured. Verify via Claude Code — the `mcp__memory__*` tools should be available. Nothing to install.

## Per-project bootstrap (newfin specifically)

Once all services are green:

### Step A — Set the graph name

Every project uses its own Graphiti graph name. For newfin:

```bash
# Graph name = "newfin" (used in all add_episode / search calls)
# Nothing to install — FalkorDB creates graphs on first write
python3 -c "
import asyncio, sys
sys.path.insert(0, '/home/neil1988/.graphiti')
from qwen_client import create_qwen_graphiti
async def m():
    g = await create_qwen_graphiti(graph_name='newfin')
    r = await g.search('project newfin', group_ids=['newfin'])
    print(f'newfin graph: {len(r)} facts (0 is fine if graph is empty)')
asyncio.run(m())
"
```

### Step B — Install Graphify hook (CRITICAL)

```bash
cd /home/neil1988/newfin
graphify hook install
```

This appends post-commit + post-checkout hooks to `.git/hooks/`. Every commit auto-refreshes `graphify-out/graph.json` (~10s AST-only, no LLM). **Install early, not late.**

### Step C — Initial Graphify build

```bash
cd /home/neil1988/newfin

# First full build (runs Pass 1 AST + Pass 2 Leiden clustering; skip Pass 3 for now)
graphify update .

# Verify
ls -la graphify-out/graph.json
stat -c '%y %s bytes' graphify-out/graph.json
```

Per-subsystem builds (cheaper for PRE-TASK queries):

```bash
graphify update src/scoring
graphify query "what calls autorsi_unified" --graph src/scoring/graphify-out/graph.json
```

### Step D — Create lessons + wiki directories

```bash
cd /home/neil1988/newfin
mkdir -p lessons .neuraltree/wiki
touch lessons/_INDEX.md .neuraltree/wiki/_INDEX.md
```

Lesson file template (see [04-LESSONS.md](04-LESSONS.md) for full format):

```markdown
---
name: <Domain> Lessons
description: Past <domain> issues
type: reference
last_verified: 2026-04-18
---

## <Symptom headline> (<date>)
- **Symptom:** ...
- **Root cause:** ...
- **Chain:** A → B → C → symptom
- **Fix:** ...
- **Key file:** `path/to/file.py`
- **Lesson:** General principle
- **Commit:** <sha>

## Related
- [sibling-domain.md](sibling-domain.md)

## Docs
- `path/to/file.py` — implementation target
```

### Step E — Initialize memory branches (optional, for deep projects)

Newfin already has a `.claude/` directory with agents / commands / rules. Verify the Claude Code auto-memory structure:

```bash
ls /home/neil1988/.claude/projects/-home-neil1988-newfin/memory/ 2>/dev/null || echo "Memory not initialized yet — will auto-create on first session"
```

First time Claude Code runs in newfin, it creates the memory structure. Standard layout:

```
memory/
├── MEMORY.md          # Trunk (<100 lines index)
├── user/profile.md
├── rules/             # Behavioral rules (e.g. gngm_protocol.md)
├── active/            # Current phase / blockers
├── reference/         # Stable facts
└── archive/           # Compressed history
```

### Step F — Run health check

```bash
bash docs/GNGM/scripts/gngm-health.sh
```

Expected output: 4x 🟢 OK. If any 🔴, fix before doing GNGM work.

## Troubleshooting

### "Ollama did not respond within 180s. GPU may be overloaded."

First call to Qwen after model eviction triggers a cold reload (30-60s). The Graphiti client has a 2-retry loop — second attempt usually succeeds. If persistent:

```bash
systemctl --user restart ollama
# OR
ollama serve
```

### "No such tool available" for MCP tools

MCP servers are cold-start. You killed a server mid-session and Claude Code didn't reconnect. Commit any MCP patches and restart your session. NEVER kill MCP processes while Claude Code is running.

### Graphify graph stale (code moved, queries point to old nodes)

Hook should prevent this, but if you committed big refactors elsewhere:

```bash
graphify update .   # incremental AST refresh
# OR
graphify .          # full rebuild (heavy, only for monthly drift)
```

### Viking returns 0 results for expected topic

```bash
# Re-index recently changed files
mcp__neuraltree__neuraltree_viking_index(file_paths=[".neuraltree/wiki/<topic>.md"])
```

Or diagnose with `neuraltree_diagnose(failed_queries=[{"text":"query","expected_topic":"hint"}])`.

## What to do next

1. Read [02-PROTOCOL.md](02-PROTOCOL.md) — the full protocol
2. Skim [04-LESSONS.md](04-LESSONS.md) — 8 pitfalls surfaced in LocalizationTools
3. Start working — Claude invokes GNGM on trigger phrases automatically

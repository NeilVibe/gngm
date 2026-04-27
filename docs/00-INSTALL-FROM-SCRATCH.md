---
name: GNGM Install from Scratch — Full Pipeline (8 phases)
description: Comprehensive installation guide for setting up the complete GNGM knowledge stack on a fresh machine — Docker, Ollama, Qwen 3.5 9B, FalkorDB, Viking, NeuralTree MCP, Memory MCP, Graphiti client, Graphify venv, Claude Code wiring. Everything is open-source. Designed for end-to-end execution by Claude Code or a human.
type: gngm-doc
last_verified: 2026-04-27
---

# Install from scratch — full GNGM pipeline

Comprehensive installation guide for setting up the complete GNGM stack on a fresh machine. Everything is open-source. The guide is designed so that Claude Code (or a human) can execute it end-to-end.

**Estimated time:** 30-60 minutes on a fresh machine (Ollama model pull is the longest step).

## Contents

- [Phase 0 — System prerequisites](#phase-0--system-prerequisites)
- [Phase 1 — Graphiti layer (FalkorDB + Ollama + Qwen)](#phase-1--graphiti-layer-falkordb--ollama--qwen)
- [Phase 2 — Viking (semantic search)](#phase-2--viking-semantic-search)
- [Phase 3 — NeuralTree MCP server](#phase-3--neuraltree-mcp-server)
- [Phase 4 — Memory MCP server](#phase-4--memory-mcp-server)
- [Phase 5 — Graphiti Python client](#phase-5--graphiti-python-client)
- [Phase 6 — Graphify (per project)](#phase-6--graphify-per-project)
- [Phase 7 — Claude Code MCP wiring](#phase-7--claude-code-mcp-wiring)
- [Phase 8 — First project bootstrap](#phase-8--first-project-bootstrap)
- [Full automated install (optional)](#full-automated-install-optional)
- [Troubleshooting](#troubleshooting)

---

## Phase 0 — System prerequisites

### Required

| Tool | Version | Purpose |
|---|---|---|
| **Docker** | 20.10+ | Runs FalkorDB |
| **Python** | 3.10+ | Graphiti client, Graphify, NeuralTree MCP, Viking |
| **Node.js** | 18+ | Memory MCP (official @modelcontextprotocol/server-memory) |
| **Git** | any | Repo cloning |
| **Claude Code** | latest | The agent that consumes GNGM |

### Linux (Ubuntu/Debian)

```bash
# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER        # log out + back in after this

# Python 3.11 (recommended — matches NeuralTree MCP runtime)
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3-pip git curl

# Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### macOS

```bash
# Homebrew prereq
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Then
brew install docker python@3.11 node git
# Start Docker Desktop manually (macOS requires the GUI for Docker)
```

### WSL2 (Windows)

Same as Linux (Ubuntu). Ensure Docker Desktop has WSL2 integration enabled in its Settings → Resources → WSL Integration.

### Verify prerequisites

```bash
docker --version      # >= 20.10
python3 --version     # >= 3.10
node --version        # >= 18
git --version
```

---

## Phase 1 — Graphiti layer (FalkorDB + Ollama + Qwen)

Graphiti stores the LLM-extracted prose facts. Needs a graph DB (FalkorDB, Redis-based) + an LLM for entity extraction (Qwen via Ollama).

### 1a. FalkorDB (Docker container)

```bash
# Run FalkorDB — persists in a named volume
docker run -d \
    --name falkordb \
    --restart unless-stopped \
    -p 6379:6379 \
    -v falkordb_data:/data \
    falkordb/falkordb:edge

# Verify
docker ps --filter name=falkordb --format '{{.Status}}'
# Expected: Up X seconds
```

Troubleshooting:

- **Port 6379 in use** — another Redis running? `sudo lsof -i :6379`. Stop the conflicting service or change the port.
- **Container exits immediately** — `docker logs falkordb` shows why.

### 1b. Ollama

```bash
# Linux / WSL2 — official install script
curl -fsSL https://ollama.com/install.sh | sh

# macOS — via homebrew
brew install ollama
brew services start ollama       # or: ollama serve &
```

Verify:

```bash
curl -s http://localhost:11434/api/tags | head -c 100
# Expected: JSON like {"models":[...]}
```

### 1c. Pull Qwen 3.5 9B

```bash
# Primary model — main Graphiti extractor (~6.6 GB download)
ollama pull qwen3.5:9b

# Optional smaller fallback for low-VRAM situations (~3.4 GB)
ollama pull qwen3.5:4b

# Verify
ollama list | grep qwen3.5
# Expected: qwen3.5:9b ... (and optionally :4b)
```

**GPU note:** Qwen 9B needs ~8 GB VRAM. On cold start, the first request loads the model (30-60s). The Graphiti client has retry logic for this — don't panic on the first timeout.

---

## Phase 2 — Viking (semantic search)

Viking provides fast semantic search over project documentation using Model2Vec embeddings (256-dim, multilingual).

```bash
# Clone and install Viking
cd ~
git clone https://github.com/NeilVibe/viking.git .openviking   # repo URL per latest
cd ~/.openviking
pip install -e .

# Start Viking (runs on port 1933)
bash ~/.openviking/start_viking.sh

# Verify
curl -s http://localhost:1933/health
# Expected: {"status":"ok","healthy":true,"version":"0.3.5",...}
```

**Note:** The Viking repo URL may vary — check the NeilVibe GitHub organization for current location, or replace with your chosen semantic-search backend. The MCP tool names (`mcp__openviking__*`) assume the openviking-compatible API.

### Auto-start Viking on boot

Linux with systemd:

```bash
# Create user service
cat > ~/.config/systemd/user/viking.service <<'EOF'
[Unit]
Description=Viking semantic search
After=network.target

[Service]
ExecStart=/home/%u/.openviking/start_viking.sh
Restart=on-failure

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now viking.service
```

---

## Phase 3 — NeuralTree MCP server

NeuralTree provides 26 tools for lesson management, wiki compilation, knowledge-map surgery, etc. It's an MCP server that Claude Code spawns as a child process.

```bash
cd ~
git clone https://github.com/NeilVibe/neuraltree.git
cd ~/neuraltree

# Install deps
pip install -e .

# Verify the MCP server module imports
python3.11 -c "from neuraltree_mcp.server import main; print('OK')"
```

The MCP server is registered in `~/.claude/settings.json` (see Phase 7). Claude Code auto-spawns it on session start.

---

## Phase 4 — Memory MCP server

Official @modelcontextprotocol/server-memory — provides the cross-session entity graph.

```bash
# Install globally via npm (uses Node.js from Phase 0)
npm install -g @modelcontextprotocol/server-memory

# Verify
which mcp-server-memory
# Expected: /usr/local/bin/mcp-server-memory or similar
```

Also registered in `~/.claude/settings.json` (Phase 7).

---

## Phase 5 — Graphiti Python client

GNGM vendors a custom Qwen-friendly Graphiti client with a 4-stage salvage pipeline (wrapper remap / item normalize / prose extract / content-preserving retry) for robust entity extraction.

```bash
# Create directory and copy vendored client from this gngm repo
mkdir -p ~/.graphiti
cp /path/to/gngm/clients/graphiti/qwen_client.py ~/.graphiti/
cp /path/to/gngm/clients/graphiti/feed_project.py ~/.graphiti/

# Install dependencies (system pip is fine, small set)
pip install graphiti-core falkordb-client aiohttp httpx

# Smoke test
python3 -c "
import asyncio, sys
sys.path.insert(0, '/home/$USER/.graphiti')
from qwen_client import create_qwen_graphiti

async def m():
    g = await create_qwen_graphiti(graph_name='test_install')
    r = await g.search('test', group_ids=['test_install'])
    print(f'Graphiti OK: {len(r)} results (0 is fine if graph is empty)')

asyncio.run(m())
"
```

**Why the custom client?** Qwen's structured-output behavior is inconsistent (wrong wrapper keys, prose responses, naked arrays, `format=json` empty responses). The vendored client has salvage logic for all four patterns plus a content-preserving retry. See `docs/04-LESSONS.md` Lesson #7 for the full story.

---

## Phase 6 — Graphify (per project)

Graphify is installed per-project in a venv. The `gngm-init.sh` script handles this automatically:

```bash
# In the project root
python3 -m venv .venv-graphify
.venv-graphify/bin/pip install "graphifyy[mcp]"

# Install the post-commit hook (auto-refresh graph on every commit)
.venv-graphify/bin/graphify hook install

# Initial build
.venv-graphify/bin/graphify update .
```

**Why per-project venv?** Keeps Graphify isolated from the project's own Python environment and allows different projects to pin different versions.

**PyPI trap:** the package is `graphifyy` (double-y), NOT `graphify`. The installed CLI binary is still named `graphify`. See Lesson #4.

---

## Phase 7 — Claude Code MCP wiring

Edit `~/.claude/settings.json` to register the MCP servers. Create the file if it doesn't exist.

```json
{
  "mcpServers": {
    "neuraltree": {
      "command": "python3.11",
      "args": ["-m", "neuraltree_mcp.server"],
      "env": {
        "PYTHONPATH": "/home/YOUR_USERNAME/neuraltree/src"
      }
    },
    "memory": {
      "command": "mcp-server-memory",
      "args": []
    },
    "openviking": {
      "command": "python3.11",
      "args": ["-m", "openviking_mcp.server"],
      "env": {
        "VIKING_URL": "http://localhost:1933"
      }
    }
  }
}
```

Replace `YOUR_USERNAME` with your system user name.

**Verify:** Start Claude Code in any project. The MCP tools `mcp__neuraltree__*`, `mcp__memory__*`, `mcp__openviking__*` should be available in the first turn.

**⚠️ CRITICAL:** NEVER kill an MCP server mid-session — Claude Code does NOT auto-respawn. If you patch an MCP server's source code, commit the patch but defer reload to the NEXT Claude Code session. See Lesson #3.

---

## Phase 8 — First project bootstrap

With all services running, bootstrap GNGM in any project:

```bash
# Option A — one-line installer (clones gngm + copies into target project)
curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/install.sh | bash -s -- /path/to/your/project
cd /path/to/your/project
bash docs/GNGM/scripts/gngm-init.sh

# Option B — manual clone + copy
git clone https://github.com/NeilVibe/gngm.git ~/gngm
cd /path/to/your/project
mkdir -p docs/GNGM
cp -r ~/gngm/docs ~/gngm/scripts docs/GNGM/
bash docs/GNGM/scripts/gngm-init.sh
```

The bootstrap creates `lessons/`, `.neuraltree/wiki/`, installs Graphify venv + hooks, runs initial AST build, seeds Graphiti. Idempotent — safe to re-run.

After bootstrap, run health check:

```bash
bash docs/GNGM/scripts/gngm-health.sh
```

Expected: **8/8 OK** (all four layers green).

Then start Claude Code in that project and say `GNGM health` to trigger the protocol. If health is green, say `GNGM` before any work.

---

## Full automated install (optional)

A convenience script that does Phases 1-5 in one shot. Review it before running — it makes system-wide changes.

```bash
# Run from the gngm repo root
bash scripts/install-services.sh
```

The script is idempotent. It skips steps where artifacts already exist (FalkorDB container, Qwen model, Viking clone, etc.).

---

## Troubleshooting

### "Ollama did not respond within 180s"

GPU reloading the model. First call after eviction takes 30-60s. Built-in retry loop (2 retries) usually resolves. Persistent issue:

```bash
systemctl --user restart ollama     # Linux with systemd
# OR
pkill -f ollama && ollama serve &   # manual restart
```

Lower VRAM? Use `qwen3.5:4b` fallback by editing `qwen_client.py` or pulling the smaller model.

### FalkorDB connection refused

```bash
docker ps --filter name=falkordb --format '{{.Status}}'
# If not running:
docker start falkordb
# If missing:
docker run -d --name falkordb -p 6379:6379 falkordb/falkordb:edge
```

### "No such tool available" for MCP tools

You killed an MCP server mid-session. Claude Code does NOT auto-reconnect. Fix:

1. Commit any source patches
2. Quit the Claude Code session
3. Start a new session
4. MCP servers re-spawn fresh

See Lesson #3.

### `graphify` CLI not found

Project venv not activated. Either use the full path (`.venv-graphify/bin/graphify`) or activate the venv (`source .venv-graphify/bin/activate`). Or re-run `gngm-init.sh` to rebuild the venv.

### Graphify post-commit hook doesn't trigger rebuild

The hook skips when no code files changed. Markdown-only commits don't trigger a rebuild — that's by design. To force a rebuild:

```bash
.venv-graphify/bin/graphify update .
```

### Viking returns 0 results for clear topic

```bash
# Re-index the file
mcp__neuraltree__neuraltree_viking_index(file_paths=["path/to/doc.md"])
```

Or diagnose the gap:

```bash
mcp__neuraltree__neuraltree_diagnose(failed_queries=[{"text":"query","expected_topic":"hint"}])
```

### Memory MCP `create_entities` rejects valid input

Known bug in Claude Code's MCP param serialization. Array-of-objects gets stringified. Workaround: use `add_observations` on an existing entity. See Lesson #2.

### Ports in use (6379, 1933, 11434)

```bash
# Find what's using the port
sudo lsof -i :6379        # FalkorDB
sudo lsof -i :1933        # Viking
sudo lsof -i :11434       # Ollama

# Kill the offending process, or remap the GNGM service to a different port
```

---

## Verification checklist

After all phases complete, in a project directory:

```bash
bash docs/GNGM/scripts/gngm-health.sh
```

Should report:

```
[1/4] Graphiti
  🟢 OK   FalkorDB container running
  🟢 OK   Ollama qwen3.5:9b available

[2/4] NeuralTree
  🟢 OK   NeuralTree PYTHONPATH: /home/USER/neuraltree/src
  🟢 OK   lessons/ + .neuraltree/wiki/ present

[3/4] Graphify
  🟢 OK   graphify CLI at .venv-graphify/bin/graphify (project venv)
  🟢 OK   graph.json present
  🟢 OK   post-commit hook installed

[4/4] Viking
  🟢 OK   Viking responding

GNGM FULL POWER — all tools green
```

If all 8 checks pass, you're done. Start saying `GNGM` in Claude Code.

---

## Related

- [01-SETUP.md](01-SETUP.md) — prerequisites + minimal setup variant
- [02-PROTOCOL.md](02-PROTOCOL.md) — full protocol mechanics once installed
- [03-CHEATSHEET.md](03-CHEATSHEET.md) — quick reference during work
- [04-LESSONS.md](04-LESSONS.md) — 9 pitfalls + resilience patterns
- [05-PROJECT-STRUCTURE.md](05-PROJECT-STRUCTURE.md) — canonical project tree

## Docs

- [../CHANGELOG.md](../CHANGELOG.md) — version history
- [../README.md](../README.md) — repo overview + 14-protocol catalog
- [../scripts/gngm-init.sh](../scripts/gngm-init.sh) — minimal alternative to this guide
- [../scripts/gngm-update.sh](../scripts/gngm-update.sh) — non-destructive refresh once installed

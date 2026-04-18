#!/usr/bin/env bash
# GNGM services installer — one-shot install of all services
#
# Idempotent. Safe to re-run. Skips steps where artifacts already exist.
#
# Covers:
#   1. FalkorDB (Docker container)
#   2. Ollama + qwen3.5:9b model
#   3. NeuralTree MCP server (git clone + pip install)
#   4. Memory MCP server (npm global)
#   5. Graphiti Python client (vendored from this repo)
#
# Does NOT cover (per-project, run gngm-init.sh later):
#   - Graphify venv + hook install
#   - Project lesson / wiki dir creation
#   - Graphiti seed episode for project graph
#
# Usage:
#   bash scripts/install-services.sh

set -eu

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

say_ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
say_warn() { echo -e "  ${YELLOW}—${RESET} $1"; }
say_err()  { echo -e "  ${RED}✗${RESET} $1"; }

echo "=== GNGM services installer ==="
echo "Source repo: $REPO_DIR"
echo ""

# Platform detection
if [ "$(uname)" = "Darwin" ]; then
    PLATFORM="macos"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM="wsl2"
else
    PLATFORM="linux"
fi
echo "Platform: $PLATFORM"
echo ""

# Prereq checks
echo "[0/5] Checking prerequisites..."
for cmd in docker python3 node git curl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        say_ok "$cmd: $(command -v "$cmd")"
    else
        say_err "$cmd: NOT FOUND — install it first (see docs/00-INSTALL-FROM-SCRATCH.md Phase 0)"
        exit 1
    fi
done

PY_VERSION=$(python3 --version | awk '{print $2}')
NODE_VERSION=$(node --version | sed 's/v//')
echo "  Python: $PY_VERSION"
echo "  Node:   $NODE_VERSION"
echo ""

# 1. FalkorDB
echo "[1/5] FalkorDB (Docker)..."
if docker ps --filter name=falkordb --format '{{.Status}}' 2>/dev/null | grep -q Up; then
    say_warn "FalkorDB container already running"
elif docker ps -a --filter name=falkordb --format '{{.Names}}' 2>/dev/null | grep -q falkordb; then
    docker start falkordb >/dev/null 2>&1
    say_ok "FalkorDB container started"
else
    docker run -d \
        --name falkordb \
        --restart unless-stopped \
        -p 6379:6379 \
        -v falkordb_data:/data \
        falkordb/falkordb:edge >/dev/null
    say_ok "FalkorDB container created and started"
fi
echo ""

# 2. Ollama + Qwen 3.5 9B
echo "[2/5] Ollama + qwen3.5:9b..."
if command -v ollama >/dev/null 2>&1; then
    say_warn "Ollama already installed: $(ollama --version | head -1)"
else
    if [ "$PLATFORM" = "macos" ]; then
        brew install ollama
        brew services start ollama
    else
        curl -fsSL https://ollama.com/install.sh | sh
    fi
    say_ok "Ollama installed"
fi

# Wait for ollama service to be up
for i in 1 2 3 4 5; do
    if curl -sS -m 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
        break
    fi
    echo "  Waiting for ollama service..."
    sleep 2
done

if ollama list 2>/dev/null | grep -q "qwen3.5:9b"; then
    say_warn "qwen3.5:9b already pulled"
else
    echo "  Pulling qwen3.5:9b (~6.6 GB — will take several minutes)..."
    ollama pull qwen3.5:9b
    say_ok "qwen3.5:9b pulled"
fi
echo ""

# 3. NeuralTree MCP server
echo "[3/5] NeuralTree MCP server..."
if [ -d "$HOME/neuraltree" ]; then
    say_warn "NeuralTree already cloned at $HOME/neuraltree — pulling latest"
    cd "$HOME/neuraltree" && git pull --ff-only 2>&1 | tail -1
else
    git clone https://github.com/NeilVibe/neuraltree.git "$HOME/neuraltree" 2>&1 | tail -2
    say_ok "NeuralTree cloned to $HOME/neuraltree"
fi

cd "$HOME/neuraltree"
if pip show neuraltree-mcp >/dev/null 2>&1; then
    say_warn "neuraltree-mcp already installed"
else
    pip install -e . >/dev/null
    say_ok "neuraltree-mcp installed in editable mode"
fi
cd - >/dev/null
echo ""

# 4. Memory MCP server
echo "[4/5] Memory MCP server..."
if command -v mcp-server-memory >/dev/null 2>&1; then
    say_warn "mcp-server-memory already installed"
else
    npm install -g @modelcontextprotocol/server-memory 2>&1 | tail -2
    say_ok "mcp-server-memory installed globally"
fi
echo ""

# 5. Graphiti Python client
echo "[5/5] Graphiti Python client..."
mkdir -p "$HOME/.graphiti"
if [ -f "$HOME/.graphiti/qwen_client.py" ]; then
    say_warn "$HOME/.graphiti/qwen_client.py already exists (backing up)"
    cp "$HOME/.graphiti/qwen_client.py" "$HOME/.graphiti/qwen_client.py.bak.$(date +%Y-%m-%d-%H%M)"
fi

cp "$REPO_DIR/clients/graphiti/qwen_client.py" "$HOME/.graphiti/qwen_client.py"
cp "$REPO_DIR/clients/graphiti/feed_project.py" "$HOME/.graphiti/feed_project.py"
say_ok "Client files copied to $HOME/.graphiti/"

pip install graphiti-core falkordb-client aiohttp httpx 2>&1 | tail -1
say_ok "Python dependencies installed"

# Smoke test
echo ""
echo "Smoke test: Graphiti search..."
python3 <<PY | head -3
import asyncio, sys
sys.path.insert(0, '$HOME/.graphiti')
from qwen_client import create_qwen_graphiti

async def m():
    try:
        g = await create_qwen_graphiti(graph_name='test_install')
        r = await g.search('test', group_ids=['test_install'])
        print(f"✓ Graphiti OK: {len(r)} results")
    except Exception as e:
        print(f"✗ Graphiti FAIL: {e}")

asyncio.run(m())
PY

echo ""
echo "=== Services install complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit ~/.claude/settings.json to register MCP servers"
echo "     (template in docs/00-INSTALL-FROM-SCRATCH.md Phase 7)"
echo "  2. Install Viking separately — see Phase 2 of the install guide"
echo "  3. Start Claude Code in a project → run gngm-init.sh"
echo ""
echo "Full guide: $REPO_DIR/docs/00-INSTALL-FROM-SCRATCH.md"

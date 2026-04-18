#!/usr/bin/env bash
# GNGM 4-tool health check — ~10 seconds
# Usage: bash docs/GNGM/scripts/gngm-health.sh
#
# Exit codes:
#   0  — all four tools healthy
#   1  — one or more services down (details in output)

set -u  # fail on unset vars

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

ok=0
warn=0
fail=0

echo "=== GNGM Health Check ==="
echo ""

# 1. Graphiti — FalkorDB + Ollama Qwen
echo "[1/4] Graphiti"
if docker ps --filter name=falkordb --format '{{.Status}}' 2>/dev/null | grep -q Up; then
    echo -e "  ${GREEN}OK${RESET}   FalkorDB container running"
    ok=$((ok + 1))
else
    echo -e "  ${RED}FAIL${RESET} FalkorDB container not running"
    echo "       Fix: docker start falkordb  (or docker run if missing)"
    fail=$((fail + 1))
fi

if ollama list 2>/dev/null | grep -q "qwen3.5:9b"; then
    echo -e "  ${GREEN}OK${RESET}   Ollama qwen3.5:9b available"
    ok=$((ok + 1))
else
    if ollama list 2>/dev/null | grep -q "qwen3.5:4b"; then
        echo -e "  ${YELLOW}WARN${RESET} Ollama qwen3.5:4b available (9b missing — degraded mode)"
        echo "       Fix: ollama pull qwen3.5:9b"
        warn=$((warn + 1))
    else
        echo -e "  ${RED}FAIL${RESET} Ollama qwen3.5 not available"
        echo "       Fix: ollama pull qwen3.5:9b"
        fail=$((fail + 1))
    fi
fi

# 2. NeuralTree — MCP server path sanity
echo ""
echo "[2/4] NeuralTree"
if [ -f "/home/neil1988/.claude/settings.json" ]; then
    NT_PATH=$(python3 -c "
import json
try:
    d = json.load(open('/home/neil1988/.claude/settings.json'))
    print(d.get('mcpServers', {}).get('neuraltree', {}).get('env', {}).get('PYTHONPATH', 'MISSING'))
except Exception as e:
    print(f'ERROR: {e}')
" 2>&1)
    if [ "$NT_PATH" = "MISSING" ] || [[ "$NT_PATH" == ERROR* ]]; then
        echo -e "  ${RED}FAIL${RESET} NeuralTree MCP PYTHONPATH not set in settings.json"
        fail=$((fail + 1))
    elif [ ! -d "$NT_PATH" ]; then
        echo -e "  ${RED}FAIL${RESET} NeuralTree PYTHONPATH points to missing dir: $NT_PATH"
        fail=$((fail + 1))
    else
        echo -e "  ${GREEN}OK${RESET}   NeuralTree PYTHONPATH: $NT_PATH"
        ok=$((ok + 1))
    fi
else
    echo -e "  ${YELLOW}WARN${RESET} No ~/.claude/settings.json — MCP status unknown"
    warn=$((warn + 1))
fi

# Check lessons + wiki dirs
if [ -d "lessons" ] && [ -d ".neuraltree/wiki" ]; then
    n_lessons=$(ls lessons/*.md 2>/dev/null | grep -v _INDEX | wc -l)
    n_wikis=$(ls .neuraltree/wiki/*.md 2>/dev/null | wc -l)
    echo -e "  ${GREEN}OK${RESET}   lessons/ ($n_lessons files) + .neuraltree/wiki/ ($n_wikis files) present"
    ok=$((ok + 1))
else
    echo -e "  ${YELLOW}WARN${RESET} lessons/ or .neuraltree/wiki/ missing — will be created on first use"
    warn=$((warn + 1))
fi

# 3. Graphify — CLI + graph.json + hook
echo ""
echo "[3/4] Graphify"

# Find graphify binary — prefer project venv, fall back to PATH
GRAPHIFY_BIN=""
if [ -x ".venv-graphify/bin/graphify" ]; then
    GRAPHIFY_BIN=".venv-graphify/bin/graphify"
    echo -e "  ${GREEN}OK${RESET}   graphify CLI at .venv-graphify/bin/graphify (project venv)"
    ok=$((ok + 1))
elif command -v graphify >/dev/null 2>&1; then
    GRAPHIFY_BIN="$(command -v graphify)"
    echo -e "  ${GREEN}OK${RESET}   graphify CLI at $GRAPHIFY_BIN (on PATH)"
    ok=$((ok + 1))
else
    echo -e "  ${RED}FAIL${RESET} graphify CLI not found"
    echo "       Fix: python3 -m venv .venv-graphify && .venv-graphify/bin/pip install 'graphifyy[mcp]'"
    fail=$((fail + 1))
fi

if [ -f "graphify-out/graph.json" ]; then
    size=$(stat -c '%s' graphify-out/graph.json 2>/dev/null || stat -f '%z' graphify-out/graph.json 2>/dev/null)
    mtime=$(stat -c '%y' graphify-out/graph.json 2>/dev/null | cut -d. -f1 || stat -f '%Sm' graphify-out/graph.json 2>/dev/null)
    echo -e "  ${GREEN}OK${RESET}   graph.json present ($size bytes, modified $mtime)"
    ok=$((ok + 1))
else
    echo -e "  ${YELLOW}WARN${RESET} graphify-out/graph.json missing — run '$GRAPHIFY_BIN update .' to build"
    warn=$((warn + 1))
fi

# Check hook installed
if [ -f ".git/hooks/post-commit" ] && grep -q graphify-hook-start .git/hooks/post-commit 2>/dev/null; then
    echo -e "  ${GREEN}OK${RESET}   post-commit hook installed (auto-refresh on commit)"
    ok=$((ok + 1))
else
    echo -e "  ${YELLOW}WARN${RESET} post-commit hook NOT installed — run '$GRAPHIFY_BIN hook install'"
    warn=$((warn + 1))
fi

# 4. Viking — HTTP health
echo ""
echo "[4/4] Viking"
viking_status=$(curl -sS -m 3 http://localhost:1933/health 2>&1)
if echo "$viking_status" | grep -q '"healthy":true' 2>/dev/null; then
    version=$(echo "$viking_status" | python3 -c "import sys, json; print(json.load(sys.stdin).get('version', '?'))" 2>/dev/null)
    echo -e "  ${GREEN}OK${RESET}   Viking responding (v$version)"
    ok=$((ok + 1))
else
    echo -e "  ${RED}FAIL${RESET} Viking not responding on http://localhost:1933"
    echo "       Fix: ~/.openviking/start_viking.sh"
    fail=$((fail + 1))
fi

# Summary
echo ""
echo "=== Summary ==="
echo -e "  ${GREEN}OK:   $ok${RESET}"
[ "$warn" -gt 0 ] && echo -e "  ${YELLOW}WARN: $warn${RESET}"
[ "$fail" -gt 0 ] && echo -e "  ${RED}FAIL: $fail${RESET}"

if [ "$fail" -gt 0 ]; then
    echo ""
    echo "GNGM is DEGRADED — fix FAILs before work"
    exit 1
elif [ "$warn" -gt 0 ]; then
    echo ""
    echo "GNGM operational with warnings"
    exit 0
else
    echo ""
    echo "GNGM FULL POWER — all tools green"
    exit 0
fi

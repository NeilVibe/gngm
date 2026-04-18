#!/usr/bin/env bash
# GNGM one-command project bootstrap
# Usage: bash docs/GNGM/scripts/gngm-init.sh
#
# Idempotent — safe to re-run. Only creates what's missing.
#
# What it does:
#   1. Creates lessons/ + .neuraltree/wiki/ dirs with _INDEX.md
#   2. Installs graphify post-commit + post-checkout hooks
#   3. Runs initial graphify update . (AST-only, fast)
#   4. Creates first Graphiti episode to establish graph_id
#   5. Runs final health check

set -eu

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# Resolve graph name from current directory name (default)
PROJECT_NAME=$(basename "$(pwd)")
GRAPH_NAME="${GRAPH_NAME:-$PROJECT_NAME}"

echo "=== GNGM Project Bootstrap ==="
echo "Project: $PROJECT_NAME"
echo "Graph name: $GRAPH_NAME"
echo ""

# 1. Create directories
echo "[1/5] Creating lessons/ + .neuraltree/wiki/ ..."
mkdir -p lessons .neuraltree/wiki

if [ ! -f "lessons/_INDEX.md" ]; then
    cat > lessons/_INDEX.md <<EOF
# Lessons Index

Atomic lessons for this project. When a domain accumulates 3+ lessons, it becomes eligible for wiki compilation (see \`.neuraltree/wiki/\`).

## Domains

_(Populated as lessons are added via \`neuraltree_lesson_add\`.)_

## Conventions

- One lesson = one symptom → root cause → fix → chain
- Group related lessons in a single file by domain
- Every lesson needs a \`## <headline> (<date>)\` header
- Frontmatter required: name, description, type, last_verified
EOF
    echo -e "  ${GREEN}✓${RESET} lessons/_INDEX.md created"
else
    echo -e "  ${YELLOW}—${RESET} lessons/_INDEX.md exists, skipping"
fi

if [ ! -f ".neuraltree/wiki/_INDEX.md" ]; then
    cat > .neuraltree/wiki/_INDEX.md <<EOF
# Wiki Index

Canonical distilled docs. Populated via \`neuraltree_compile(topic, content, sources)\` when a lesson domain crosses 3 entries.

## Pages

_(Populated as domains become compile-ready.)_

## Conventions

- One page per topic
- Frontmatter required: name, description, source_count, last_compiled
- Body: synthesized from lessons/
- ## Sources section links back to source lesson files
- ## Related section cross-links other wikis
EOF
    echo -e "  ${GREEN}✓${RESET} .neuraltree/wiki/_INDEX.md created"
else
    echo -e "  ${YELLOW}—${RESET} .neuraltree/wiki/_INDEX.md exists, skipping"
fi

# 2. Install graphify (venv-first, PATH fallback) + hooks
echo ""
echo "[2/5] Installing graphify + hooks..."

# Resolve graphify binary — prefer project venv, fall back to PATH, create venv if missing
GRAPHIFY_BIN=""
if [ -x ".venv-graphify/bin/graphify" ]; then
    GRAPHIFY_BIN=".venv-graphify/bin/graphify"
    echo -e "  ${YELLOW}—${RESET} .venv-graphify/bin/graphify exists, using it"
elif command -v graphify >/dev/null 2>&1; then
    GRAPHIFY_BIN="$(command -v graphify)"
    echo -e "  ${YELLOW}—${RESET} using system graphify at $GRAPHIFY_BIN"
else
    echo "  Creating .venv-graphify/ + installing graphifyy[mcp]..."
    python3 -m venv .venv-graphify 2>&1 | tail -1
    .venv-graphify/bin/pip install --upgrade pip 2>&1 | tail -1
    .venv-graphify/bin/pip install "graphifyy[mcp]" 2>&1 | tail -2
    if [ -x ".venv-graphify/bin/graphify" ]; then
        GRAPHIFY_BIN=".venv-graphify/bin/graphify"
        echo -e "  ${GREEN}✓${RESET} graphify installed at .venv-graphify/bin/graphify"
    else
        echo -e "  ${YELLOW}!${RESET} graphify install failed — skipping hook + build"
        GRAPHIFY_BIN=""
    fi
fi

# Install hooks
if [ -n "$GRAPHIFY_BIN" ]; then
    if [ -f ".git/hooks/post-commit" ] && grep -q graphify-hook-start .git/hooks/post-commit 2>/dev/null; then
        echo -e "  ${YELLOW}—${RESET} post-commit hook already installed"
    else
        "$GRAPHIFY_BIN" hook install 2>&1 | head -3
        echo -e "  ${GREEN}✓${RESET} hooks installed"
    fi
fi

# 3. Initial graphify update
echo ""
echo "[3/5] Initial Graphify build..."
if [ -f "graphify-out/graph.json" ]; then
    echo -e "  ${YELLOW}—${RESET} graph.json already exists — skipping initial build"
    echo "       (run '$GRAPHIFY_BIN update .' to refresh)"
elif [ -n "$GRAPHIFY_BIN" ]; then
    echo "  Running: $GRAPHIFY_BIN update . (AST-only, no LLM)"
    echo "  (First build on a big repo may take 30-90s)"
    "$GRAPHIFY_BIN" update . 2>&1 | tail -8
else
    echo -e "  ${YELLOW}!${RESET} graphify not available — skipping build"
fi

# 4. First Graphiti episode (establishes graph_id)
echo ""
echo "[4/5] Seeding Graphiti graph '$GRAPH_NAME' ..."
if [ -f "/home/neil1988/.graphiti/qwen_client.py" ]; then
    python3 <<PY 2>&1 | tail -3
import asyncio, sys
sys.path.insert(0, '/home/neil1988/.graphiti')
from qwen_client import create_qwen_graphiti
from datetime import datetime, timezone

async def m():
    try:
        g = await create_qwen_graphiti(graph_name='$GRAPH_NAME')
        r = await g.search('project init', group_ids=['$GRAPH_NAME'])
        if len(r) > 0:
            print(f"  Graph '$GRAPH_NAME' already has {len(r)} facts — skipping seed")
            return
        await g.add_episode(
            name='gngm-bootstrap-$PROJECT_NAME-$(date +%Y-%m-%d)',
            episode_body="""
GNGM bootstrap for project $PROJECT_NAME on $(date +%Y-%m-%d).
Initial graph creation. Connects: $PROJECT_NAME -> GNGM -> Graphiti.
Hooks installed, lessons/ + .neuraltree/wiki/ dirs created, ready for work.
""",
            source_description='GNGM init bootstrap',
            reference_time=datetime.now(timezone.utc),
            group_id='$GRAPH_NAME',
        )
        print(f"  ${GREEN}✓${RESET} Graphiti graph '$GRAPH_NAME' seeded")
    except Exception as e:
        print(f"  ${YELLOW}!${RESET} Graphiti seed failed: {e}")
        print(f"       (not blocking — you can add episodes manually later)")

asyncio.run(m())
PY
else
    echo -e "  ${YELLOW}!${RESET} ~/.graphiti/qwen_client.py not found — skipping seed"
fi

# 5. Final health check
echo ""
echo "[5/5] Running final health check..."
echo ""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/gngm-health.sh" ]; then
    bash "$SCRIPT_DIR/gngm-health.sh"
else
    echo -e "  ${YELLOW}—${RESET} gngm-health.sh not found next to this script"
fi

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Next steps:"
echo "  1. Read docs/GNGM/02-PROTOCOL.md to internalize the four modes"
echo "  2. Keep docs/GNGM/03-CHEATSHEET.md open for quick reference"
echo "  3. Start working — say 'GNGM' in chat to trigger the protocol"

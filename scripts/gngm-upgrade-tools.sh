#!/usr/bin/env bash
# GNGM tool upgrade — opt-in upgrade of the knowledge-stack TOOLS to the
# versions pinned by the installed GNGM release.
#
# Usage:
#   bash docs/GNGM/scripts/gngm-upgrade-tools.sh [target_project_path] [--yes]
#
# Or via curl:
#   curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/scripts/gngm-upgrade-tools.sh \
#     | bash -s -- /path/to/project --yes
#
# Why this is SEPARATE from gngm-update.sh:
#   gngm-update.sh refreshes DOCS only — non-destructive, never touches envs.
#   THIS script upgrades the actual tool binaries: it rebuilds .venv-graphify,
#   bumps graphiti-core, and refreshes the vendored Graphiti client. Kept
#   separate + opt-in so gngm-update.sh stays safe and predictable.
#
# Pinned targets (GNGM 0.7.0):
#   graphifyy[mcp]  -> 0.8.5    per-project .venv-graphify (isolated)
#   graphiti-core   -> 0.29.0   shared user-level install (see note below)
#
# What it does NOT touch:
#   - your project source, lessons/, memory/, docs/ outside docs/GNGM/
#   - the Graphiti graph data stored in FalkorDB
#
# Idempotent. Safe to re-run. Confirms before mutating anything.

set -eu

GRAPHIFYY_VERSION="0.8.5"
GRAPHITI_CORE_VERSION="0.29.0"

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; BLUE="\033[0;34m"; RESET="\033[0m"

# ---- Parse args (target path + optional --yes) -------------------------------
TARGET=""
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        *)        TARGET="$arg" ;;
    esac
done

# ---- Resolve target project root ---------------------------------------------
if [ -z "$TARGET" ]; then
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # Installed layout: <project>/docs/GNGM/scripts/
        if [ -f "$SCRIPT_DIR/../README.md" ] && [ -d "$SCRIPT_DIR/../protocols" ]; then
            TARGET="$(cd "$SCRIPT_DIR/../../.." && pwd)"
        fi
    fi
    TARGET="${TARGET:-$(pwd)}"
fi
if [ ! -d "$TARGET" ]; then
    echo -e "${RED}ERROR${RESET}: target '$TARGET' is not a directory"
    exit 1
fi

echo -e "${BLUE}=== GNGM tool upgrade ===${RESET}"
echo "Target project: $TARGET"
echo ""
echo "Will upgrade:"
echo "  graphifyy[mcp]  -> ${GRAPHIFYY_VERSION}   ($TARGET/.venv-graphify, isolated)"
echo "  graphiti-core   -> ${GRAPHITI_CORE_VERSION}  (shared user-level pip install)"
echo ""
echo -e "${YELLOW}Note:${RESET} graphiti-core is a shared install — bumping it affects every GNGM"
echo "      project on this machine. 0.29.0 is API-compatible with 0.28.x"
echo "      (verified), and the step is idempotent, so re-runs are harmless."
echo ""

# ---- Confirm -----------------------------------------------------------------
if [ "$ASSUME_YES" -ne 1 ]; then
    if [ -e /dev/tty ]; then
        printf "Continue? [y/N]: "
        read -r ans </dev/tty 2>/dev/null || ans="n"
        case "$ans" in
            y|Y) ;;
            *) echo "Aborted. Nothing changed."; exit 0 ;;
        esac
    else
        echo -e "${RED}No TTY${RESET} — re-run with --yes to confirm non-interactively."
        exit 1
    fi
fi
echo ""

cd "$TARGET"

# ---- 1. Graphify venv --------------------------------------------------------
echo "[1/4] Graphify -> graphifyy[mcp]==${GRAPHIFYY_VERSION}"
if [ -d ".venv-graphify" ]; then
    .venv-graphify/bin/pip install --upgrade "graphifyy[mcp]==${GRAPHIFYY_VERSION}" 2>&1 | tail -2
    echo -e "  ${GREEN}OK${RESET} .venv-graphify upgraded"
else
    python3 -m venv .venv-graphify 2>&1 | tail -1
    .venv-graphify/bin/pip install --upgrade pip 2>&1 | tail -1
    .venv-graphify/bin/pip install "graphifyy[mcp]==${GRAPHIFYY_VERSION}" 2>&1 | tail -2
    echo -e "  ${GREEN}OK${RESET} .venv-graphify created + installed"
fi
.venv-graphify/bin/graphify --version 2>/dev/null | sed 's/^/  /' || true
echo ""

# ---- 2. One-time graph rebuild (0.4.x -> 0.8.x format) -----------------------
echo "[2/4] One-time graph rebuild (0.4.x -> 0.8.x format)"
# The 0.4.x -> 0.8.x jump changes the cache layout and the node-ID format.
# A clean AST rebuild (no LLM / no backend needed) regenerates graph.json in
# the new format and clears ghost-duplicate nodes from the old ID scheme.
# Community IDs renumber once on this rebuild — expected and harmless.
if [ -d "graphify-out" ]; then
    rm -rf graphify-out/cache/
    rm -f graphify-out/graph.json graphify-out/manifest.json
    echo "  cleared graphify-out/cache/ + stale graph.json"
    .venv-graphify/bin/graphify update . 2>&1 | tail -5
    echo -e "  ${GREEN}OK${RESET} graph rebuilt in 0.8.x format (community IDs renumbered once — expected)"
    echo "       if this project also used semantic extraction, re-run:"
    echo "         .venv-graphify/bin/graphify extract . --backend <ollama|claude-cli>"
else
    echo -e "  ${YELLOW}--${RESET} no graphify-out/ yet — run gngm-init.sh for the first build"
fi
if [ -d ".git" ]; then
    .venv-graphify/bin/graphify hook install 2>&1 | head -2 || true
    echo -e "  ${GREEN}OK${RESET} graphify git hooks refreshed"
fi
echo ""

# ---- 3. graphiti-core --------------------------------------------------------
echo "[3/4] Graphiti -> graphiti-core[falkordb]==${GRAPHITI_CORE_VERSION}"
pip install --upgrade "graphiti-core[falkordb]==${GRAPHITI_CORE_VERSION}" aiohttp httpx 2>&1 | tail -2
echo -e "  ${GREEN}OK${RESET} graphiti-core upgraded"
echo ""

# ---- 4. Vendored Graphiti client ---------------------------------------------
echo "[4/4] Vendored Graphiti client (~/.graphiti/qwen_client.py)"
# GNGM 0.7.0's client is verified against graphiti-core 0.29.0. Refresh from the
# clients/ subtree if this install carries it (GNGM >= 0.7.0); else print guidance.
CLIENT_SRC=""
for cand in \
    "$TARGET/docs/GNGM/clients/graphiti/qwen_client.py" \
    "$(dirname "${BASH_SOURCE[0]:-/dev/null}")/../clients/graphiti/qwen_client.py"; do
    if [ -f "$cand" ]; then CLIENT_SRC="$cand"; break; fi
done
if [ -n "$CLIENT_SRC" ] && [ -f "$HOME/.graphiti/qwen_client.py" ]; then
    cp "$HOME/.graphiti/qwen_client.py" "$HOME/.graphiti/qwen_client.py.bak.$(date +%Y-%m-%d-%H%M)"
    cp "$CLIENT_SRC" "$HOME/.graphiti/qwen_client.py"
    echo -e "  ${GREEN}OK${RESET} ~/.graphiti/qwen_client.py refreshed (previous version backed up)"
elif [ -n "$CLIENT_SRC" ]; then
    echo -e "  ${YELLOW}--${RESET} no ~/.graphiti/qwen_client.py present — run install-services.sh to set it up"
else
    echo -e "  ${YELLOW}--${RESET} clients/ not found in this install — refresh the client manually:"
    echo "       cp <gngm-repo>/clients/graphiti/qwen_client.py ~/.graphiti/qwen_client.py"
fi
echo ""

echo -e "${GREEN}=== Tool upgrade complete ===${RESET}"
echo ""
HEALTH="$(dirname "${BASH_SOURCE[0]:-/dev/null}")/gngm-health.sh"
if [ -f "$HEALTH" ]; then
    echo "Verify: bash $HEALTH"
else
    echo "Verify: bash docs/GNGM/scripts/gngm-health.sh"
fi

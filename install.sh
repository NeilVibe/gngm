#!/usr/bin/env bash
# GNGM installer — drops the knowledge stack into any project
#
# Usage:
#   ./install.sh [target_project_path]        # defaults to current directory
#
# Or via curl:
#   curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/install.sh | bash -s -- /path/to/project
#
# What it does:
#   1. Copies docs/ + scripts/ from this repo into <target>/docs/GNGM/
#   2. Does NOT run the bootstrap — that's a separate explicit step
#      (so the user can inspect before committing to service installs)
#
# After install, run:
#   cd /path/to/project
#   bash docs/GNGM/scripts/gngm-init.sh

set -eu

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

TARGET="${1:-$(pwd)}"
REPO_URL="https://github.com/NeilVibe/gngm.git"

# Resolve source directory — prefer local clone if script is run from it
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/README.md" ]; then
    SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "Source: local clone at $SOURCE_DIR"
else
    # Running via curl | bash — need to clone
    SOURCE_DIR="$(mktemp -d)/gngm"
    echo "Source: cloning $REPO_URL to $SOURCE_DIR"
    git clone --depth 1 "$REPO_URL" "$SOURCE_DIR" >/dev/null 2>&1
fi

# Validate target
if [ ! -d "$TARGET" ]; then
    echo -e "${RED}ERROR${RESET}: target '$TARGET' is not a directory"
    exit 1
fi

TARGET_DOCS="$TARGET/docs/GNGM"
echo "Target: $TARGET_DOCS"
echo ""

# Check for existing install
if [ -d "$TARGET_DOCS" ]; then
    echo -e "${YELLOW}WARN${RESET}: $TARGET_DOCS already exists"
    echo "       Proceeding will overwrite existing docs + scripts"
    printf "       Continue? [y/N]: "
    read -r ans
    if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Create target + copy files
mkdir -p "$TARGET_DOCS/docs" "$TARGET_DOCS/scripts" "$TARGET_DOCS/protocols"
cp "$SOURCE_DIR/docs"/*.md "$TARGET_DOCS/docs/" 2>/dev/null
cp "$SOURCE_DIR/scripts"/*.sh "$TARGET_DOCS/scripts/"
cp "$SOURCE_DIR/protocols"/*.md "$TARGET_DOCS/protocols/" 2>/dev/null
chmod +x "$TARGET_DOCS/scripts"/*.sh

# Also drop a thin README at the top of docs/GNGM/ pointing to the detailed docs
cat > "$TARGET_DOCS/README.md" <<'EOF'
# GNGM Knowledge Stack (installed)

This directory contains the GNGM (Graphiti + NeuralTree + Graphify + MemoryMCP) knowledge stack installed from https://github.com/NeilVibe/gngm.

## Quick start

```bash
# 1. Bootstrap — installs Graphify venv, hooks, lessons dir, Graphiti seed
bash docs/GNGM/scripts/gngm-init.sh

# 2. Health check any time
bash docs/GNGM/scripts/gngm-health.sh

# 3. Say "GNGM" in Claude Code to trigger the protocol
```

## Detailed docs

See `docs/GNGM/docs/`:

- `01-SETUP.md` — prerequisites + installation
- `02-PROTOCOL.md` — full 4-mode protocol
- `03-CHEATSHEET.md` — one-page reference
- `04-LESSONS.md` — 9 pitfalls + resilience patterns
EOF

echo ""
echo -e "${GREEN}✓${RESET} GNGM installed at $TARGET_DOCS"
echo ""
echo "Next steps:"
echo "  cd $TARGET"
echo "  bash docs/GNGM/scripts/gngm-init.sh         # bootstrap project"
echo ""
echo "Then say 'GNGM' in Claude Code to trigger the protocol."

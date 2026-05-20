#!/usr/bin/env bash
# GNGM updater — non-destructive refresh of already-installed GNGM in a project
#
# Usage:
#   bash docs/GNGM/scripts/gngm-update.sh [target_project_path]
#
#   target_project_path defaults to the parent of $TARGET_DOCS if running
#   from inside an installed copy, otherwise to the current directory.
#
# Or via curl (for projects that don't yet have a local copy of this script):
#   curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/scripts/gngm-update.sh | bash -s -- /path/to/project
#
# What it does:
#   Refreshes ONLY the GNGM-managed subtree under <target>/docs/GNGM/:
#     - docs/GNGM/protocols/   ← full overwrite from upstream
#     - docs/GNGM/docs/        ← full overwrite from upstream
#     - docs/GNGM/scripts/     ← full overwrite from upstream
#     - docs/GNGM/clients/     ← full overwrite from upstream (vendored Graphiti client)
#     - docs/GNGM/README.md    ← refreshed
#
#   What it does NOT touch:
#     - <target>/CLAUDE.md, MEMORY.md, MASTER_PLAN.md, etc. (project files)
#     - <target>/docs/ outside the GNGM subtree
#     - <target>/lessons/, memory/, src/, etc.
#     - Any project-authored files
#
# Safe to re-run any time. Idempotent. Prints a summary diff.

set -eu

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

REPO_URL="https://github.com/NeilVibe/gngm.git"

# ---- Resolve target ----------------------------------------------------------

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    # If we're running from an installed copy, infer the project root
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # Expected: <project>/docs/GNGM/scripts/
        if [ -f "$SCRIPT_DIR/../README.md" ] && [ -d "$SCRIPT_DIR/../protocols" ]; then
            TARGET="$(cd "$SCRIPT_DIR/../../.." && pwd)"
        fi
    fi
    # Fallback to cwd
    TARGET="${TARGET:-$(pwd)}"
fi

TARGET_DOCS="$TARGET/docs/GNGM"

if [ ! -d "$TARGET_DOCS" ]; then
    echo -e "${RED}ERROR${RESET}: $TARGET_DOCS does not exist."
    echo "       This script updates an EXISTING GNGM install. For first install:"
    echo "       curl -fsSL https://raw.githubusercontent.com/NeilVibe/gngm/main/install.sh | bash -s -- $TARGET"
    exit 1
fi

echo -e "${BLUE}=== GNGM Update ===${RESET}"
echo "Target: $TARGET_DOCS"
echo ""

# ---- Resolve source ----------------------------------------------------------

# Prefer local clone if script is being run from one
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    POSSIBLE_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -f "$POSSIBLE_SOURCE/README.md" ] && [ -d "$POSSIBLE_SOURCE/protocols" ] && [ "$POSSIBLE_SOURCE" != "$TARGET_DOCS" ]; then
        SOURCE_DIR="$POSSIBLE_SOURCE"
        echo "Source: local clone at $SOURCE_DIR"
    fi
fi

# Otherwise clone fresh
if [ -z "${SOURCE_DIR:-}" ]; then
    SOURCE_DIR="$(mktemp -d)/gngm"
    echo "Source: cloning $REPO_URL"
    git clone --depth 1 "$REPO_URL" "$SOURCE_DIR" >/dev/null 2>&1
    CLEANUP_SOURCE=1
fi

# ---- Capture pre-state -------------------------------------------------------

before_protocols=$(ls "$TARGET_DOCS/protocols"/*.md 2>/dev/null | wc -l)
before_docs=$(ls "$TARGET_DOCS/docs"/*.md 2>/dev/null | wc -l)
before_scripts=$(ls "$TARGET_DOCS/scripts"/*.sh 2>/dev/null | wc -l)

echo ""
echo "Before refresh:"
echo "  protocols/  $before_protocols files"
echo "  docs/       $before_docs files"
echo "  scripts/    $before_scripts files"
echo ""

# ---- Refresh -----------------------------------------------------------------

echo "Refreshing GNGM-managed subtree (non-destructive to project files)..."

mkdir -p "$TARGET_DOCS/protocols" "$TARGET_DOCS/docs" "$TARGET_DOCS/scripts" "$TARGET_DOCS/clients/graphiti"

# Refresh a managed directory: overwrite the files that exist upstream, but
# PRESERVE project-only files. A consuming project may add its own custom
# protocol / doc / script alongside the GNGM-managed ones (winacard, for
# example, keeps a project-specific protocols/AVQA.md). Blind-wiping the whole
# directory destroyed those. Only files GNGM actually ships are removed first;
# everything else in the directory survives.
PRESERVED=0
refresh_managed_dir() {
    local sub="$1" ext="$2"
    local src="$SOURCE_DIR/$sub" dst="$TARGET_DOCS/$sub"
    mkdir -p "$dst"
    local f base
    for f in "$dst"/*."$ext"; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        if [ -f "$src/$base" ]; then
            rm -f "$f"          # GNGM-managed — recopied fresh below
        else
            echo -e "  ${YELLOW}preserved project-only${RESET} $sub/$base"
            PRESERVED=$((PRESERVED + 1))
        fi
    done
    cp "$src"/*."$ext" "$dst/" 2>/dev/null || true
}

refresh_managed_dir protocols       md
refresh_managed_dir docs            md
refresh_managed_dir scripts         sh
refresh_managed_dir clients/graphiti py
chmod +x "$TARGET_DOCS/scripts"/*.sh

# Version stamp — lets a consuming project check which GNGM release it is on
cp "$SOURCE_DIR/VERSION" "$TARGET_DOCS/VERSION" 2>/dev/null || true

# README.md inside the installed dir (the "thin" pointer) is regenerated
# fresh from the install.sh-style template so it stays current
cat > "$TARGET_DOCS/README.md" <<'EOF'
# GNGM Knowledge Stack (installed)

This directory contains the GNGM (Graphiti + NeuralTree + Graphify + MemoryMCP) knowledge stack installed from https://github.com/NeilVibe/gngm.

## Quick start

```bash
# 1. Bootstrap — installs Graphify venv, hooks, lessons dir, Graphiti seed
bash docs/GNGM/scripts/gngm-init.sh

# 2. Health check any time
bash docs/GNGM/scripts/gngm-health.sh

# 3. Refresh THIS install when upstream ships new protocols/docs
bash docs/GNGM/scripts/gngm-update.sh

# 4. Upgrade tool versions when a release pins newer ones (opt-in)
bash docs/GNGM/scripts/gngm-upgrade-tools.sh

# 5. Say "GNGM" / "PRD" / "NSH" / etc. in Claude Code to trigger protocols
```

## Detailed docs

See `docs/GNGM/docs/`:

- `00-INSTALL-FROM-SCRATCH.md` — full install pipeline
- `01-SETUP.md` — prerequisites + installation
- `02-PROTOCOL.md` — full 4-mode protocol
- `03-CHEATSHEET.md` — one-page reference
- `04-LESSONS.md` — pitfalls + resilience patterns
- `05-PROJECT-STRUCTURE.md` — canonical project tree
- `06-WAVE-PROTOCOL.md` — wave lifecycle
- `07-GRAPHIFY-MASTERY.md` — using Graphify to full potential
- `08-GRAPHITI-MASTERY.md` — using Graphiti to full potential
- `09-GOAL-AUTONOMOUS-MODE.md` — Claude Code `/goal` as a discipline-preserving autonomy muscle
- `UPGRADE-0.7.0.md` — moving an existing project to release 0.7.0

## Protocols

See `docs/GNGM/protocols/` and `docs/GNGM/README.md` for the canonical list.

Foundational: NLF, SDP, TDD.
Operational: GIT-SAFETY, GIT-HYGIENE, RAC, DEBUG, LOGGING, STRESS-TEST, NATURAL-STOP-HANDOFF.
Product / scoping: PRD, PRD-TO-ISSUES, UBIQUITOUS-LANGUAGE, IMPROVE-ARCHITECTURE.
EOF

# ---- Post-state + summary ----------------------------------------------------

after_protocols=$(ls "$TARGET_DOCS/protocols"/*.md 2>/dev/null | wc -l)
after_docs=$(ls "$TARGET_DOCS/docs"/*.md 2>/dev/null | wc -l)
after_scripts=$(ls "$TARGET_DOCS/scripts"/*.sh 2>/dev/null | wc -l)

echo ""
echo "After refresh:"
echo "  protocols/  $after_protocols files (was $before_protocols)"
echo "  docs/       $after_docs files (was $before_docs)"
echo "  scripts/    $after_scripts files (was $before_scripts)"
echo ""

# Compute deltas (new + removed protocols specifically — they matter most)
NEW_PROTOCOLS=$(comm -13 \
    <(ls "$TARGET_DOCS/protocols"/*.md 2>/dev/null | xargs -n1 basename | sort) \
    <(ls "$SOURCE_DIR/protocols"/*.md   2>/dev/null | xargs -n1 basename | sort) \
    2>/dev/null || true)
# (after re-copy, target == source, so this will be empty post-refresh — instead diff against before)

# Cleanup if we cloned
if [ -n "${CLEANUP_SOURCE:-}" ] && [ -d "$SOURCE_DIR" ]; then
    rm -rf "$(dirname "$SOURCE_DIR")"
fi

echo -e "${GREEN}Update complete.${RESET}"
echo "GNGM version: $(cat "$TARGET_DOCS/VERSION" 2>/dev/null || echo 'unknown (pre-0.8.0)')"
echo ""
if [ "${PRESERVED:-0}" -gt 0 ]; then
    echo -e "${YELLOW}Preserved $PRESERVED project-only file(s)${RESET} — kept as-is (not GNGM-managed)."
    echo ""
fi
echo -e "${YELLOW}⚠ GNGM-managed files were overwritten from upstream.${RESET}"
echo "  If you edited a GNGM-managed protocol/doc IN PLACE (e.g. extended the"
echo "  shipped DEBUG.md with project-specific runbooks), that edit was"
echo "  replaced. Run 'git diff docs/GNGM/' and restore in-place"
echo "  customizations BEFORE committing."
echo ""
echo "Next steps:"
echo "  - Review protocol changes:    git -C $TARGET diff --stat docs/GNGM/"
echo "  - Run health check:           bash $TARGET_DOCS/scripts/gngm-health.sh"
echo "  - Commit refreshed install:   cd $TARGET && git add docs/GNGM/ && git commit -m 'chore(gngm): update to latest'"
echo ""
echo "If new protocols shipped, see:"
echo "  - $TARGET_DOCS/README.md (refreshed pointer)"
echo "  - https://github.com/NeilVibe/gngm/blob/main/CHANGELOG.md (release notes)"

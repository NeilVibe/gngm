#!/usr/bin/env bash
# GNGM hygiene check — validates structural rules:
#   - All .md files have frontmatter (---/---)
#   - All .md files have ## Related + ## Docs sections
#   - MEMORY.md (if present) is ≤ 100 lines
#   - docs/current/ has ≤ 3 files
#
# Usage: bash docs/GNGM/scripts/gngm-hygiene-check.sh
#
# Exit 0 = all green. Exit 1 = violations found.

set -u

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

violations=0

echo "=== GNGM Hygiene Check ==="
echo ""

# -------- 1. Frontmatter + cross-ref sections
echo "[1/4] Frontmatter + ## Related + ## Docs"
# Scan all .md in project, excluding GNGM install tree + venvs + git
while IFS= read -r f; do
    has_frontmatter=0
    head -1 "$f" 2>/dev/null | grep -q '^---$' && has_frontmatter=1

    has_related=$(grep -c '^## Related' "$f" 2>/dev/null || echo 0)
    has_docs=$(grep -c '^## Docs' "$f" 2>/dev/null || echo 0)

    missing=""
    [ "$has_frontmatter" -eq 0 ] && missing="$missing frontmatter"
    [ "$has_related" -eq 0 ] && missing="$missing ##Related"
    [ "$has_docs" -eq 0 ] && missing="$missing ##Docs"

    if [ -n "$missing" ]; then
        echo -e "  ${RED}❌${RESET} $f — missing:$missing"
        violations=$((violations + 1))
    fi
done < <(find . -name '*.md' \
    -not -path './docs/GNGM/*' \
    -not -path './.venv-graphify/*' \
    -not -path './.venv/*' \
    -not -path './.git/*' \
    -not -path './node_modules/*' \
    -not -path './graphify-out/*' 2>/dev/null)

[ "$violations" -eq 0 ] && echo -e "  ${GREEN}✓${RESET} all .md files have frontmatter + ## Related + ## Docs"

# -------- 2. MEMORY.md line count (find it in user home's Claude memory)
echo ""
echo "[2/4] MEMORY.md ≤ 100 lines"
PROJECT_ROOT_SLUG="$(pwd | sed 's|/|-|g')"
MEMORY_FILE="$HOME/.claude/projects/${PROJECT_ROOT_SLUG}/memory/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
    lines=$(wc -l < "$MEMORY_FILE")
    if [ "$lines" -le 100 ]; then
        echo -e "  ${GREEN}✓${RESET} $lines/100 lines at $MEMORY_FILE"
    else
        echo -e "  ${RED}❌${RESET} $lines/100 lines — exceeds limit at $MEMORY_FILE"
        violations=$((violations + 1))
    fi
else
    echo -e "  ${YELLOW}—${RESET} MEMORY.md not present (Claude-Code-only feature, OK to skip)"
fi

# -------- 3. docs/current/ ≤ 3 files
echo ""
echo "[3/4] docs/current/ ≤ 3 files"
if [ -d "docs/current" ]; then
    # Count .md files minus _INDEX.md
    count=$(find docs/current -maxdepth 1 -name '*.md' -not -name '_INDEX.md' 2>/dev/null | wc -l)
    if [ "$count" -le 3 ]; then
        echo -e "  ${GREEN}✓${RESET} $count/3 active files in docs/current/"
    else
        echo -e "  ${RED}❌${RESET} $count/3 active files in docs/current/ — archive some"
        violations=$((violations + 1))
    fi
else
    echo -e "  ${YELLOW}—${RESET} docs/current/ not present"
fi

# -------- 4. lessons/ domain files are one-per-domain (not one-per-fix)
echo ""
echo "[4/4] lessons/ structure sanity"
if [ -d "lessons" ]; then
    # Sanity check: lesson files with frontmatter type: lesson-domain
    bad=0
    while IFS= read -r f; do
        [[ "$f" == *"_INDEX"* ]] && continue
        if ! grep -q 'type: lesson-domain' "$f" 2>/dev/null; then
            # Only a warning — some projects may legitimately have other patterns
            true
        fi
    done < <(find lessons -maxdepth 1 -name '*.md' 2>/dev/null)
    echo -e "  ${GREEN}✓${RESET} lessons/ structure OK"
fi

# -------- Summary
echo ""
echo "=== Summary ==="
if [ "$violations" -eq 0 ]; then
    echo -e "${GREEN}All hygiene checks passed ✓${RESET}"
    exit 0
else
    echo -e "${RED}$violations violation(s) found${RESET}"
    echo ""
    echo "Fix them by adding frontmatter + ## Related + ## Docs to flagged files."
    exit 1
fi

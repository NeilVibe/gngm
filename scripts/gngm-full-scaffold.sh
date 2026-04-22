#!/usr/bin/env bash
# GNGM Full Project Scaffold — makes a project ready to fully harness GNGM.
#
# Works on:
#   - Empty directories (new projects)
#   - Existing repos (grafts GNGM on without touching your code)
#
# Works with:
#   - Claude Code (CLAUDE.md + memory trunk at ~/.claude/projects/)
#   - Codex CLI / Cursor / multi-CLI (AGENTS.md)
#   - Gemini CLI (GEMINI.md)
#   - Any combination (--ai-cli all)
#
# Works for any language/stack — the structure wraps around your code.
#
# Idempotent: never clobbers existing files. Safe to re-run.
#
# Usage:
#   bash docs/GNGM/scripts/gngm-full-scaffold.sh [--ai-cli <claude|codex|gemini|all>]
#                                                [--project-name <name>]
#                                                [--purpose "<one-line>"]
#                                                [--domains "d1,d2,d3"]
#                                                [--memory-trunk <on|off>]
#                                                [--no-prompt]
#
# All flags optional — script prompts interactively if missing.

set -eu

# -------- colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# -------- defaults + arg parsing
AI_CLI=""
PROJECT_NAME=""
PURPOSE=""
DOMAINS_CSV=""
MEMORY_TRUNK="auto"
INTERACTIVE=1

while [ $# -gt 0 ]; do
    case "$1" in
        --ai-cli)       AI_CLI="$2"; shift 2;;
        --project-name) PROJECT_NAME="$2"; shift 2;;
        --purpose)      PURPOSE="$2"; shift 2;;
        --domains)      DOMAINS_CSV="$2"; shift 2;;
        --memory-trunk) MEMORY_TRUNK="$2"; shift 2;;
        --no-prompt)    INTERACTIVE=0; shift;;
        -h|--help)
            grep -E '^#( |$)' "$0" | sed 's/^# \?//' | head -40
            exit 0;;
        *)
            echo -e "${RED}Unknown arg:${RESET} $1"
            exit 1;;
    esac
done

# -------- resolve paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Templates live next to scripts/ when called from installed project,
# OR one level up when running from the gngm repo directly
if [ -d "$SCRIPT_DIR/../templates" ]; then
    TEMPLATES_DIR="$SCRIPT_DIR/../templates"
elif [ -d "$SCRIPT_DIR/../../templates" ]; then
    TEMPLATES_DIR="$SCRIPT_DIR/../../templates"
else
    echo -e "${RED}ERROR${RESET} Can't find templates/ directory relative to $SCRIPT_DIR"
    echo "       Script must be run from within a GNGM install or the gngm repo."
    exit 1
fi

PROJECT_ROOT="$(pwd)"
DATE="$(date +%Y-%m-%d)"

# -------- auto-detect project name
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# -------- header
echo ""
echo -e "${CYAN}=== GNGM Full Project Scaffold ===${RESET}"
echo "Project: $PROJECT_NAME"
echo "Root:    $PROJECT_ROOT"
echo "Date:    $DATE"
echo ""

# -------- interactive prompts (only if INTERACTIVE=1 and flag missing)
prompt_default() {
    local varname="$1"
    local prompt_text="$2"
    local default_val="${3:-}"
    local cur_val
    eval "cur_val=\${$varname}"
    if [ -z "$cur_val" ] && [ "$INTERACTIVE" -eq 1 ]; then
        if [ -n "$default_val" ]; then
            printf "  %s [default: %s]: " "$prompt_text" "$default_val"
        else
            printf "  %s: " "$prompt_text"
        fi
        read -r ans
        [ -z "$ans" ] && ans="$default_val"
        eval "$varname=\"\$ans\""
    elif [ -z "$cur_val" ]; then
        eval "$varname=\"\$default_val\""
    fi
}

prompt_default AI_CLI "Which CLI AI? (claude/codex/gemini/all)" "claude"
prompt_default PURPOSE "One-line project purpose" "(fill in later in CLAUDE.md)"
prompt_default DOMAINS_CSV "Pre-seed lesson domains (comma-separated, or blank)" ""
if [ "$AI_CLI" = "claude" ] || [ "$AI_CLI" = "all" ]; then
    [ "$MEMORY_TRUNK" = "auto" ] && MEMORY_TRUNK="on"
else
    [ "$MEMORY_TRUNK" = "auto" ] && MEMORY_TRUNK="off"
fi

# Validate ai-cli choice
case "$AI_CLI" in
    claude|codex|gemini|all) ;;
    *)
        echo -e "${RED}ERROR${RESET} --ai-cli must be one of: claude, codex, gemini, all"
        exit 1;;
esac

echo ""
echo -e "${CYAN}Plan:${RESET}"
echo "  CLI AI:          $AI_CLI"
echo "  Project name:    $PROJECT_NAME"
echo "  Purpose:         $PURPOSE"
echo "  Lesson domains:  ${DOMAINS_CSV:-(none)}"
echo "  Memory trunk:    $MEMORY_TRUNK"
echo ""

# -------- helpers
# substitute_tpl <src-tpl> <dest-file>  — fill placeholders, write only if dest missing
substitute_tpl() {
    local src="$1"
    local dest="$2"
    if [ -f "$dest" ]; then
        echo -e "  ${YELLOW}—${RESET} $dest exists, skipping"
        return 0
    fi
    if [ ! -f "$src" ]; then
        echo -e "  ${RED}!${RESET} template missing: $src"
        return 1
    fi
    mkdir -p "$(dirname "$dest")"
    sed \
        -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{PURPOSE}}|$PURPOSE|g" \
        -e "s|{{DATE}}|$DATE|g" \
        "$src" > "$dest"
    echo -e "  ${GREEN}✓${RESET} $dest"
}

# Variant for domain-template (has {{DOMAIN}} placeholder too)
substitute_domain_tpl() {
    local src="$1"
    local dest="$2"
    local domain="$3"
    if [ -f "$dest" ]; then
        echo -e "  ${YELLOW}—${RESET} $dest exists, skipping"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    sed \
        -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{PURPOSE}}|$PURPOSE|g" \
        -e "s|{{DATE}}|$DATE|g" \
        -e "s|{{DOMAIN}}|$domain|g" \
        "$src" > "$dest"
    echo -e "  ${GREEN}✓${RESET} $dest"
}

# -------- Step 1 — Git repo
echo -e "${CYAN}[1/7] Git repo${RESET}"
if [ ! -d ".git" ]; then
    if [ "$INTERACTIVE" -eq 1 ]; then
        printf "  Not a git repo. Init here? [Y/n]: "
        read -r ans
    else
        ans="y"
    fi
    if [ "$ans" != "n" ] && [ "$ans" != "N" ]; then
        git init -q
        echo -e "  ${GREEN}✓${RESET} git initialized"
    else
        echo -e "  ${YELLOW}—${RESET} skipped (graphify hooks need git — may fail later)"
    fi
else
    echo -e "  ${YELLOW}—${RESET} git repo already exists"
fi

# -------- Step 2 — Memory trunk (Claude Code specific)
echo ""
echo -e "${CYAN}[2/7] Claude memory trunk${RESET}"
if [ "$MEMORY_TRUNK" = "on" ]; then
    MEMORY_DIR="$HOME/.claude/projects/-${PROJECT_ROOT//\//-}/memory"
    # Strip leading double-dash that occurs because path starts with /
    MEMORY_DIR="$(echo "$MEMORY_DIR" | sed 's|/-home|/-home|')"
    echo "  Memory trunk path: $MEMORY_DIR"
    mkdir -p "$MEMORY_DIR"/{user,rules,active,reference,archive}
    substitute_tpl "$TEMPLATES_DIR/MEMORY.md.tpl"               "$MEMORY_DIR/MEMORY.md"
    substitute_tpl "$TEMPLATES_DIR/memory/user-profile.md.tpl"  "$MEMORY_DIR/user/profile.md"
    substitute_tpl "$TEMPLATES_DIR/memory/rules-_INDEX.md.tpl"  "$MEMORY_DIR/rules/_INDEX.md"
    substitute_tpl "$TEMPLATES_DIR/memory/active-_INDEX.md.tpl" "$MEMORY_DIR/active/_INDEX.md"
    substitute_tpl "$TEMPLATES_DIR/memory/reference-_INDEX.md.tpl" "$MEMORY_DIR/reference/_INDEX.md"
else
    echo -e "  ${YELLOW}—${RESET} skipped (memory trunk is Claude Code specific)"
fi

# -------- Step 3 — Project-level CLI instructions file(s)
echo ""
echo -e "${CYAN}[3/7] CLI instructions file${RESET}"
case "$AI_CLI" in
    claude)
        substitute_tpl "$TEMPLATES_DIR/CLAUDE.md.tpl" "CLAUDE.md";;
    codex)
        substitute_tpl "$TEMPLATES_DIR/CLAUDE.md.tpl" "AGENTS.md";;
    gemini)
        substitute_tpl "$TEMPLATES_DIR/CLAUDE.md.tpl" "GEMINI.md";;
    all)
        substitute_tpl "$TEMPLATES_DIR/CLAUDE.md.tpl" "CLAUDE.md"
        substitute_tpl "$TEMPLATES_DIR/CLAUDE.md.tpl" "AGENTS.md"
        substitute_tpl "$TEMPLATES_DIR/CLAUDE.md.tpl" "GEMINI.md"
        echo -e "  ${GREEN}✓${RESET} multi-CLI files created (CLAUDE.md + AGENTS.md + GEMINI.md)"
        ;;
esac

# -------- Step 4 — docs/ tree
echo ""
echo -e "${CYAN}[4/7] docs/ tree${RESET}"
mkdir -p docs/{current,architecture,reference,protocols,waves,history}
substitute_tpl "$TEMPLATES_DIR/docs/INDEX.md.tpl"              "docs/INDEX.md"
substitute_tpl "$TEMPLATES_DIR/docs/current-_INDEX.md.tpl"     "docs/current/_INDEX.md"
substitute_tpl "$TEMPLATES_DIR/docs/architecture-_INDEX.md.tpl" "docs/architecture/_INDEX.md"
substitute_tpl "$TEMPLATES_DIR/docs/reference-_INDEX.md.tpl"   "docs/reference/_INDEX.md"
substitute_tpl "$TEMPLATES_DIR/docs/protocols-_INDEX.md.tpl"   "docs/protocols/_INDEX.md"
substitute_tpl "$TEMPLATES_DIR/docs/waves-_INDEX.md.tpl"       "docs/waves/_INDEX.md"
substitute_tpl "$TEMPLATES_DIR/docs/history-_INDEX.md.tpl"     "docs/history/_INDEX.md"

# -------- Step 5 — lessons/ seeds
echo ""
echo -e "${CYAN}[5/7] lessons/ seeds${RESET}"
mkdir -p lessons
substitute_tpl "$TEMPLATES_DIR/lessons/_INDEX.md.tpl" "lessons/_INDEX.md"
if [ -n "$DOMAINS_CSV" ]; then
    IFS=',' read -ra DOMAINS <<< "$DOMAINS_CSV"
    for d in "${DOMAINS[@]}"; do
        d_trim=$(echo "$d" | xargs)
        [ -n "$d_trim" ] && substitute_domain_tpl \
            "$TEMPLATES_DIR/lessons/domain-template.md.tpl" \
            "lessons/$d_trim.md" \
            "$d_trim"
    done
else
    echo -e "  ${YELLOW}—${RESET} no domains requested (seed later as needed)"
fi

# Also create .neuraltree/wiki/_INDEX.md stub if missing
mkdir -p .neuraltree/wiki
if [ ! -f ".neuraltree/wiki/_INDEX.md" ]; then
    cat > .neuraltree/wiki/_INDEX.md <<WIKI_EOF
---
name: ${PROJECT_NAME} wiki index
description: Compiled canonical docs, synthesized from lessons/ when a domain crosses 3 lessons.
type: wiki-index
last_verified: ${DATE}
---

# ${PROJECT_NAME} Wiki Index

Compiled via \`neuraltree_compile(topic, content, sources)\` when a lesson domain reaches 3+ entries.

## Pages

_None yet. Wikis compile at 3-lesson threshold._

## Related
- [../../lessons/_INDEX.md](../../lessons/_INDEX.md)

## Docs
- \`~/.claude/rules/neuraltree-protocol.md\` (if available)
WIKI_EOF
    echo -e "  ${GREEN}✓${RESET} .neuraltree/wiki/_INDEX.md"
fi

# -------- Step 6 — config files
echo ""
echo -e "${CYAN}[6/7] config files${RESET}"
substitute_tpl "$TEMPLATES_DIR/graphifyignore.tpl" ".graphifyignore"
substitute_tpl "$TEMPLATES_DIR/gitignore.tpl"      ".gitignore"
substitute_tpl "$TEMPLATES_DIR/env-example.tpl"    ".env.example"

# -------- Step 7 — tools bootstrap (gngm-init.sh)
# Non-fatal: scaffolding already succeeded; tool bootstrap failures (e.g. Ollama cold-start
# Graphiti seed timeout) don't roll back what we've already created.
echo ""
echo -e "${CYAN}[7/7] GNGM tools bootstrap${RESET}"
if [ -f "$SCRIPT_DIR/gngm-init.sh" ]; then
    if bash "$SCRIPT_DIR/gngm-init.sh"; then
        :
    else
        echo ""
        echo -e "  ${YELLOW}!${RESET} gngm-init.sh reported non-zero exit — continuing anyway"
        echo "       (Common cause: Ollama cold-start Graphiti seed timeout — re-run gngm-init.sh later)"
    fi
else
    echo -e "  ${YELLOW}—${RESET} gngm-init.sh not found at $SCRIPT_DIR — tools bootstrap skipped"
    echo "       Run it manually: bash docs/GNGM/scripts/gngm-init.sh"
fi

# -------- Final hygiene check
echo ""
echo -e "${CYAN}=== Hygiene check ===${RESET}"
if [ -f "$SCRIPT_DIR/gngm-hygiene-check.sh" ]; then
    bash "$SCRIPT_DIR/gngm-hygiene-check.sh" || true
fi

# -------- Summary
echo ""
echo -e "${GREEN}=== Scaffold complete ===${RESET}"
echo ""
echo "Next steps:"
echo "  1. Read docs/GNGM/docs/05-PROJECT-STRUCTURE.md (structure conventions)"
echo "  2. Read docs/GNGM/docs/06-WAVE-PROTOCOL.md (how waves run)"
echo "  3. Fill in your project's purpose in the CLI instructions file"
if [ "$MEMORY_TRUNK" = "on" ]; then
    echo "  4. Memory trunk auto-loads every Claude Code session from:"
    echo "     $MEMORY_DIR/MEMORY.md"
fi
echo "  5. Say 'GNGM' in chat to trigger the full protocol"
echo ""
echo "Idempotent: re-run this script safely — it won't clobber existing files."

#!/usr/bin/env bash
# GNGM Context-Hygiene Audit — diagnostic only, NEVER deletes
#
# Surveys per-project Claude Code surface across one or many projects and
# flags bloat that could tip the project over Anthropic's 529 Overloaded
# cliff. See protocols/CONTEXT-HYGIENE.md for the discipline this script
# supports.
#
# Usage:
#   bash docs/GNGM/scripts/gngm-context-audit.sh              # audit current dir
#   bash docs/GNGM/scripts/gngm-context-audit.sh ~/project    # audit specific project
#   bash docs/GNGM/scripts/gngm-context-audit.sh --all        # audit every project under $HOME
#   bash docs/GNGM/scripts/gngm-context-audit.sh --all --top  # show only the worst N=10
#
# Exit codes:
#   0  — all audited projects are within thresholds
#   1  — at least one project crossed a RED threshold (likely 529-prone)
#   2  — invocation error (bad args, no projects found)

set -u

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

# Thresholds (calibrated against 2026-05-25 newfin incident — see CONTEXT-HYGIENE.md)
CLAUDE_MD_YELLOW=15000      # bytes
CLAUDE_MD_RED=30000
SKILLS_YELLOW=10
SKILLS_RED=25
AGENTS_YELLOW=20
AGENTS_RED=50
COMMANDS_YELLOW=10
COMMANDS_RED=25

# --- Parse args ---
MODE="single"
TARGET="."
TOP_N=0

while [ $# -gt 0 ]; do
    case "$1" in
        --all)   MODE="all" ;;
        --top)   TOP_N=10 ;;
        --help|-h)
            sed -n '2,18p' "$0" | sed 's/^# //; s/^#//'
            exit 0
            ;;
        -*)
            echo "Unknown flag: $1" >&2
            exit 2
            ;;
        *)
            TARGET="$1"
            MODE="single"
            ;;
    esac
    shift
done

# --- Helper: audit a single project ---
# Sets globals: CL_BYTES SK_COUNT AG_COUNT_TOP AG_COUNT_NESTED CMD_COUNT FW_DIRS WORST_LEVEL
audit_project() {
    local dir="$1"
    CL_BYTES=0
    SK_COUNT=0
    AG_COUNT_TOP=0
    AG_COUNT_NESTED=0
    CMD_COUNT=0
    FW_DIRS=""
    WORST_LEVEL=0  # 0=green 1=yellow 2=red

    # CLAUDE.md / AGENTS.md / GEMINI.md — take the largest if multiple exist
    for cm in "$dir/CLAUDE.md" "$dir/AGENTS.md" "$dir/GEMINI.md"; do
        if [ -f "$cm" ]; then
            local s
            s=$(wc -c < "$cm" 2>/dev/null || echo 0)
            [ "$s" -gt "$CL_BYTES" ] && CL_BYTES=$s
        fi
    done

    # Project skills
    if [ -d "$dir/.claude/skills" ]; then
        SK_COUNT=$(find "$dir/.claude/skills" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    fi

    # Project agents — top-level + nested
    if [ -d "$dir/.claude/agents" ]; then
        AG_COUNT_TOP=$(find "$dir/.claude/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
        AG_COUNT_NESTED=$(find "$dir/.claude/agents" -name "*.md" 2>/dev/null | wc -l)
    fi

    # Project commands
    if [ -d "$dir/.claude/commands" ]; then
        CMD_COUNT=$(find "$dir/.claude/commands" -name "*.md" 2>/dev/null | wc -l)
    fi

    # Framework state dirs (presence + cumulative size)
    local fw_list=()
    for fd in .claude-flow .swarm .hive-mind .ruv-swarm .sparc; do
        if [ -d "$dir/$fd" ]; then
            local sz
            sz=$(du -sh "$dir/$fd" 2>/dev/null | cut -f1)
            fw_list+=("${fd}=${sz}")
        fi
    done
    # Use "-" as empty placeholder — bash IFS=$'\t' collapses consecutive tabs
    # so we can't have empty fields in the row format.
    if [ ${#fw_list[@]} -eq 0 ]; then
        FW_DIRS="-"
    else
        FW_DIRS="${fw_list[*]}"
    fi

    # Worst level
    [ "$CL_BYTES" -ge "$CLAUDE_MD_YELLOW" ] && WORST_LEVEL=1
    [ "$CL_BYTES" -ge "$CLAUDE_MD_RED" ] && WORST_LEVEL=2
    [ "$SK_COUNT" -ge "$SKILLS_YELLOW" ] && [ "$WORST_LEVEL" -lt 1 ] && WORST_LEVEL=1
    [ "$SK_COUNT" -ge "$SKILLS_RED" ] && WORST_LEVEL=2
    [ "$AG_COUNT_NESTED" -ge "$AGENTS_YELLOW" ] && [ "$WORST_LEVEL" -lt 1 ] && WORST_LEVEL=1
    [ "$AG_COUNT_NESTED" -ge "$AGENTS_RED" ] && WORST_LEVEL=2
    [ "$CMD_COUNT" -ge "$COMMANDS_YELLOW" ] && [ "$WORST_LEVEL" -lt 1 ] && WORST_LEVEL=1
    [ "$CMD_COUNT" -ge "$COMMANDS_RED" ] && WORST_LEVEL=2
    [ -n "$FW_DIRS" ] && [ "$WORST_LEVEL" -lt 1 ] && WORST_LEVEL=1
}

# --- Helper: color for a single metric ---
metric_color() {
    local val=$1 yellow=$2 red=$3
    if [ "$val" -ge "$red" ]; then echo -ne "${RED}"
    elif [ "$val" -ge "$yellow" ]; then echo -ne "${YELLOW}"
    else echo -ne "${GREEN}"
    fi
}

# --- Find projects to audit ---
PROJECTS=()
if [ "$MODE" = "single" ]; then
    if [ ! -d "$TARGET" ]; then
        echo "Not a directory: $TARGET" >&2
        exit 2
    fi
    # A project is a dir with either CLAUDE.md OR a .claude/ subdir
    if [ -f "$TARGET/CLAUDE.md" ] || [ -d "$TARGET/.claude" ] || [ -f "$TARGET/AGENTS.md" ]; then
        PROJECTS+=("$TARGET")
    else
        echo "No CLAUDE.md / AGENTS.md / .claude/ found in $TARGET" >&2
        exit 2
    fi
else
    # --all: find any project under $HOME with CLAUDE.md or .claude/
    # Exclude common non-project dirs to keep scan fast
    while IFS= read -r path; do
        # Strip the matched filename to get project root
        proj=$(dirname "$path")
        # Dedup
        if [[ ! " ${PROJECTS[*]:-} " =~ " ${proj} " ]]; then
            PROJECTS+=("$proj")
        fi
    done < <(find "$HOME" -maxdepth 4 \
        \( -name node_modules -o -name .venv -o -name .venv-graphify -o -name .git \
        -o -name __pycache__ -o -name .neuraltree -o -name graphify-out \) -prune -o \
        -name CLAUDE.md -print 2>/dev/null)

    if [ ${#PROJECTS[@]} -eq 0 ]; then
        echo "No projects found under $HOME" >&2
        exit 2
    fi
fi

# --- Audit each project ---
echo -e "${BOLD}=== GNGM Context-Hygiene Audit ===${RESET}"
echo -e "${DIM}Diagnostic only — this script never deletes anything.${RESET}"
echo -e "${DIM}See protocols/CONTEXT-HYGIENE.md for the discipline.${RESET}"
echo ""

# Collect rows, sort by worst level (red first), then by CLAUDE.md size
declare -a ROWS
for p in "${PROJECTS[@]}"; do
    audit_project "$p"
    # row format: worst_level<TAB>cl_bytes<TAB>sk_count<TAB>ag_top<TAB>ag_nested<TAB>cmd<TAB>fw_dirs<TAB>path
    ROWS+=("${WORST_LEVEL}	${CL_BYTES}	${SK_COUNT}	${AG_COUNT_TOP}	${AG_COUNT_NESTED}	${CMD_COUNT}	${FW_DIRS}	${p}")
done

# Sort by worst_level desc, then cl_bytes desc
IFS=$'\n' SORTED=($(printf '%s\n' "${ROWS[@]}" | sort -t$'\t' -k1,1nr -k2,2nr))
unset IFS

# Apply --top
if [ "$TOP_N" -gt 0 ] && [ ${#SORTED[@]} -gt "$TOP_N" ]; then
    SORTED=("${SORTED[@]:0:$TOP_N}")
    echo -e "${DIM}Showing worst ${TOP_N} of ${#PROJECTS[@]} projects (use without --top to see all).${RESET}"
    echo ""
fi

# --- Print table ---
printf "%-40s %10s %7s %7s %10s %5s\n" "PROJECT" "CLAUDE.md" "SKILLS" "AGENTS" "AG-NESTED" "CMDS"
printf "%-40s %10s %7s %7s %10s %5s\n" "----------------------------------------" "----------" "-------" "-------" "----------" "-----"

any_red=0
for row in "${SORTED[@]}"; do
    IFS=$'\t' read -r lvl cl sk agt agn cm fw path <<< "$row"
    [ "$lvl" -ge 2 ] && any_red=1

    # Trim path for display
    short=$(echo "$path" | sed "s|^$HOME|~|")
    display=$short
    [ ${#display} -gt 40 ] && display="…${display: -39}"

    # Color metrics
    cl_color=$(metric_color "$cl" "$CLAUDE_MD_YELLOW" "$CLAUDE_MD_RED")
    sk_color=$(metric_color "$sk" "$SKILLS_YELLOW" "$SKILLS_RED")
    agn_color=$(metric_color "$agn" "$AGENTS_YELLOW" "$AGENTS_RED")
    cm_color=$(metric_color "$cm" "$COMMANDS_YELLOW" "$COMMANDS_RED")

    # Format CLAUDE.md bytes as KB
    cl_kb=$(awk "BEGIN { printf \"%.0fK\", $cl/1024 }")

    printf "%-40s ${cl_color}%10s${RESET} ${sk_color}%7s${RESET} %7s ${agn_color}%10s${RESET} ${cm_color}%5s${RESET}\n" \
        "$display" "$cl_kb" "$sk" "$agt" "$agn" "$cm"

    # Print framework dirs on a sub-line if present (placeholder "-" means none)
    if [ -n "$fw" ] && [ "$fw" != "-" ]; then
        echo -e "  ${YELLOW}↳ framework state:${RESET} $fw"
    fi
done

echo ""
echo -e "${BOLD}=== Thresholds ===${RESET}"
echo -e "  CLAUDE.md:  ${GREEN}<${CLAUDE_MD_YELLOW}B${RESET}  ${YELLOW}${CLAUDE_MD_YELLOW}-${CLAUDE_MD_RED}B${RESET}  ${RED}>=${CLAUDE_MD_RED}B${RESET}"
echo -e "  SKILLS:     ${GREEN}<${SKILLS_YELLOW}${RESET}     ${YELLOW}${SKILLS_YELLOW}-${SKILLS_RED}${RESET}      ${RED}>=${SKILLS_RED}${RESET}"
echo -e "  AG-NESTED:  ${GREEN}<${AGENTS_YELLOW}${RESET}    ${YELLOW}${AGENTS_YELLOW}-${AGENTS_RED}${RESET}     ${RED}>=${AGENTS_RED}${RESET}"
echo -e "  CMDS:       ${GREEN}<${COMMANDS_YELLOW}${RESET}    ${YELLOW}${COMMANDS_YELLOW}-${COMMANDS_RED}${RESET}     ${RED}>=${COMMANDS_RED}${RESET}"
echo ""

if [ "$any_red" -eq 1 ]; then
    echo -e "${RED}${BOLD}⚠ At least one project crossed a RED threshold.${RESET}"
    echo ""
    echo "If that project is hitting 529 Overloaded errors:"
    echo "  1. Read protocols/CONTEXT-HYGIENE.md → 'Safe to delete vs danger zone'"
    echo "  2. Run the step-3 reference check (grep for framework refs in project code)"
    echo "  3. rm -rf only the framework dirs that have ZERO project-code references"
    echo ""
    exit 1
fi

echo -e "${GREEN}All audited projects within thresholds.${RESET}"
exit 0

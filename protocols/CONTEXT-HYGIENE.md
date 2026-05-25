---
name: CONTEXT-HYGIENE — Keep per-project Claude Code surface small
description: Hard rule against letting per-project `.claude/` directories accumulate framework dumps (claude-flow, SPARC, swarm libraries, abandoned skill installs). A bloated per-project surface inflates the system prompt, blows the prompt cache on every miss, and tips requests over Anthropic's 529 Overloaded cliff while same-account neighboring projects work fine. Codified after a real incident where one project (~2.4 MB of project-local descriptors) 529'd consistently while four other projects on the same account did not.
type: gngm-protocol
version: 1
last_verified: 2026-05-25
trigger: self-applied when 529s appear on one project but not others, when installing meta-frameworks into `.claude/`, monthly per-project audit
---

# CONTEXT-HYGIENE — Keep per-project Claude Code surface small

> **Status:** Hard rule. Codified 2026-05-25 after a real-user incident.
> **Scope:** Any project where Claude Code loads `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, or has a `CLAUDE.md` that accreted over many waves.

## The incident (concrete reference case)

2026-05-25, `newfin` project. Every session opened on `newfin` failed with:

```
API Error: 529 Overloaded
```

Four sibling projects on the same Anthropic account (`CheckComputer`, `winacard`, `LocalizationTools`, others) worked fine in the same window. The pattern survived restarts, model swaps, and time of day.

Per-project context surface measured:

| Project | `CLAUDE.md` | Project skills | Project agents | Framework dirs |
|---|---|---|---|---|
| CheckComputer | 5 KB | 0 | 0 | — |
| winacard | 10 KB | 0 | 0 | — |
| LocalizationTools | 13 KB | 19 | 34 | — |
| **newfin** | **28 KB** | **30 (486 KB)** | **98 nested .md** | **`.claude-flow/`, `.swarm/`, `.hive-mind/`** |

`newfin` had **claude-flow / SPARC / hive-mind** installed at some earlier point. The framework added 30 project-local skills (`v3-*`, `agentdb-*`, `swarm-*`, `sparc-*`, `github-*`), 23 nested agent subdirectories totalling 98 `.md` files, a 492 KB `commands/` tree, and three runtime state dirs (`.claude-flow/`, `.swarm/`, `.hive-mind/`). Zero files in the project's own source code referenced any of it. Last touched: 1-2+ months stale.

Fix: `rm -rf .claude-flow .swarm .hive-mind .claude/skills .claude/agents .claude/commands`. ~6 MB on disk gone, **~1.9 MB of descriptor text removed from every API call**. 529s stopped immediately on the next session.

## Why this hurts (the danger)

Bloat in `.claude/` is silent — there is no per-session log of "your prompt is now 3× the size of your other projects." It only surfaces when something downstream breaks. The failure modes:

1. **529 Overloaded on the bloated project only.** Larger requests cost more compute per turn and get shed first when Anthropic's capacity is constrained. The threshold is binary, not gradual — same account, same hour, same model, only the fat project falls off the cliff.
2. **Cold-start tax on every cache miss.** Anthropic's prompt cache TTL is 5 minutes. Every session start, every `/compact`, every 5-minute idle window re-pays the full descriptor cost. Bloated projects pay 3-10× the cold-start that lean projects pay.
3. **Cache thrash within a session.** Long conversations push older context out of the rolling cache window. Bloated system prompts mean less room for actual work context before thrash starts.
4. **Debugging blind alley.** The user thinks the API is broken ("only this project 529s — must be a regional issue?"). Hours can be lost before anyone audits the per-project surface.
5. **Trust decay in the tooling.** A user who hits 529s repeatedly stops trusting Claude Code; a user who finds out it was their own `.claude/` dir wonders why the tool didn't warn them.

None of these are speculative — all five showed up in the `newfin` incident. The danger of bloat is that you don't see it accumulating; you only see the explosion.

## What lives in `.claude/` and what actually loads

| File / dir | Loaded into prompt? | Who put it there? | Audit priority |
|---|---|---|---|
| `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` | **Fully loaded** every turn | You / GNGM scaffold | HIGH — watch size |
| `MEMORY.md` (auto-memory trunk) | **Fully loaded** every turn | Claude Code's memory system | HIGH — keep trunk thin |
| `.claude/skills/<name>/SKILL.md` | Frontmatter advertised; body on invoke | You OR a framework installer | MEDIUM — count matters |
| `.claude/agents/<name>.md` (+ nested) | Frontmatter advertised; body on spawn | You OR a framework installer | MEDIUM — count matters |
| `.claude/commands/<name>.md` | Loaded on invoke; advertised by name | You OR a framework installer | MEDIUM — count + size |
| `.claude/settings.json` / `settings.local.json` | Config only, NOT prompt | You | LOW — don't touch |
| `.claude/memory.db` | Claude Code internal | Claude Code | LOW — don't touch |
| `.claude/projects/` | Session storage, NOT prompt | Claude Code | LOW — disk only |
| `.claude/hooks/` | Hook scripts; their **output** injects into prompt | You / framework | HIGH if any hook dumps large output |
| `.claude-flow/`, `.swarm/`, `.hive-mind/` etc. | NOT prompt (runtime state) | Framework installers | MEDIUM — disk + signal of forgotten framework |

The dominant prompt-budget consumers are: (a) `CLAUDE.md` body size, (b) count of advertised skills/agents (each gets a one-line description in the system prompt), (c) any auto-loaded commands, (d) hook output that fires on `SessionStart` / `UserPromptSubmit`.

## The rules — by scenario

| Scenario | Action |
|---|---|
| One project 529s while sibling projects don't | Run the audit (see below). Treat as bloat until proven otherwise. |
| About to install a meta-framework into `.claude/` (claude-flow, SPARC, swarm libs, agent zoos) | First measure current `.claude/` size + skill/agent count. Re-measure after install. Decide *then* whether the surface increase is worth it. |
| Framework was tried and abandoned | `rm -rf` its install dirs (both `.claude/<framework-stuff>/` AND root-level `.framework-name/` state dirs). Verify zero project-code references first. |
| Skill/agent in `.claude/` has zero references from project code AND has not been invoked in 30+ days | Delete. The global version (if any) is enough. |
| Skill/agent in `.claude/` IS referenced by project code (imports, scripts, hooks) | **LEAVE.** It is in use. |
| `CLAUDE.md` exceeds 25 KB | Audit for redundant context. Move stable facts to `memory/reference/` branches; keep trunk lean. |
| `CLAUDE.md` exceeds 50 KB | Treat as urgent — split using `IMPROVE-ARCHITECTURE` discipline. |
| New project | Do NOT pre-install meta-frameworks "just in case." Install per-need. |
| Monthly cadence (or after every major wave) | Run the audit for every project under `~/`. |

## The audit pattern

For any single project (run from project root):

```bash
# 1. Size the per-project Claude Code surface
echo "=== CLAUDE.md ==="; wc -c CLAUDE.md AGENTS.md GEMINI.md 2>/dev/null
echo "=== .claude/ contents ==="; du -sh .claude/* 2>/dev/null
echo "=== Framework state dirs ==="; du -sh .claude-flow .swarm .hive-mind .ruv* 2>/dev/null

# 2. Inventory skills/agents/commands
echo "=== Project skills ==="; ls .claude/skills/ 2>/dev/null | wc -l
echo "=== Project agents (top-level + nested) ==="
ls .claude/agents/*.md 2>/dev/null | wc -l
find .claude/agents -name "*.md" 2>/dev/null | wc -l
echo "=== Project commands ==="; find .claude/commands -name "*.md" 2>/dev/null | wc -l

# 3. CRITICAL — verify zero project-code references before deletion
grep -rl "\.claude-flow\|claude_flow\|hive-mind\|ruv-swarm\|sparc" \
  --include="*.py" --include="*.sh" --include="*.js" --include="*.ts" \
  --include="*.yaml" --include="*.yml" --include="*.json" 2>/dev/null \
  | grep -v "^\.claude" | grep -v "^node_modules" | head -20
# Empty output = nothing in project code uses it = safe to delete.
# Any output = investigate before touching.

# 4. Compare to a known-lean sibling project on the same machine
for p in ~/lean-project ~/this-project; do
  echo "--- $(basename $p) ---"
  [ -f "$p/CLAUDE.md" ] && wc -c "$p/CLAUDE.md"
  echo "skills: $(ls "$p/.claude/skills" 2>/dev/null | wc -l)"
  echo "agents: $(ls "$p/.claude/agents" 2>/dev/null | wc -l)"
done
```

If a project is ≥2× a known-lean sibling on any axis (CLAUDE.md size, skill count, agent count) AND has framework dirs in the root → bloat suspect. Run step 3 to confirm safe-to-delete, then `rm -rf`.

The companion script `scripts/gngm-context-audit.sh` runs this for every project under `~/` and prints a sortable table.

## When to run the audit

| Trigger | Cadence | Action level |
|---|---|---|
| 529s on one project but not siblings | Immediate | Drop everything, audit, fix |
| About to install a meta-framework | Before AND after install | Measure delta; decide if it's worth it |
| Slow Claude Code cold-start on a specific project | Within the session | Quick audit; defer fix if not blocking |
| Monthly per-project sweep | First of the month | Routine — combine with GIT-HYGIENE monthly review |
| After a wave that touched `.claude/` | Same session | One-liner sanity check |
| Found an abandoned framework on disk | When discovered | Delete after reference check |

## Safe to delete vs danger zone

**Safe to delete** (provided step 3 above confirms zero project-code references):

- `.claude-flow/`, `.swarm/`, `.hive-mind/`, `.ruv-swarm*/` and similar framework runtime dirs at the project root
- `.claude/skills/<framework-name>-*` directories from frameworks you abandoned
- `.claude/agents/<framework-name>/` subdirectories (whole subtrees) from abandoned frameworks
- `.claude/commands/<framework-name>/` subdirectories
- Top-level `.claude/commands/*.md` files whose name announces a framework (e.g. `claude-flow-*.md`)
- Stale `.claude/skills/<name>/` last touched 90+ days ago that you never invoke

**Danger zone — verify each individually before touching:**

- Anything you (the user) wrote yourself in `.claude/skills/` or `.claude/agents/`
- `.claude/rules/*.md` — project-specific behavioral rules
- `.claude/settings.json` and `.claude/settings.local.json` — permission allowlists, hook config
- `.claude/memory.db`, `.claude/projects/` — Claude Code internal state
- `.claude/hooks/` — if hooks exist, they have side effects; delete only with full understanding
- `CLAUDE.md` itself — never delete; trim by moving content to `memory/` branches

**Never delete without investigation:**

- Any directory under `.claude/` that you don't recognize. Apply `IMPROVE-ARCHITECTURE` reading discipline first — investigate, then act.

## GNGM's own posture (design note)

GNGM installs into `<project>/docs/GNGM/`. It does **not** install anything into `<project>/.claude/`. This is deliberate. A knowledge-stack protocol that itself bloats the prompt would be embarrassing — and it would make CONTEXT-HYGIENE auto-violating.

If a future GNGM release ever needs to add a per-project skill or agent, it must justify the cost in the release notes and provide an opt-out flag in the scaffold script. The current rule: GNGM stays out of `.claude/`.

The user's own `CLAUDE.md` (created by GNGM's scaffold) is the only file GNGM touches that loads into every prompt. The scaffold's template is intentionally compact (~150 lines) and structured as a trunk-index pointing to `memory/` branches — not a dump of content.

## Anti-patterns

- ❌ Installing a meta-framework "to try it out" and forgetting to remove it. Frameworks compound: each install adds another 0.5-2 MB of `.claude/` surface.
- ❌ Treating 529 errors as "Anthropic's problem." If one of your projects 529s and others don't, the asymmetry is on your side, not theirs.
- ❌ Letting `CLAUDE.md` grow unbounded across waves. Use trunk-index + branches (per `organization-master.md` style); keep the trunk under 25 KB.
- ❌ Auto-loading every skill you have ever found interesting. Globals (`~/.claude/skills/`) load for ALL projects — be selective there too.
- ❌ Hooks that dump multi-KB output on every `SessionStart` or `UserPromptSubmit`. Hooks fire silently every turn; their output goes into the prompt. Audit hook output size, not just script existence.
- ❌ Deleting `.claude/` content without the step-3 reference check. If project code imports from it, you will break the project, not just slim it.

## Related

- [VRAM-HYGIENE.md](VRAM-HYGIENE.md) — sister hygiene protocol; same shape, different finite resource (GPU memory)
- [GIT-HYGIENE.md](GIT-HYGIENE.md) — sister hygiene protocol; everyday-discipline pattern
- [IMPROVE-ARCHITECTURE.md](IMPROVE-ARCHITECTURE.md) — use its read-before-delete posture for any unfamiliar `.claude/` content
- [NLF.md](NLF.md) — when investigating bloat, root-cause discipline applies (it's the framework dump, not "Anthropic's flaky")
- [`../docs/02-PROTOCOL.md`](../docs/02-PROTOCOL.md) §"Anti-patterns" — pointer back to this file

## Docs

- [Anthropic API errors reference](https://docs.anthropic.com/en/api/errors) — 529 Overloaded definition
- [Claude Code skills documentation](https://docs.anthropic.com/en/docs/claude-code) — what loads from `.claude/skills/` and how
- `~/.claude/settings.json` — global-level skill/agent inventory contributes baseline cost before per-project surface is added
- Companion script (planned): `scripts/gngm-context-audit.sh` — sortable per-project bloat report

## Changelog

- 2026-05-25 — v1. Codified after `newfin` 529 incident: 30 project skills + 23 nested agent dirs + 492 KB commands tree + three framework runtime dirs (`.claude-flow/`, `.swarm/`, `.hive-mind/`) accumulated from an abandoned claude-flow install. `rm -rf` of all six removed ~6 MB on disk and ~1.9 MB of system-prompt surface; 529s stopped on the next session. Four sibling projects on the same account had never been affected.

# GIT-SAFETY — Do Not Destroy Git History

> A single `git push --force` can annihilate someone's life work.
> This protocol codifies the defenses. Learned the hard way, 2026-04-18.
>
> **Sibling protocol: [GIT-HYGIENE.md](GIT-HYGIENE.md).** GIT-SAFETY defends against catastrophes (force-push, silent restore, hard reset). GIT-HYGIENE codifies the daily commit/push discipline that means catastrophes have nothing to destroy. Both required — neither alone is enough.

## The incident that forged this protocol

On 2026-04-18, a "confused" Claude Code session force-pushed an `Initial commit` (April 2025, just 1 line of README) over a working repository's `main` branch. **All 20+ commits of Phase 33 production work got wiped from the remote in a single command.**

The ONLY reason nothing was permanently lost: **the originating user's local disk still had the `.git/` reflog.** Had their laptop died / been stolen / had a disk failure within the ~90-day reflog window, months of work would have been irrecoverable.

A few hours later, while installing a protective pre-push hook, the author of this doc **force-pushed an older commit over another repo's `main`** during hook testing, because the hook had a silent bug (git-lfs consumed stdin before the force-check could run). Second near-miss, same day.

Both incidents recovered. Both were 60 seconds from catastrophe if a drive had failed at the wrong moment. **That fragility is the problem.**

## The absolute rules

### 1. NEVER force-push to a protected branch as a test

"I just want to see if the hook works" is how I nearly destroyed LocalizationTools' main history. **If you need to test a hook, push to a throwaway branch:**

```bash
# WRONG — tests a hook by actually destroying main's history
git push origin HEAD~1:main --force

# RIGHT — tests a hook on a branch nothing cares about
git push origin HEAD~1:refs/heads/hook-test --force
git push origin --delete hook-test    # cleanup
```

### 2. Pre-push hooks that come AFTER git-lfs do nothing

`git lfs pre-push` consumes stdin. Any force-push check in the same hook script that reads stdin after it will see an empty stream and silently allow the push.

**Fix:** capture stdin to a tempfile, run your check on the captured copy, then replay to LFS:

```sh
TMPFILE=$(mktemp)
cat > "$TMPFILE"

# Run force-push check using captured stdin
while read local_ref local_sha remote_ref remote_sha; do
    # ... your safety check ...
done < "$TMPFILE"

# Replay captured stdin to LFS
git lfs pre-push "$@" < "$TMPFILE"
rm -f "$TMPFILE"
```

Reference implementation: `scripts/gngm-init.sh` installs a tested stdin-safe hook.

### 3. Remotes are NOT backups

When a force-push removes commits from a remote:

- The old commits become unreferenced on the server
- `git fetch` CANNOT retrieve them — fetch only sees ref-reachable objects
- GitHub keeps internal logs ~90 days but access requires support tickets
- Gitea retention depends on `git gc` config

**The only reliable recovery paths are:**

1. Your local `.git/` reflog (~30-90 days depending on config)
2. Another clone's local `.git/`
3. An offline backup (tar, rsync, CI mirror)

If your laptop dies the same day as the force-push, you have none of these.

### 4. Dual-remote push is a real defense — use it

Two independently-hosted remotes (e.g., GitHub + self-hosted Gitea / GitLab / Bitbucket) means a force-push to one does not touch the other.

```bash
# Push to both after every significant commit
git push origin main && git push secondary main
```

Even if both get force-pushed by the same confused process, they'd need to be force-pushed identically within the same window. Two mistakes of identical magnitude in seconds is dramatically less likely than one.

### 5. Install a pre-push hook that blocks force-push to main/master

Default behavior: `git push --force origin main` should BLOCK with a loud error. Override requires `ALLOW_FORCE=1`:

```bash
ALLOW_FORCE=1 git push --force origin main
```

The override is deliberate friction — you must type it. No autopilot destruction.

Reference hook shipped with GNGM: see `scripts/gngm-init.sh`. Copy to `.git/hooks/pre-push`, `chmod +x`, done.

### 6. For every destructive operation — tar `.git/` first

A 10-second tarball is cheap insurance:

```bash
mkdir -p ~/.git-backups
tar czf ~/.git-backups/<project>-$(date +%Y%m%d-%H%M).tar.gz .git/
```

Do this BEFORE:
- Any force-push
- Any `git reset --hard`
- Any `git filter-branch` / `git filter-repo`
- Any rebase that drops commits
- Any BFG repo cleaner run
- Removing a remote
- Trying a destructive "cleanup" command you read about on Stack Overflow

### 7. GitHub Pro is $4/month. Worth it for private repos

GitHub's **branch protection rules** on `main` with "Do not allow force pushes" enabled is a server-side guarantee that client-side hooks cannot provide. Available on public repos for free; private repos require Pro.

For any private repo that holds >1 week of meaningful work, $4/month to protect against your own mistakes (and anyone else's) is cheap.

### 8. NEVER ignore "forced-update" in fetch output

```
+ abc1234...def5678 main -> origin/main  (forced update)
```

If you see this and didn't initiate it, STOP. Someone or something force-pushed. Investigate before doing anything else. Do not reflexively `git pull` — that could merge the wrong state into your local.

Check: `git reflog refs/remotes/origin/main` for the history of remote-ref positions. The last `update by push` entry shows the state before the force-push — that's probably the state you want to restore to.

### 9. Never blindly trust another tool / agent / session to have done git safely

If another Claude session, another developer, an automation script, or a CI workflow touches your remote — **verify before you build on top**. A confused tool can destroy in one command what took a year to build.

Quick verification on session start:

```bash
git fetch
git log --oneline origin/main...HEAD    # should be empty (up-to-date) OR your new commits only
git reflog refs/remotes/origin/main | head -5    # should show "update by push", not "forced-update"
```

### 10. Emotional calibration — your panic is data

If discovering a force-push makes your heart race and hands shake, **that is appropriate**. Git history loss is a real, often-irreversible trauma. Do not let a chat partner (human or AI) rush you past that feeling. Pause. Take the backup. Investigate with your guard up.

The worst recovery mistakes happen in the 5 minutes right after the panic peaks, when relief makes you sloppy.

## The second incident that forged rules 11-13

On 2026-04-25, during a successful Phase G Wave G6 Task G.6.5 ship (4 commits dual-pushed clean), a coder subagent dispatched mid-task ran `git restore` (or `git checkout --`) on the working tree. This silently overwrote **8 files of pre-existing uncommitted user WIP**: 6 Svelte frontend files (viewport-clamp + wiring fixes), `.claude/scheduled_tasks.lock`, and 2 lesson edits. The user had explicitly noted these in the prior handoff as "leave alone."

`git restore` and `git checkout -- <file>` operations on the working tree do NOT appear in the reflog. There was no warning, no panic moment, no "forced-update" notification. The loss only became visible when comparing the post-session `git status` to the pre-session `git status` and finding the modified-marker (`M`) files all gone — silently reverted to HEAD.

Recovery exhausted: git fsck found no dangling blobs with the lost content. NeuralTree backup was 4 days stale. Cursor history was a year stale. No IDE-specific local-history dirs existed for the project. Gitea had only what was pushed (no WIP). **Permanent loss of ~6 hours of frontend WIP.**

Forensic signature: 10 files with **identical mtime to the nanosecond** (`2026-04-25 16:08:44.531789065`) — a `git restore <multiple-files>` runs in a single syscall batch and writes them all simultaneously. If you ever see identical-nanosecond mtimes across files in your working tree, an agent / hook / tool used a multi-file working-tree-modifying git command.

Force-push (rules 1-10) is the loud catastrophe. Working-tree restore is the silent one. Both warrant defenses.

### 11. Agent briefs MUST forbid working-tree-modifying git ops on out-of-scope files

When dispatching a coder / fixer / refactor agent, the brief MUST include this absolute rule:

> **DO NOT run any of the following on files OUTSIDE your scope:**
>   - `git restore <file>` / `git restore --staged --worktree <file>`
>   - `git checkout -- <file>` / `git checkout HEAD <file>`
>   - `git reset --hard` / `git reset HEAD --hard`
>   - `git clean -fd` / `git clean -fdx`
>   - `git stash drop` (unless YOU created the stash in this session)
>
> **If you encounter pre-existing uncommitted modifications, leave them EXACTLY as you found them.** Do not "clean up" the working tree. Do not run `git checkout` on a file you didn't intend to modify. Do not assume `git status` should be clean before/after your work.
>
> Your scope is the files explicitly named in your brief. Anything else is the user's WIP — sacred, off-limits, untouchable.

The brief must also enumerate the EXACT files the agent is allowed to touch. Anything not in that list = out-of-scope = touchable only via Read.

### 12. Always `git stash --include-untracked` before dispatching a working-tree-modifying agent

Belt-and-suspenders defense. Even with rule 11 in the brief, an agent might still slip. **Pre-flight: stash everything.** Post-flight: pop.

```bash
# Wrapper script — invoke this BEFORE any coder agent dispatch
git stash push --include-untracked --message "agent-autostash-$(date +%Y%m%d-%H%M%S)"
PRE_STASH_REF=$(git rev-parse stash@{0})

# ... dispatch agent here ...

# Post-flight: restore the user's WIP
git stash pop --quiet
# If pop conflicts (agent committed something that touched the same file),
# DO NOT auto-resolve — surface the conflict to the user.
```

**Why this works:** if the agent runs `git restore` mid-dispatch, it restores from HEAD (which doesn't have the WIP). After the agent returns, `git stash pop` re-applies the WIP on top of any agent commits. If the agent's commits conflict with the WIP, the user gets a normal merge-conflict to resolve — much better than silent loss.

**Why some teams won't do this:** stash conflicts can be annoying. The annoying conflict IS the alarm — it tells you the agent touched something it shouldn't have. Without the stash, that alarm doesn't fire.

Reference implementation: `scripts/agent_autostash.sh` ships with this protocol. See it for the full conflict-handling logic.

### 13. Post-flight: verify working tree matches your pre-flight expectation

After every agent return, **before** committing or moving on:

```bash
# Pre-flight: capture the state
git status --short > /tmp/pre-agent-status.txt
git ls-files --modified --others --exclude-standard | sort > /tmp/pre-agent-files.txt

# ... dispatch agent ...

# Post-flight: diff the state lists
git status --short > /tmp/post-agent-status.txt
git ls-files --modified --others --exclude-standard | sort > /tmp/post-agent-files.txt

# What changed?
diff /tmp/pre-agent-status.txt /tmp/post-agent-status.txt
# Any line REMOVED from the post-list = a file that was modified pre-agent but is no longer modified post-agent.
# That's a smoking gun — the agent reverted user WIP.
diff /tmp/pre-agent-files.txt /tmp/post-agent-files.txt
```

If you see lines disappearing from the modified-files list (without a corresponding commit by the agent that included them), STOP. The agent reverted user WIP. Investigate before doing anything else. Check `git fsck --lost-found` immediately while the dangling blobs are still fresh in `.git/objects/`.

**Identical-nanosecond mtimes are a forensic tell.** Run:
```bash
stat -c "%y %n" <suspect-files> | sort
```
If multiple files show the same nanosecond timestamp, a multi-file git op (likely `git restore <files>`) hit them. Match the timestamp to your reflog + Bash tool history to find the offending command.

## Summary — the 13 rules

### Force-push catastrophes (1-10)
1. Never force-push to main as a "test"
2. Pre-push hooks after git-lfs silently fail unless you fix stdin consumption
3. Remotes are not backups — your local reflog is the primary safety net
4. Dual-remote push is a real, independent defense
5. Install a pre-push hook that blocks force-push without `ALLOW_FORCE=1`
6. Tar `.git/` before any destructive operation
7. GitHub Pro is $4/month — worth it for private repos
8. Investigate "forced-update" in fetch output — don't `git pull`
9. Verify git state before trusting another agent/session's work
10. Your panic is appropriate — don't let anyone rush you past it

### Working-tree silent-loss (11-13, added 2026-04-25)
11. Agent briefs MUST forbid `git restore` / `git checkout --` / `git reset` / `git clean` on out-of-scope files
12. ALWAYS `git stash --include-untracked` before dispatching ANY coder agent (autostash + auto-pop)
13. Post-flight: diff `git status --short` pre vs post-agent — disappearing modified-files = silent revert

## Related

- [NLF.md](NLF.md) — No Lie Fix (lie-fixes and bandages forbidden — this applies to git recovery too)
- [SDP.md](SDP.md) — Standard Development Protocol
- GNGM `04-LESSONS.md` — 9 pitfalls + resilience patterns
- `scripts/gngm-init.sh` — installs the stdin-safe pre-push hook referenced here

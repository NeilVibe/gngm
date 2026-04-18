# GIT-SAFETY — Do Not Destroy Git History

> A single `git push --force` can annihilate someone's life work.
> This protocol codifies the defenses. Learned the hard way, 2026-04-18.

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

## Summary — the 10 rules

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

## Related

- [NLF.md](NLF.md) — No Lie Fix (lie-fixes and bandages forbidden — this applies to git recovery too)
- [SDP.md](SDP.md) — Standard Development Protocol
- GNGM `04-LESSONS.md` — 9 pitfalls + resilience patterns
- `scripts/gngm-init.sh` — installs the stdin-safe pre-push hook referenced here

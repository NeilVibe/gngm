# GIT-HYGIENE — Everyday Commit + Push Discipline

> Sibling to [GIT-SAFETY.md](GIT-SAFETY.md). GIT-SAFETY defends against catastrophes (force-push, agent silent-restore). GIT-HYGIENE is the daily discipline that means catastrophes have nothing to destroy.
>
> Forged 2026-04-25 after 6 hours of frontend WIP died in a silent `git restore` because it had been uncommitted for too many sessions.

## The core insight

Git tracks 4 layers of durability. **Each layer up = harder to lose work:**

```
Layer 1: Working tree (files on disk)
   ↓ ZERO backup. Overwrite = gone forever. No reflog. No undo.
Layer 2: Index (staged: git add)
   ↓ Recoverable from reflog ~30-90 days IF you committed at some point.
Layer 3: Local repo (committed: git commit)
   ↓ Reflog protects against reset/rebase mistakes for ~30-90 days.
Layer 4: Remote (pushed: git push)
   ↓ Distributed copy. Survives disk crash + accidental local destruction.
```

**Most lost work lives at layer 1.** Working-tree changes have no automatic backup — not via git, not via your filesystem, not via your IDE (most don't auto-snapshot), not via any tool you didn't explicitly install.

The only way to move work UP the layers is to do it yourself: `git add` → `git commit` → `git push`. Each step costs <5 seconds. **Skipping them is renting your work from the disk gods.**

## The 10 rules

### 1. Commit on every natural pause

Triggers that mean "commit now":
- About to context-switch (different feature, different file, different problem)
- About to take a break (lunch, walking, sleep, weekend)
- About to dispatch an agent (especially one with `Bash` access)
- About to run a destructive command (`reset`, `rebase`, `clean`, `stash drop`)
- A test just went GREEN
- A test just went RED in a way you want to remember
- You changed your mind about an approach (commit the abandoned approach BEFORE pivoting — your future self might want it)
- 30-60 minutes have passed since your last commit

These are NOT triggers requiring "is this commit-worthy?" deliberation. **Hit any trigger → commit → keep going.**

### 2. WIP commits are normal — make them ugly and prolific

The shame around "messy commit history" kills more work than messy history ever caused. **WIP commits are insurance, not vandalism.**

```bash
git commit -m "wip: viewport-clamp + wiring (mid-debug)"
git commit -m "wip: trying approach B — A didn't work"
git commit -m "wip: pause for lunch, currently broken"
git commit -m "wip: half of TMExplorer wiring done"
```

You can always squash later with `git rebase -i HEAD~N` before merging to main / opening a PR. **Squashing a clean line of WIP commits takes 90 seconds. Recovering deleted WIP takes ∞.**

### 3. Push WIP at end of every focused work session

Every time you finish a chunk of focused work (an hour, a session, before bed):

```bash
git push origin HEAD:wip/<topic>
```

A WIP branch on the remote is full disaster insurance: laptop dies, drive corrupts, agent runs `git reset --hard`, doesn't matter — your work is on someone else's hardware. WIP branches are cheap (delete them later). Push aggressively.

For solo projects: `git push origin main` works too if you don't fear half-broken commits on main. Many solo workflows commit-and-push messy WIP to main + clean up at PR time.

### 4. Untracked files are also vulnerable — `git add` them or accept their volatility

`git status` lines starting with `??` are NEW files git doesn't know about. They are NOT in any backup, and `git stash` (without `--include-untracked`) ignores them.

If you create a new file and want it protected:

```bash
git add path/to/new-file.svelte
git commit -m "wip: scaffold new component"
```

Or commit the placeholder version even if it's just an empty stub. The first commit is the safety net; subsequent edits ride on top of reflog.

### 5. Atomic commits per logical change (TDD discipline)

When working with TDD:

```bash
# Red phase
git commit -m "test: failing test for <behavior>"

# Green phase
git commit -m "feat: <behavior> implementation"

# Refactor phase
git commit -m "refactor: tidy <behavior> internals (no behavior change)"
```

Three small commits beat one large commit because:
- Bisect can find the broken commit in O(log N)
- Revert can undo just the broken phase
- Code review can focus on one logical change at a time
- WIP within a phase is safe even if a later phase fails

### 6. Treat `M` in `git status` as "volatile, not safe"

The `M` flag means "your file differs from HEAD." It is a comparison, not a save state. **Never carry `M` files across multiple sessions thinking they're "saved."**

If you find yourself with `M` files at the end of a session:

- **Decide:** is this work valuable enough to keep? If yes → commit. If no → `git restore <file>` deliberately.
- **Don't punt.** Punting today becomes punting tomorrow becomes lost work the day after.
- The "leave alone" instruction in handoffs is a YELLOW FLAG. It means "I haven't decided yet" — and indecision is how WIP rots.

### 7. Push to a second remote (defense in depth)

Single remotes can have outages, repo-level admin mistakes, or permission revocation. Two independent remotes (e.g., GitHub + self-hosted Gitea) means the work survives even rare hosting failures.

```bash
git remote -v   # verify you have 2 remotes
# origin   git@github.com:user/repo.git
# gitea    user@gitea-host:user/repo.git

# Dual-push pattern
git push origin main && git push gitea main
```

For solo projects on consumer-grade machines, this is genuinely useful — your `~` and your laptop SSD are both single points of failure.

### 8. Read `git reflog` regularly — it's your safety net

Reflog is git's local time-travel log. Every HEAD movement (commit, reset, checkout, rebase) is recorded for ~30-90 days. **If you committed something at any point, you can recover it via reflog even if you `git reset --hard` afterward.**

```bash
git reflog -30           # last 30 HEAD movements
git reflog show stash    # stash history
git reflog refs/heads/main   # main branch history specifically
```

Recovery flow:
1. `git reflog` shows commit hashes of everything you've done
2. `git show <hash>` to see what was in that state
3. `git checkout <hash>` to bring it back (detached HEAD), or `git branch recover <hash>` to make it permanent

Reflog only knows about LAYER 3+ (committed) operations. Layer 1 (working-tree) doesn't appear here — another reason to commit early.

### 9. Stash is a backup, but a weak one

`git stash` IS recoverable from reflog (`git reflog show stash`), but stashes can be dropped accidentally:
- `git stash clear` wipes them all
- `git stash drop` removes one
- Old stashes can be GC'd if you don't `git stash apply` them in time
- Multiple `git stash pop` operations can lose stashes if applied in wrong order

**Stash is for short-lived state (minutes), not long-lived state (days).** For long-lived WIP, commit to a branch instead.

### 10. Make commit cheap, make push cheap

If commit/push is friction, you'll skip it. Friction comes from:
- Slow pre-commit hooks (lint everything, run all tests)
- Mandatory ticket numbers in commit messages
- Required co-authors / signing
- Slow remotes (rate-limited, unreliable)

**Solo projects:** keep hooks fast (<5 sec total) or allow `--no-verify` for WIP. The goal is to make commit-every-30-min painless. Slow hooks = skipped commits = lost work.

**Team projects:** commit fast on a feature branch (skip CI), squash + clean for PR. Don't make people pay CI cost for WIP commits.

```bash
# WIP commit, skip hooks (allowed for personal branches)
git commit --no-verify -m "wip: <topic>"
```

`--no-verify` is fine for WIP commits on personal branches. It's NOT fine for shared branches without team agreement.

## The cadence model

Internalize this rhythm:

| Time horizon | Action | Layer reached |
|---|---|---|
| Every 5-10 min | Save the file (Ctrl-S) | Layer 1 (volatile) |
| Every 30-60 min | `git commit -m "wip: ..."` | Layer 3 (reflog-protected) |
| Every focused session | `git push origin HEAD:wip/<topic>` | Layer 4 (off-machine) |
| Every milestone | Squash + clean message + push to main / open PR | Layer 4 (clean history) |

If you skip the 30-min commit, you risk the work between layer 1 and layer 3.
If you skip the end-of-session push, you risk the work between layer 3 and layer 4.

## The "untrusted environment" multiplier

When working in environments where other tools/agents/scripts can touch the working tree:
- Coder subagents with `Bash` access
- IDE auto-format / auto-fix on save
- Pre-commit hooks that auto-modify (auto-format, auto-import)
- File watchers that move/rename files
- Build systems that overwrite generated files

**Compress the cadence.** If an agent might run `git restore` (silent loss), commit before dispatching. If a hook might rewrite imports, commit before save. The 30-60 min default tightens to "every action that COULD touch the working tree."

GIT-SAFETY rules 11-13 codify this for agent dispatches. The principle generalizes.

## Anti-patterns (what NOT to do)

| Anti-pattern | Why it fails |
|---|---|
| "I'll commit when it's done" | "Done" is days away. Work between now and "done" is volatile. |
| "It's just a small change, no need to commit" | Small changes are 80% of lost work because they don't trigger your "this is important" reflex. |
| "I'll squash later, so messy commits are bad now" | You can squash anytime in the future. You can't un-lose work. |
| Carrying `M` files across multiple sessions | Each session = another opportunity for an agent / hook / tool to revert them. |
| Treating `git status` clean = safe | Clean only means committed. Uncommitted edits between commits are still volatile. |
| Forgetting to `git add` new files before `git stash` | Default stash ignores untracked files. They stay in working tree, vulnerable. |
| `git stash drop` without checking content | Drops are silent and irreversible. Always `git stash show -p` before drop. |
| "I have one remote, that's enough" | Single point of failure. Hosting outage / admin mistake = work gone. |
| Slow pre-commit hooks | Friction → skipped commits → lost WIP. Either fast hooks or `--no-verify` allowed. |
| Long-lived WIP branches without push | Branch on local disk = single SSD failure away from gone. Push the branch. |

## When you DO lose work

Order of recovery attempts (most likely to succeed → least):

1. **`git reflog` if you ever committed it** — recovers any committed state from last ~90 days
2. **`git fsck --lost-found`** — finds dangling commits + blobs not referenced by any branch
3. **`git stash list` + `git fsck`** — stashes that got dropped but aren't GC'd yet
4. **IDE local history** — VS Code, JetBrains, etc. (check `~/.config/<IDE>/User/History/` and Windows `%APPDATA%/<IDE>/User/History/`)
5. **OS-level recovery** — `extundelete` on ext4, recycle bin on Windows, Time Machine on macOS
6. **Reconstruction from memory** — if symptoms are observable (running app reproduces the bug you fixed), you can re-derive

If recovery fails, the lesson is: **the cost of one commit (5 seconds) is dramatically less than the cost of recovery (hours to days).** Make commit cheap and frequent.

## Cross-references

- [GIT-SAFETY.md](GIT-SAFETY.md) — catastrophe defenses (force-push, agent silent-restore). GIT-HYGIENE prevents the daily losses; GIT-SAFETY prevents the rare big losses. Both required.
- [NLF.md](NLF.md) — No Lie Fix. "I'll commit later" is a lie to yourself about intent. Commit now or accept the loss.
- [SDP.md](SDP.md) — Standard Development Protocol. Every SDP step (Brainstorm, Plan, Execute, Review) is a natural commit boundary.
- [TDD.md](TDD.md) — TDD's RED-GREEN-REFACTOR pattern is naturally three atomic commits.

## Summary — the 10 rules + cadence

1. Commit on every natural pause (context-switch, break, agent dispatch, test pass/fail, 30-60 min)
2. WIP commits are normal — make them ugly and prolific
3. Push WIP to a remote branch at end of every session
4. Untracked files: `git add` them or accept volatility
5. Atomic commits per logical change (TDD discipline)
6. `M` flag is a comparison marker, NOT a save state
7. Two remotes (GitHub + Gitea / GitLab / etc.) — defense in depth
8. Read `git reflog` regularly — your safety net for committed states
9. Stash is for minutes, branches are for days
10. Make commit + push cheap (fast hooks, `--no-verify` for WIP)

**Cadence: save → 30 min: commit → end-of-session: push → milestone: squash + PR.**

If you only remember one rule: **a 5-second WIP commit is the cheapest insurance you'll ever buy.**

---
name: rebase-main
description: Fetch and rebase the current branch onto origin/main (or origin/master) for a clean linear history. Handles conflicts and reports what was done.
argument-hint:
allowed-tools: Bash(git:*), Read, Grep, Glob, Edit
---

# Rebase Current Branch onto Main

Rebase the current working branch onto the latest `origin/main` (or `origin/master`) for a clean, linear commit history. Handle conflicts and produce a summary report.

## Your Task

Execute the following steps in order:

### 1. Pre-flight checks
1. Run `git rev-parse --abbrev-ref HEAD` to get the current branch name.
2. **Safety check**: if on `main` or `master`, **stop** and warn the user. Do NOT rebase the main branch.
3. Run `git status --porcelain` to check for uncommitted changes.
   - If there are uncommitted changes, **stop** and warn the user. Ask if they want to stash or commit first. Do NOT proceed with a dirty working tree.
4. Determine the main branch: check if `origin/main` exists (`git rev-parse --verify origin/main`). If not, fall back to `origin/master`.

### 2. Fetch and rebase
1. Run `git fetch origin` to get the latest remote state.
2. Run `git rev-list --count HEAD..{main-branch}` to see how many new commits are on main.
   - If **0 commits** incoming, report "Already up to date with {main-branch}" and stop.
3. Capture the incoming commit list BEFORE rebasing: `git log --oneline HEAD..{main-branch}`.
4. Run `git rebase {main-branch}`.
5. Capture the rebase output.

### 3. Handle conflicts
If the rebase stops due to conflicts:
1. Run `git diff --name-only --diff-filter=U` to list conflicted files.
2. For **each conflicted file**:
   a. Read the file to see the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
   b. Analyze the conflict:
      - **Theirs-only changes** (our side is unchanged around the conflict): accept theirs.
      - **Ours-only changes** (their side is unchanged around the conflict): accept ours.
      - **Both sides changed**: Use your best judgment based on the code context. Prefer combining both changes when they don't overlap logically. If the conflict is complex or ambiguous, **abort the rebase** (`git rebase --abort`), report the issue, and let the user handle it manually.
   c. Edit the file to remove conflict markers and apply the resolution.
   d. Run `git add {file}` to mark it resolved.
3. After all conflicts in the current step are resolved, run `git rebase --continue`.
4. Repeat steps 1-3 if the rebase stops again on subsequent commits.
5. If more than **3 conflict rounds** occur, **abort the rebase** (`git rebase --abort`) and report to the user that manual resolution is needed.

### 4. Post-rebase report
Generate a clear report with:

```
## Rebase Report: {current-branch} onto {main-branch}

### Summary
- **New commits from main:** {count}
- **Conflicts:** {count} ({list of files, or "None"})
- **Status:** {Rebased cleanly | Rebased with conflict resolution | Aborted}

### Commits from main
{list of commits from git log --oneline captured BEFORE the rebase}

### Conflict Resolutions (if any)
For each resolved conflict:
- **{filename}**: {brief description of what conflicted and how it was resolved}

### Notes
- Your local commits have been replayed on top of the latest main.
- If your branch was previously pushed, you will need to force-push: `git push --force-with-lease`
```

## Important

- **Never rebase `main` or `master`** — check the branch name first
- If there are uncommitted changes, **do not proceed** — ask the user first
- If a conflict resolution is ambiguous, **abort the rebase** rather than guessing wrong
- Always use `git rebase --continue` (never `--skip`) after resolving conflicts
- Use `--force-with-lease` (not `--force`) in the push reminder — it's safer
- After completion, do NOT push — leave that to the user, but remind them about force-push if needed
- If anything goes wrong mid-rebase, run `git rebase --abort` to return to the original state

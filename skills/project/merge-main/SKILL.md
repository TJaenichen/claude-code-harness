---
name: merge-main
description: Fetch and merge origin/main into the current branch and resolve conflicts.
argument-hint:
allowed-tools: Bash(git:*), Read, Grep, Glob, Edit
---

# Merge Main into Current Branch

Merge the latest `origin/main` (or `origin/master`) into the current working branch, handle conflicts, and produce a summary report.

## Your Task

Execute the following steps in order:

### 1. Pre-flight checks
1. Run `git rev-parse --abbrev-ref HEAD` to get the current branch name.
2. Run `git status --porcelain` to check for uncommitted changes.
   - If there are uncommitted changes, **stop** and warn the user. Ask if they want to stash or commit first. Do NOT proceed with a dirty working tree.
3. Determine the main branch: check if `origin/main` exists (`git rev-parse --verify origin/main`). If not, fall back to `origin/master`.

### 2. Fetch and merge
1. Run `git fetch origin` to get the latest remote state.
2. Run `git log --oneline HEAD..{main-branch} --count` (use `git rev-list --count HEAD..{main-branch}`) to see how many commits are incoming.
   - If **0 commits** incoming, report "Already up to date" and stop.
3. Run `git merge {main-branch} --no-edit`.
4. Capture the merge output.

### 3. Handle conflicts
If the merge reports conflicts:
1. Run `git diff --name-only --diff-filter=U` to list conflicted files.
2. For **each conflicted file**:
   a. Read the file to see the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
   b. Analyze the conflict:
      - **Theirs-only changes** (our side is unchanged around the conflict): accept theirs.
      - **Ours-only changes** (their side is unchanged around the conflict): accept ours.
      - **Both sides changed**: Use your best judgment based on the code context. Prefer combining both changes when they don't overlap logically. If the conflict is complex or ambiguous, resolve it conservatively and flag it in the report.
   c. Edit the file to remove conflict markers and apply the resolution.
   d. Run `git add {file}` to mark it resolved.
3. After all conflicts are resolved, run `git commit --no-edit` to complete the merge.

### 4. Post-merge report
Generate a clear report with:

```
## Merge Report: {main-branch} → {current-branch}

### Summary
- **Incoming commits:** {count}
- **Conflicts:** {count} ({list of files, or "None"})
- **Status:** {Merged cleanly | Merged with conflict resolution}

### Incoming Commits
{list of commits from git log --oneline HEAD..origin/main BEFORE the merge, i.e., the commits that were brought in}

### Conflict Resolutions (if any)
For each resolved conflict:
- **{filename}**: {brief description of what conflicted and how it was resolved}

### Files Changed
{git diff --stat HEAD~1 summary showing files changed, insertions, deletions}
```

## Important

- **Never force-push or reset** — this skill is purely additive (fetch + merge)
- If there are uncommitted changes, **do not proceed** — ask the user first
- If a conflict resolution is ambiguous, flag it clearly in the report so the user can review
- Always use `--no-edit` on merge/commit to avoid interactive editors
- After completion, do NOT push — leave that to the user

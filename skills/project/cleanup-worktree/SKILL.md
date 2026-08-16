---
name: cleanup-worktree
description: Remove a git worktree after a feature branch has been merged.
argument-hint: <work-item-id>
allowed-tools: Bash(git:*)
disable-model-invocation: true
---

# Cleanup Worktree

Work item ID: $ARGUMENTS

## Your task

1. **Verify the worktree exists**:
   ```bash
   git worktree list | grep "$ARGUMENTS"
   ```

2. **Check if the feature branch was merged** (from the main repo):
   ```bash
   cd /c/work/Payments && git fetch origin && git branch -r --merged origin/main | grep "$ARGUMENTS"
   ```

3. **If merged, remove the worktree**:
   ```bash
   git worktree remove /c/work/$ARGUMENTS_*
   ```

4. **Prune stale references**:
   ```bash
   git worktree prune
   ```

5. **Optionally delete the remote branch** (ask user first):
   ```bash
   git push origin --delete feature/$ARGUMENTS_*
   ```

## Output

Report:
- Whether the branch was merged
- Worktree removal status
- Ask before deleting remote branch

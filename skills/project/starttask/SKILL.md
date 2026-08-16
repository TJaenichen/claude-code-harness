---
name: starttask
description: Start a new task - pull main, create worktree and feature branch from DevOps work item
argument-hint: <work-item-id>
allowed-tools: Bash(git:*), Bash(curl:*)
---

# Start New Task

Work item ID: $ARGUMENTS

## Your task

1. **Pull latest main** in C:\work\Payments:
   ```bash
   cd /c/work/Payments && git checkout main && git pull
   ```

2. **Fetch work item details** from DevOps:
   ```bash
   curl -L --negotiate -u : "https://devops.example.com/DefaultCollection/MyProject/_apis/wit/workitems/$ARGUMENTS?api-version=6.0"
   ```

3. **Extract the title** from `fields.System.Title` and create a short name:
   - Remove special characters
   - Replace spaces with underscores
   - Truncate to max 15 characters
   - Example: "Add Widget Support for New Processor" → "AddWidgetSup"

4. **Create worktree and branch** (from C:\work\Payments):
   ```bash
   git worktree add -b feature/<ID>_<ShortName> /c/work/<ID>_<ShortName> origin/main
   ```

   Where:
   - Branch name: `feature/$ARGUMENTS_<ShortName>`
   - Directory: `/c/work/$ARGUMENTS_<ShortName>` (no "feature-" prefix to keep path short)

5. **Push the feature branch** to create remote tracking:
   ```bash
   cd /c/work/<ID>_<ShortName>
   git push -u origin feature/<ID>_<ShortName>
   ```
6. **Report success** with:
   - Work item title
   - Branch name
   - Worktree path
   - Conversation renamed to

## Important

- Directory name does NOT include "feature-" prefix (to avoid Windows path length issues)
- Branch name DOES include "feature/" prefix
- Short name must be max 15 characters to avoid path-too-long errors on Windows
- If the work item doesn't exist, report the error clearly

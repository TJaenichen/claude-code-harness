---
name: finalize-task
description: Commit, squash, push, and create a PR for the current branch.
argument-hint: ["PR title or description"]
allowed-tools: Bash(git:*), Bash(powershell:*)
---

# Finalize Task

Optional arguments: $ARGUMENTS

## Your task

Complete the current branch by committing all changes, squashing into a single commit, pushing, and creating a pull request.

## Steps

### 1. Gather context (run in parallel)

- `git status` — check for uncommitted changes
- `git log --oneline main..HEAD` — see all commits on this branch
- `git diff --stat main..HEAD` — see all changed files vs main
- `git rev-parse --abbrev-ref HEAD` — get current branch name

### 2. Commit any uncommitted changes

If there are staged or unstaged changes:
1. Stage all relevant changes (be specific with file paths, avoid secrets like `.env`)
2. Generate a concise commit message describing the changes
3. Commit

If the working tree is clean, skip this step.

### 3. Squash commits

If there are **multiple commits** on this branch (vs main):
1. Find the merge base: `git merge-base main HEAD`
2. Soft-reset to the merge base: `git reset --soft <merge-base>`
3. Create a single commit with a message that summarizes ALL the changes across all commits
4. Use a clear, descriptive commit message

If there is only **one commit**, skip this step.

### 4. Push

```bash
git push -u origin <branch> --force-with-lease
```

Use `--force-with-lease` since we may have squashed (safe force push that won't overwrite others' work).

### 5. Create Pull Request

Extract the work item ID from the branch name (format: `feature/<ID>_<ShortName>`).

Use PowerShell to create the PR via Azure DevOps REST API:

```powershell
$repoId = "<REPO_ID>"
$baseUrl = "https://devops.example.com/DefaultCollection/MyProject/_apis/git/repositories/$repoId"

$body = @{
    sourceRefName = "refs/heads/<branch>"
    targetRefName = "refs/heads/main"
    title = "<title>"
    description = "<description>"
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "$baseUrl/pullrequests?api-version=6.0" -Method Post -Body $body -ContentType "application/json" -UseDefaultCredentials
```

**PR title**: Use `$ARGUMENTS` if provided, otherwise generate from the commit message. Include the work item ID as `(#<ID>)` at the end.

**PR description**: Generate a summary with:
```
## Summary
- bullet points describing the changes

## Test plan
- [ ] relevant test steps
```

### 6. Report success

Display:
- Commit hash and message
- Number of commits squashed (if any)
- PR URL: `https://devops.example.com/DefaultCollection/MyProject/_git/Payments/pullrequest/{id}`

## Edge cases

- **No changes and no commits**: Report that there's nothing to finalize
- **PR already exists for this branch**: Report the existing PR URL instead of creating a duplicate. Find it via:
  ```powershell
  Invoke-RestMethod -Uri "$baseUrl/pullrequests?searchCriteria.sourceRefName=refs/heads/<branch>&api-version=6.0" -UseDefaultCredentials
  ```
- **Branch is `main`**: Refuse and tell the user to work on a feature branch
- **Push fails**: Report the error, do not retry blindly

## Important

- Always use `-UseDefaultCredentials` for Windows auth
- Always use `--force-with-lease` (not `--force`) when pushing after squash
- Use PowerShell `Invoke-RestMethod` for API calls (not curl) — it handles Windows auth natively
- Save PowerShell scripts to temp files if commands get complex, to avoid escaping issues

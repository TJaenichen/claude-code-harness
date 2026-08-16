---
name: pr
description: Manage Pull Requests - create, update description, add wiki links. Use for all PR operations in Azure DevOps.
argument-hint: "<create|update|wiki|info> [options]"
allowed-tools: Bash(git:*), Bash(powershell:*)
---

# Pull Request Management

Command: `/pr $ARGUMENTS`

## Commands

| Command | Description | Example |
|---------|-------------|---------|
| `create` | Create new PR from current branch | `/pr create "My PR Title"` |
| `update` | Update PR description | `/pr update "New description content"` |
| `wiki` | Add wiki documentation link to PR | `/pr wiki "Title\|URL"` or `/pr wiki URL` |
| `info` | Show current branch's PR info | `/pr info` |

## Azure DevOps Configuration

- **Server:** https://devops.example.com/
- **Project:** MyProject (ID: `<PROJECT_ID>`)
- **Repository:** Payments (ID: `<REPO_ID>`)
- **Auth:** Windows Integrated Security (UseDefaultCredentials)

## API Endpoints

```
Base URL: https://devops.example.com/DefaultCollection/MyProject/_apis/git/repositories/<REPO_ID>
```

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get PR by branch | GET | `/pullrequests?searchCriteria.sourceRefName=refs/heads/{branch}&api-version=6.0` |
| Get PR by ID | GET | `/pullrequests/{id}?api-version=6.0` |
| Create PR | POST | `/pullrequests?api-version=6.0` |
| Update PR | PATCH | `/pullrequests/{id}?api-version=6.0` |

## Your Task

Parse `$ARGUMENTS` and execute the appropriate command:

### `/pr create "Title"` or `/pr create "Title" "Description"`
1. Get current branch name: `git rev-parse --abbrev-ref HEAD`
2. Check if branch is pushed to remote, if not push it: `git push -u origin {branch}`
3. Create PR via POST with:
   - `sourceRefName`: `refs/heads/{current-branch}`
   - `targetRefName`: `refs/heads/main`
   - `title`: from arguments
   - `description`: from arguments (optional)
4. Return PR URL: `https://devops.example.com/DefaultCollection/MyProject/_git/Payments/pullrequest/{id}`

### `/pr update "content"` or `/pr update prepend "content"` or `/pr update append "content"`
1. Get current branch name
2. Find PR for current branch via GET search
3. Get current description
4. Update description:
   - Default/`prepend`: Add content at beginning
   - `append`: Add content at end
   - `replace`: Replace entire description
5. PATCH the PR with new description

### `/pr wiki "Title|URL"` or `/pr wiki URL`
1. Parse wiki link - if no `|`, use "Documentation" as title
2. Find PR for current branch
3. Remove existing `## Documentation` section if present
4. Prepend new documentation section:
   ```
   ## Documentation
   - [Title](URL)

   ```
5. PATCH the PR

### `/pr info`
1. Get current branch name
2. Find PR for current branch
3. Display: PR ID, Title, Status, URL, Description preview

## PowerShell Template for API Calls

```powershell
$repoId = "<REPO_ID>"
$baseUrl = "https://devops.example.com/DefaultCollection/MyProject/_apis/git/repositories/$repoId"

# GET request
Invoke-RestMethod -Uri "$baseUrl/pullrequests?searchCriteria.sourceRefName=refs/heads/$branch&api-version=6.0" -UseDefaultCredentials

# PATCH request
$body = @{ description = $newDesc } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri "$baseUrl/pullrequests/$prId`?api-version=6.0" -Method Patch -Body $body -ContentType "application/json" -UseDefaultCredentials

# POST request (create)
$body = @{
    sourceRefName = "refs/heads/$branch"
    targetRefName = "refs/heads/main"
    title = $title
    description = $description
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri "$baseUrl/pullrequests?api-version=6.0" -Method Post -Body $body -ContentType "application/json" -UseDefaultCredentials
```

## Important

- Always use `-UseDefaultCredentials` for Windows auth
- PR URL format: `https://devops.example.com/DefaultCollection/MyProject/_git/Payments/pullrequest/{id}`
- Wiki link format supports both `Title|URL` and just `URL`
- When updating, preserve existing description content unless explicitly replacing
- Use PowerShell scripts saved to temp files to avoid escaping issues with complex commands

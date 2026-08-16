---
name: devops-workitem-update
argument-hint: <work-item-id>
description: Update Azure DevOps work item fields (Description, Acceptance Criteria, State, etc.)
allowed-tools: Bash(powershell:*)
---

# Update Azure DevOps Work Item

Work item ID: $ARGUMENTS

## Process

1. Ask the user what to update (or infer from context)
2. Update the work item via PowerShell:

```powershell
$ops = @(
    @{ op = "add"; path = "/fields/System.Title"; value = "New title" }
    @{ op = "add"; path = "/fields/System.Description"; value = "<p>HTML content</p>" }
)
$body = ConvertTo-Json -InputObject $ops -Depth 5
Invoke-RestMethod -Uri "https://devops.example.com/DefaultCollection/MyProject/_apis/wit/workitems/$ARGUMENTS`?api-version=6.0" -Method Patch -Body $body -ContentType "application/json-patch+json" -UseDefaultCredentials
```

**Important**: Use `ConvertTo-Json -InputObject $ops` (not piping) to preserve single-element arrays.

3. Verify: check that `rev` incremented in response, show link

## Field Reference

| Field | Path |
|-------|------|
| Title | `/fields/System.Title` |
| Description | `/fields/System.Description` |
| Acceptance Criteria | `/fields/Microsoft.VSTS.Common.AcceptanceCriteria` |
| State | `/fields/System.State` |
| Assigned To | `/fields/System.AssignedTo` |
| Area Path | `/fields/System.AreaPath` |
| Iteration Path | `/fields/System.IterationPath` |

Operations: `add` (set/replace), `replace` (fails if missing), `remove` (clear)

HTML values must be on a **single line** (no embedded newlines).

## Web link

`https://devops.example.com/DefaultCollection/MyProject/_workitems/edit/$ARGUMENTS/`

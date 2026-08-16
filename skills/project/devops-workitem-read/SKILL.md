---
name: devops-workitem-read
argument-hint: <work-item-id>
description: Fetch Azure DevOps work item details (title, state, description, acceptance criteria)
allowed-tools: Bash(curl:*)
---

# Read Azure DevOps Work Item

Work item ID: $ARGUMENTS

## Your task

Fetch the work item details from Azure DevOps using the REST API with integrated Windows authentication.

### Execute

```bash
curl -L --negotiate -u : "https://devops.example.com/DefaultCollection/MyProject/_apis/wit/workitems/$ARGUMENTS?api-version=6.0"
```

### Parse and display

Extract and display the following fields from the JSON response:

| Field | JSON Path |
|-------|-----------|
| ID | `id` |
| Title | `fields.System.Title` |
| Type | `fields.System.WorkItemType` |
| State | `fields.System.State` |
| Assigned To | `fields.System.AssignedTo.displayName` |
| Description | `fields.System.Description` |
| Acceptance Criteria | `fields.Microsoft.VSTS.Common.AcceptanceCriteria` |
| Sprint | `fields.System.IterationPath` |
| Area | `fields.System.AreaPath` |

### Output format

Present a clean summary with:
- Work item ID and title
- Current state and assignee
- Description (strip HTML tags for readability)
- Acceptance criteria (if present)
- Link to web UI: `https://devops.example.com/DefaultCollection/MyProject/_workitems/edit/$ARGUMENTS/`

### Error handling

If the work item doesn't exist or access is denied, report the error clearly.

---
argument-hint: <title or description>
description: Create a new Azure DevOps work item (Task by default)
allowed-tools: Bash(powershell:*)
name: devops-workitem-create
---

# Create Azure DevOps Work Item

Title or description: $ARGUMENTS

## Process

1. Determine the work item type: **Task** by default; **User Story** for feature/analysis work that stands on its own; **Bug** for defects.
2. Pick a **content shape** (below) by who benefits, and draft Title, Description, and Acceptance Criteria as a first draft. These are sensible defaults, not a rigid standard — adapt freely to the item at hand.
3. Create it and report back. Show the plain-text draft for a nod first only when the request is genuinely ambiguous or high-stakes — a well-specified item doesn't need one. Blast radius is small (a wrong item is trivially edited or deleted to the recycle bin).
4. Create the work item via PowerShell (see **API mechanics**).
5. Extract the `id` from the response and report the new work item ID and web link.

## Content shapes

Defaults the skill drafts toward — a starting point, not a gate. The only real decision is who benefits. If your team has a written work-item format, link it here so the skill and the humans agree.

- **Story** — someone outside the delivery team benefits (customer/business-facing). Use the `As a / I want / so that` header with a *real* beneficiary.
- **Enabler** — the beneficiary is the system, pipeline, or a downstream team (plumbing). **Skip the `As a` framing** rather than inventing a fake actor; use `Problem` / `Change required` / `Rationale` instead. Do NOT write "As a Product Owner, I want the backend to…" — that disguises a technical task as a story.
- **Analysis / Spike** — the deliverable is findings, not a code change. Title starts `Investigate …`; state "analysis only" explicitly; close with a **Deliverable** block instead of AC.

Acceptance criteria can be Gherkin (Given/When/Then, reads well for behaviour) or numbered `AC1/AC2` bullets (fits technical work) — whichever is more checkable. No format is mandatory; a plain checklist is fine for small items.

### Title

- Concise and descriptive: what changes / what is wrong, not a sentence fragment of the description.
- Optional bracket prefix for the epic/project context: `[Checkout redesign] …`, `[Reporting] …`.
- Analysis-only stories start with `Investigate …`.

### User Story — Description

HTML, structured as:

```html
<div>
<p><strong>As</strong> a Product Owner,<br>
<strong>I want</strong> &lt;capability&gt;,<br>
<strong>so that</strong> &lt;benefit / measurable outcome&gt;.</p>
<h3>Description</h3>
<p>Context: what exists today, why the change is needed.</p>
<ul>
<li>Concrete scope item 1</li>
<li>Concrete scope item 2</li>
</ul>
</div>
```

- The role is the **real beneficiary** — the customer (e.g. "a retail customer") for customer-facing behaviour. If the only honest answer is "the system" or "the team", it's an **Enabler** — use that shape instead, don't write "a Product Owner".
- Use additional `<h3>` sections as needed: `Background` (current state, config values, table names), `Business Rules` (enumerated rules the AC will scenario-ize).
- Analysis-only stories state explicitly: *"This story is intended for analysis only. No implementation changes should be made until the root cause has been identified."*
- If details genuinely need sign-off first, prefer listing the specific open questions (with owners) over a blanket *"validate with &lt;team&gt; before development"* — surface them, don't hide them.

### Enabler — Description

Technical work with no external actor. No `As a` header:

```html
<div>
<h3>Problem</h3>
<p>What is blocked, broken, or absent today. Concrete.</p>
<h3>Change required</h3>
<ul><li>Specific enough that a reviewer could disagree with a bullet.</li></ul>
<h3>Rationale</h3>
<p>Which product outcome or experiment this serves (the "so that", in a different jacket).</p>
</div>
```

Acceptance criteria use the same AC-numbered or Gherkin dialects below.

### User Story — Acceptance Criteria

Two accepted dialects — pick per story nature:

**AC-numbered** (technical/enabler/backend stories):

```html
<div>
<p><strong>AC1 – &lt;Topic&gt;</strong></p>
<ul><li>Testable statement.</li><li>Testable statement.</li></ul>
<p><strong>AC2 – &lt;Topic&gt;</strong></p>
<ul><li>…</li></ul>
</div>
```

**Gherkin scenarios** (customer-facing / behavioral stories):

```html
<div>
<p><strong>Scenario 1 – &lt;Name&gt;</strong></p>
<p>Given &lt;precondition&gt;<br>When &lt;action&gt;<br>Then &lt;observable outcome&gt;.</p>
</div>
```

Standard closing ACs — include when applicable (most implementation stories):

- **Stability**: existing functionality continues to operate; no regressions outside the story's scope.
- **Validation**: verified in a non-production environment; logging/monitoring exists to confirm the new logic executes correctly.

Analysis stories close with a **Deliverable** block instead: what the documented analysis must contain (root cause, impacted components, config-vs-defect verdict, recommended solution).

### Bug

- The Bug form does **not** display `System.Description` — put the content in `Microsoft.VSTS.TCM.ReproSteps` (and environment details in `Microsoft.VSTS.TCM.SystemInfo`).
- `Custom.Environment` is **required** on creation (`PROD`, `STG`, `DEV`, `TST`, `Custom Host`).
- Structure the ReproSteps as: **Observed behavior** / **Expected behavior** / **Steps to reproduce** / **Impact** (who/what is affected, since when).

### Task

Lightweight: one paragraph on what and why, plus a "Done when" bullet list. Parent-link it to its User Story (see relations below).

### Recommended fields

| Field | Values | When |
|-------|--------|------|
| `Custom.StorySize` | `Small (1-2 days)`, `Medium (3-5 days)`, `Large (5-10 days)`, `X-Large` | User Stories |
| `Custom.Days` | `0.5`, `1`, `2-3`, `5` | Estimate, if known |
| `Microsoft.VSTS.Common.Priority` | 1 (highest) – 4 | Set when known; PO default is 3 |

## API mechanics

```powershell
$ops = @(
    @{ op = "add"; path = "/fields/System.Title"; value = "Short descriptive title" }
    @{ op = "add"; path = "/fields/System.Description"; value = "<div><p><strong>As</strong> a ...</p></div>" }
    @{ op = "add"; path = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria"; value = "<div><p><strong>AC1 - ...</strong></p><ul><li>...</li></ul></div>" }
    @{ op = "add"; path = "/fields/System.AreaPath"; value = "MyProject\MyArea" }
)
$body = ConvertTo-Json -InputObject $ops -Depth 5
Invoke-RestMethod -Uri "https://devops.example.com/DefaultCollection/MyProject/_apis/wit/workitems/`$Task?api-version=6.0" -Method Post -Body $body -ContentType "application/json-patch+json" -UseDefaultCredentials
```

**Important**: Use `ConvertTo-Json -InputObject $ops` (not piping) to preserve single-element arrays.

For other work item types, replace `` `$Task `` with `` `$Bug ``, `` `$User Story ``, etc. (URL-encode the space: `` `$User%20Story ``).

To parent-link the new item to a Feature/User Story, add a relation op:

```powershell
@{ op = "add"; path = "/relations/-"; value = @{
    rel = "System.LinkTypes.Hierarchy-Reverse"
    url = "https://devops.example.com/DefaultCollection/_apis/wit/workItems/<PARENT_ID>"
} }
```

## Field Reference

| Field | Path | Notes |
|-------|------|-------|
| Title | `/fields/System.Title` | Required |
| Description | `/fields/System.Description` | HTML, single line. Not shown on Bugs — use ReproSteps there |
| Acceptance Criteria | `/fields/Microsoft.VSTS.Common.AcceptanceCriteria` | HTML, single line |
| Repro Steps | `/fields/Microsoft.VSTS.TCM.ReproSteps` | Bug only, HTML |
| System Info | `/fields/Microsoft.VSTS.TCM.SystemInfo` | Bug only, HTML |
| Environment | `/fields/Custom.Environment` | **Required for Bugs**: `PROD`, `STG`, `DEV`, `TST`, `Custom Host` |
| Area Path | `/fields/System.AreaPath` | `MyProject\MyArea` for payment work; fallback `MyProject`. Non-existent nodes fail with TF401347, so check the area tree first |
| Iteration Path | `/fields/System.IterationPath` | Sprint assignment, e.g. `MyProject\Sprint 26` |
| State | `/fields/System.State` | `New`, `Active`, `Closed` |
| Assigned To | `/fields/System.AssignedTo` | Display name or email |
| Story Size | `/fields/Custom.StorySize` | See recommended fields |
| Days | `/fields/Custom.Days` | See recommended fields |

## Web link

`https://devops.example.com/DefaultCollection/MyProject/_workitems/edit/<ID>/`

---
name: panel-review
description: Multi-agent panel review of any code target (a PR by id, a branch, the current branch, or specific paths) against project standards, with confidence-scored findings grouped by category. Can post the findings to the Azure DevOps PR when the target is a PR. Use when the user asks for a thorough review of a PR, a branch, or a piece of code.
argument-hint: "[PR-ID | branch | path ...]"
allowed-tools: Bash(git:*), Bash(powershell:*), Glob, Grep, Read, Task
---

# Panel Review

Command: `/panel-review $ARGUMENTS`

Five reviewers in parallel (standards, bugs, git history, tests, requirements), one scored and filtered report, and the human decides what happens next. Works on a PR, a branch, or a set of files; the PR-specific steps (work item gate, posting threads) only apply when a PR is in play.

## Usage

| Usage | Description |
|-------|-------------|
| `/panel-review` | Current branch vs `main`, plus its PR if one exists |
| `/panel-review 12345` | PR #12345 by ID |
| `/panel-review feature/12345_ShortTitle` | A branch vs `main`, plus its PR if one exists |
| `/panel-review src/Rules/ tests/RulesTests.cs` | Specific files or directories from the working tree; no PR involved |

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
| Get PR work items | GET | `/pullrequests/{id}/workitems?api-version=6.0` |
| Post thread | POST | `/pullrequests/{id}/threads?api-version=6.0` |
| Get threads | GET | `/pullrequests/{id}/threads?api-version=6.0` |

## Your Task

Execute the following 10-step code review workflow.

---

### Step 1: Resolve the Target

Parse `$ARGUMENTS` and decide the **mode**:

| Argument shape | Mode | How to resolve |
|---|---|---|
| A number (e.g. `12345`) | `pr` | Fetch the PR by ID via GET `/pullrequests/{id}?api-version=6.0` |
| One or more existing paths (files or directories) | `paths` | Review the working-tree content of those paths. No PR lookup. |
| A branch name (`git rev-parse --verify <name>` or `origin/<name>` succeeds) | `branch` | Diff it against `main`. Also search for a PR on that branch; if one exists, switch to `pr` mode with that PR. |
| Empty | `branch` | Same as above with the current branch (`git rev-parse --abbrev-ref HEAD`). If the current branch is `main`, ask what to review and stop. |

Store: `mode`, `sourceBranch`, `targetBranch` (default `main`), and, in `pr` mode, `prId`, `title`, `status`, `createdBy`, `description`. In `branch` mode set `title` to the branch name and `description` to the last commit message; in `paths` mode set `title` to the path list.

If a number was given but no such PR exists, tell the user and stop.

**PowerShell template:**
```powershell
$repoId = "<REPO_ID>"
$baseUrl = "https://devops.example.com/DefaultCollection/MyProject/_apis/git/repositories/$repoId"

# By branch
$result = Invoke-RestMethod -Uri "$baseUrl/pullrequests?searchCriteria.sourceRefName=refs/heads/$branch&api-version=6.0" -UseDefaultCredentials
$pr = $result.value[0]

# By ID
$pr = Invoke-RestMethod -Uri "$baseUrl/pullrequests/$prId`?api-version=6.0" -UseDefaultCredentials
```

---

### Step 2: Eligibility Checks

**`pr` mode only.** In `branch` mode, try to parse a work item ID from the branch name (`^(feature|bugfix)/(\d+)[-_]`) and fetch it so Agent 5 has requirements context; if there is none, note "no work item context" and skip Agent 5. In `paths` mode there is no work item context; skip Agent 5. Then go to Step 3.

In `pr` mode, check the following before proceeding:

- **No linked work item**: Fetch linked work items via GET `/pullrequests/{id}/workitems?api-version=6.0` and check the `value` array. If empty, **stop the review** and tell the user: "PR has no linked DevOps work item. Link a User Story, Bug, or Task to the PR before requesting a review." This is a hard blocker — do not proceed. Store the work item IDs for use by Agent 5.
- If **status is `completed`** (merged/closed): Warn "PR is already completed" but proceed since user explicitly invoked the review.
- If **status is `abandoned`**: Warn "PR is abandoned" but proceed.
- If **a PR thread comment already contains `### Panel Review`**: Fetch threads via GET `/pullrequests/{id}/threads?api-version=6.0` and check if any thread's first comment content contains `### Panel Review`. If found, warn "PR already has a review comment" but proceed (user re-invoked = intent to re-review).

For warnings: display the warning, then continue with the review. For the missing work item check: **stop and do not proceed**.

---

### Step 3: Collect CLAUDE.md Review Criteria

Read all CLAUDE.md files in the repository to gather project-specific review standards:

```bash
find "$(git rev-parse --show-toplevel)" -name "CLAUDE.md" -not -path "*/node_modules/*" -not -path "*/.git/*"
```

Read each file. These contain the review criteria (Clean Architecture rules, testing standards, Dapper patterns, etc.).

---

### Step 4: Get the Code Under Review

- **`pr` / `branch` mode** — the complete diff against the target branch, using local git:
  ```bash
  git fetch origin
  git diff origin/main...origin/{sourceBranch} --stat
  git diff origin/main...origin/{sourceBranch}
  ```
  Use the target branch from the PR if it's not `main` (replace `origin/main` with `origin/{targetBranch}`).
- **`paths` mode** — the current content of every file under the given paths (use Glob for directories, skip binaries and generated files). If the branch has changes to those paths vs `main`, also compute `git diff main...HEAD -- <paths>` and hand both to the agents: they review the whole content but flag changed lines with priority. If there is no diff, everything is in scope and the "only flag changed code" instruction below does not apply.

If the diff is very large (>5000 lines), note this and still proceed — the parallel agents will handle chunks.

Store: list of changed files, total lines changed, which architectural layers are affected.

**Determine affected layers** from file paths:
- `Contoso.Payments.API/` = Presentation
- `Contoso.Payments.API.Application/` = Application
- `Contoso.Payments.API.Domain/` = Domain
- `Contoso.Payments.API.Infrastructure/` = Infrastructure
- `Contoso.Payments.API.PaymentProcessing/` = Payment Processing
- `Contoso.Payments.API.EFModels/` = EF Models
- `Contoso.Payments.API.UnitTests/` or `*.IntegrationTests/` = Tests
- `Contoso.Payments.Hangfire/` = Hangfire
- `Contoso.Payments/` = Web App
- Other = Other

---

### Step 5: Summarize Changes and Extract Context

Write a brief 2-4 sentence summary of what the change (or, in `paths` mode, the code) does based on the diff and the PR description. In `branch` and `paths` mode there is no PR description; the extraction below yields empty fields, which is fine.

Then parse the PR description (from Step 1's `description` field) and extract:

- **Test plan** — Any testing steps, verification instructions, or manual checks the author listed (e.g., "Test plan" sections, checklists, QA notes)
- **Directives** — Any reviewer notes, deployment instructions, migration steps, feature flags, or warnings the author called out
- **Summary context** — Any business context, motivation, scope boundaries, or known limitations mentioned in the PR description

Store these alongside the change summary. All will be passed to the review agents in Step 6.

---

### Step 6: Run the Review Panel in Parallel

Launch **5 Task agents in parallel** (4 when there is no work item context, see Agent 5) — all in a single message. Each agent receives:
- The change summary from Step 5
- The PR description context from Step 5 (test plan, directives, summary context)
- The list of changed files
- The relevant CLAUDE.md standards
- Instructions to return findings as structured JSON

**IMPORTANT:** Use `subagent_type: "general-purpose"` for all agents. Each agent should read the changed files directly and analyze them.

#### Agent 1: Standards Compliance

```
Review the following files for project standards compliance.

Target: "{title}" ({mode}; PR #{prId} when in pr mode)
Changed files: {file list}
Summary: {summary}
PR Description Context:
  Test plan: {testPlan}
  Directives: {directives}
  Summary context: {summaryContext}

Check each changed file for:
1. Clean Architecture violations — Domain must not reference Infrastructure/Application; Controllers must not contain business logic; Services must be in correct layer
2. Exception handling — No try-catch blocks unless the exception is actually handled (not just logged and rethrown). Exception: Controllers may have top-level try-catch for API responses.
3. SOLID/DRY violations — Duplicated logic, god classes, interface segregation issues
4. Dapper patterns — Must use IDbParameter and [SqlParameter] attributes for SP calls (not anonymous objects). Must use SCOPE_IDENTITY() not OUTPUT INSERTED for inserts.
5. Test assertions — Must use Assert.Fail(), never Assert.Ignore() or Assert.Inconclusive()
6. New patterns/projects — Flag any NEW architectural patterns or project additions (these need team confirmation per CLAUDE.md)

For each finding, return JSON:
{
  "file": "path/to/file.cs",
  "line": 42,
  "title": "Short issue title",
  "description": "What's wrong and how to fix it",
  "confidence": 85,
  "category": "standards"
}

Return findings as a JSON array. If no issues found, return [].
IMPORTANT: Only flag issues in the CHANGED code (new/modified lines), not pre-existing code. (In paths mode with no diff, the whole content is in scope.)
```

#### Agent 2: Bug & Logic Scan

```
Review the following files for bugs and logic errors.

Target: "{title}" ({mode}; PR #{prId} when in pr mode)
Changed files: {file list}
Summary: {summary}
PR Description Context:
  Test plan: {testPlan}
  Directives: {directives}
  Summary context: {summaryContext}

Check each changed file for:
1. Null reference risks — Missing null checks on parameters, nullable dereference without guard
2. Async/await issues — Missing await, async void (except event handlers), deadlock patterns (Result/Wait on async)
3. SQL injection — String concatenation in SQL queries instead of parameterized queries
4. Resource leaks — IDisposable not disposed, missing using statements for connections/readers
5. Logic errors — Off-by-one, incorrect boolean logic, unreachable code, swallowed exceptions
6. Concurrency issues — Shared mutable state without synchronization, race conditions

For each finding, return JSON:
{
  "file": "path/to/file.cs",
  "line": 42,
  "title": "Short issue title",
  "description": "What's wrong and how to fix it",
  "confidence": 85,
  "category": "bugs"
}

Return findings as a JSON array. If no issues found, return [].
IMPORTANT: Only flag issues in the CHANGED code (new/modified lines), not pre-existing code. (In paths mode with no diff, the whole content is in scope.)
```

#### Agent 3: Git History Context

```
Analyze the git history context for this change.

Target: "{title}" ({mode}; PR #{prId} when in pr mode)
Branch: {sourceBranch}
Changed files: {file list}
Summary: {summary}
PR Description Context:
  Test plan: {testPlan}
  Directives: {directives}
  Summary context: {summaryContext}

Check:
1. Reverted changes — Use `git log --oneline {files}` to see if any changed files were recently reverted. Flag if current changes re-introduce previously reverted code.
2. High-churn files — Use `git log --oneline --since="3 months ago" {files}` to identify frequently changed files. Flag if a file has been modified 5+ times recently (may indicate design issues).
3. Missing related changes — If a service interface is modified, check that implementations are also updated. If a domain model changes, check that dependent services are updated.
4. Commit quality — Review commits on the branch via `git log origin/main..origin/{sourceBranch} --oneline`. Flag if commits are messy (WIP, fixup, etc.) and suggest squashing.

For each finding, return JSON:
{
  "file": "path/to/file.cs",
  "line": 0,
  "title": "Short issue title",
  "description": "Context and recommendation",
  "confidence": 70,
  "category": "history"
}

Return findings as a JSON array. If no issues found, return [].
```

#### Agent 4: Test Quality

```
Review the test files in this PR for quality.

Target: "{title}" ({mode}; PR #{prId} when in pr mode)
Changed files: {file list}
Summary: {summary}
PR Description Context:
  Test plan: {testPlan}
  Directives: {directives}
  Summary context: {summaryContext}

Check:
1. Test plan coverage — If the PR description includes a test plan, verify that the test files in the PR actually cover those scenarios. Flag any test plan items that have no corresponding test.
2. Missing tests — If new services/handlers are added, are there corresponding unit tests? Flag missing coverage for new public methods.
3. Meaningless assertions — Tests that only assert true/not-null without validating actual behavior. Per CLAUDE.md: "Every test must provide real value — no tests written purely for coverage."
4. Project test patterns:
   - Must use [Order(n)] attributes when test fixture shares data (read-only tests first, mutating tests later)
   - Must use SCOPE_IDENTITY() in test setup for database inserts (not OUTPUT INSERTED due to triggers)
   - Must account for STG SQL Agent jobs that may modify test data mid-test
5. Integration test isolation — Tests must clean up after themselves; no test should depend on another test's side effects unless explicitly ordered
6. Assert patterns — Must use Assert.Fail() for expected failures, NEVER Assert.Ignore() or Assert.Inconclusive()

For each finding, return JSON:
{
  "file": "path/to/file.cs",
  "line": 42,
  "title": "Short issue title",
  "description": "What's wrong and how to fix it",
  "confidence": 75,
  "category": "tests"
}

Return findings as a JSON array. If no issues found, return [].
IMPORTANT: If no test files are in the changed files, check whether tests SHOULD have been added for the changes made. Return a single finding if significant untested logic was added.
```

#### Agent 5: Requirements Gap

**Only when Step 2 produced work item IDs** (linked to the PR, or parsed from the branch name). Otherwise launch four agents, not five.

This agent verifies that the implementation matches the business rules and requirements from the linked work item. The work item IDs are available from Step 2's `workItemRefs`.

```
Verify the PR implementation matches the requirements in the linked DevOps work item(s).

Target: "{title}" ({mode}; PR #{prId} when in pr mode)
Changed files: {file list}
Summary: {summary}
PR Description Context:
  Test plan: {testPlan}
  Directives: {directives}
  Summary context: {summaryContext}
Work Item IDs: {workItemIds from Step 2}

Step 1 — Gather all requirement context using PowerShell with -UseDefaultCredentials:

For each linked work item ID:

a) Fetch the work item with full expansion:
   GET https://devops.example.com/DefaultCollection/_apis/wit/workitems/{id}?$expand=all&api-version=6.0
   Extract: Title, Description, Acceptance Criteria (Microsoft.VSTS.Common.AcceptanceCriteria),
   Repro Steps (Microsoft.VSTS.TCM.ReproSteps), work item type (Bug/User Story/Task)

b) Fetch work item history (comments and field changes):
   GET https://devops.example.com/DefaultCollection/_apis/wit/workitems/{id}/updates?api-version=6.0
   Scan for requirement clarifications, scope changes, or business rule discussions in comments.

c) Fetch attachments: from the work item's relations array, find entries where
   rel == "AttachedFile". Download each via its URL. Read text/document content
   for specs, requirements, or business rules.

d) Fetch linked work items: from relations, follow:
   - "System.LinkTypes.Hierarchy-Reverse" (parent — may be a Feature with broader requirements)
   - "System.LinkTypes.Hierarchy-Forward" (child tasks — may have sub-requirements)
   - "System.LinkTypes.Related" (related items with additional context)
   For each linked item, fetch its Title, Description, and Acceptance Criteria.

Step 2 — Compare requirements against the PR diff:

1. Missing functionality — Acceptance criteria or business rules not addressed by the code changes.
   Check each acceptance criterion individually.
2. Partial implementations — Business rules only partially covered (e.g., happy path done but
   edge cases from the spec are missing, error scenarios not handled).
3. Scope creep — Code changes that go beyond what was requested in the work item
   (may indicate misunderstanding or undocumented requirements).
4. Contradictions — Implementation that conflicts with stated requirements or acceptance criteria.
5. PR description vs work item mismatch — Check if the PR description summary, directives,
   or test plan contradict or supplement the work item requirements. Flag discrepancies
   (e.g., PR claims feature X is done but work item acceptance criteria lists X differently).

For each finding, return JSON:
{
  "file": "path/to/file.cs",
  "line": 0,
  "title": "Short issue title",
  "description": "What requirement is missing/wrong and where it was specified (work item ID + field)",
  "confidence": 75,
  "category": "requirements"
}

Return findings as a JSON array. If no issues found, return [].
IMPORTANT: Only flag genuine gaps. If the work item description is vague or has no acceptance
criteria, note that as a single low-confidence finding rather than guessing at requirements.
All API calls must use -UseDefaultCredentials (Windows Integrated Auth).
```

---

### Step 7: Score and Collect Findings

Collect all findings from the 5 agents. Each finding has a confidence score (0-100).

Parse the JSON arrays from each agent's response. If an agent returned text instead of clean JSON, extract the findings manually.

---

### Step 8: Filter Findings

Remove findings that are:
- **Below confidence 50** — Too uncertain to report
- **Pre-existing code** — Issues in unchanged lines (agents were instructed to skip these, but double-check)
- **Intentional legacy patterns** — Known project patterns that look wrong but are correct:
  - Controller-level try-catch for API response formatting (this IS allowed per CLAUDE.md)
  - EF model `null!` property initialization (standard EF pattern)
  - Legacy WCF service calls (these are intentional, not technical debt to fix in a PR)
  - (add your own: any helper whose "surprising" behaviour is intentional and documented)

After filtering, sort remaining findings by confidence (highest first).

---

### Step 9: Report Findings to the Reviewer

Display the full review report to the user in the terminal. Do **NOT** automatically post anything to the PR — let the reviewer decide what action to take.

**Report format:**

```
Panel Review Complete
Target: {title} ({mode})
URL: https://devops.example.com/DefaultCollection/MyProject/_git/Payments/pullrequest/{prId}   <- pr mode only

Files reviewed: {fileCount}
Layers affected: {layers}
Issues found: {issueCount}
  - Standards: {n}
  - Bugs: {n}
  - History: {n}
  - Tests: {n}
  - Requirements: {n}
```

Then display findings **grouped by category**, with a heading for each:

```
## Standards ({n} issues)

**{title}** (confidence: {confidence}/100)
  File: {file}:{line}
  {description}

## Bugs ({n} issues)

**{title}** (confidence: {confidence}/100)
  File: {file}:{line}
  {description}

## History ({n} issues)
...

## Tests ({n} issues)
...

## Requirements ({n} issues)
...
```

Skip any category that has 0 findings. Within each category, sort by confidence (highest first).

If no issues were found:
```
No issues found. Clean PR!
```

---

### Step 10: Ask for Next Action

After displaying the report, ask the reviewer what they want to do:

1. **Post to PR** (`pr` mode only) — Post findings to the PR as **separate thread comments per category** (one thread per category, not one giant comment). Skip categories with 0 findings. In `branch` / `paths` mode offer **Save report** instead: write the report as markdown to the scratchpad and print the path.
2. **Fix issues** — Start fixing the reported issues in the code
3. **Done** — End the review, no further action

Only post to the PR if the reviewer explicitly chooses option 1.

When posting, create one PR thread per category using this format:

```markdown
### Panel Review — {Category}

**{title}** | {n} {category} issue(s)
Linked work item(s): #{workItemId}

---

**{finding title}** (confidence: {confidence}/100)
`{file}:{line}`
{description}

---

_Automated review by Claude Code | {date}_
```

**IMPORTANT — Azure DevOps auto-linking rules:**
- `#number` in comments auto-links to a **work item** with that ID. ONLY use `#number` to reference the PR's linked work items (from Step 2). Never use `#` with the PR ID or any other number — it will link to an unrelated work item.
- To reference the PR itself, use the full URL: `https://devops.example.com/DefaultCollection/MyProject/_git/Payments/pullrequest/{prId}`
- Only reference work items that are actually linked to the PR. Do not fabricate or guess work item IDs.

Use PowerShell script files (saved to temp) to avoid escaping issues with markdown content in bash.

---

## Important Notes

- Always use `-UseDefaultCredentials` for Windows auth
- PR URL format: `https://devops.example.com/DefaultCollection/MyProject/_git/Payments/pullrequest/{id}`
- If the reviewer chooses to post to the PR, use PowerShell script files (not inline) to avoid escaping issues
- The review focuses on CHANGED code only, not the entire codebase
- Confidence threshold of 50 is intentionally lower than typical (80) because domain patterns require nuanced judgment — the team can adjust upward if there are too many false positives

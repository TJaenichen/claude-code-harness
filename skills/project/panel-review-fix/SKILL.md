---
name: panel-review-fix
description: Multi-agent review of the current branch's diff vs main, with optional in-place fix application. Use this when the user wants to review their changes before opening a PR, when the PR-create hook asks for a review, or when the user asks to find issues and suggest fixes on the current branch.
allowed-tools: Bash, Read, Glob, Grep, Edit, Task
argument-hint: "[--auto | --manual | --review-only] [--force]"
---

Run a multi-agent code review against the current branch's diff vs `main`, then propose and (optionally) apply surgical fixes for high-confidence findings. Write a marker on completion so the PR-create hook lets the subsequent push through.

## Modes

Parse `$ARGUMENTS` for these flags. Default is `--manual`.

- `--manual` (default) — for each proposed fix, show the diff and ask the user `Apply this fix? (y/N/edit)` before calling Edit.
- `--auto` — apply every proposed fix without asking. The user can revert with `git checkout -- .`.
- `--review-only` — print findings, do not propose or apply fixes. Marker is still written.
- `--force` — bypass the "already reviewed" short-circuit in step 3. Use when you want a fresh review even though branch+HEAD haven't changed.

If multiple mode flags are passed, prefer `--review-only` > `--auto` > `--manual`.

## Step 1: Detect local context

Run these `git` commands from the current working directory:

- `git rev-parse --show-toplevel` → repo root. Capture as `REPO_ROOT`. If this fails: error "Not in a git repo. Run this from inside the repo checkout." and stop.
- `git rev-parse --abbrev-ref HEAD` → source branch. Capture as `BRANCH`. If it equals `main` or is empty: error "You're on `main`. Switch to a feature branch first." and stop.
- `git rev-parse HEAD` → HEAD sha. Capture as `HEAD_SHA`.
- `git diff main...HEAD --name-only` → changed files (3-dot means changes on this branch since divergence). Capture as `CHANGED_FILES`. If empty: print "🌱 Nothing on this branch vs `main` — nothing to review." Write the marker (Step 9) and stop.
- `git merge-base main HEAD` → base commit. Capture as `MERGE_BASE` (used for blame range filtering later).

Parse the work item ID from `BRANCH` using regex `^(feature|bugfix)/(\d+)[-_]`. If matched, capture as `WI_ID`. If not matched, set `WI_ID = ""` and skip work-item lookup.

## Step 2: Sanity-check the diff size

Run `git diff main...HEAD --stat | tail -1` to get the change summary. If the diff is enormous (say, > 5000 lines insertions+deletions), tell the user: "Large diff detected (`{summary}`). The review will take longer and cost more. Continue? (y/N)". Wait for confirmation before proceeding. Default to "y" if running unattended.

## Step 3: Marker short-circuit

Read `${REPO_ROOT}/.git/.panel-review-marker` if it exists. Compare its content to `${BRANCH}@${HEAD_SHA}`. If equal AND `--force` was not passed: print "✓ Already reviewed at this commit. Use `--force` to re-run." and stop. Otherwise continue.

## Step 4: Find CLAUDE.md files

Use Glob to find `${REPO_ROOT}/CLAUDE.md` and any `CLAUDE.md` files in the directories of `CHANGED_FILES`. Read each one and keep their contents available for the review agents.

## Step 5: Fetch work item context (optional)

If `WI_ID` is non-empty, fetch the work item via curl with Windows Integrated Auth:

```
curl -s --ntlm -u : "https://devops.example.com/DefaultCollection/MyProject/_apis/wit/workitems/${WI_ID}?$expand=all&api-version=7.0"
```

Extract these fields and keep them for the Requirements review agent (Step 6f):
- `System.Title`
- `System.Description`
- `Microsoft.VSTS.Common.AcceptanceCriteria` (strip HTML)

If the call fails, set `WI_CONTEXT = null` and skip the Requirements agent.

## Step 6: Spawn parallel review agents

Use the Task tool to launch **5 parallel** review agents (6 if `WI_CONTEXT` is present). Each agent gets `subagent_type: "general-purpose"`. Pass each agent:

- The diff: result of `git diff main...HEAD`
- The list of changed files: `CHANGED_FILES`
- The CLAUDE.md contents from Step 4
- (Requirements agent only) the work item context from Step 5
- Their specific focus (one of the six below)

Each agent should return a list of findings, each finding being a structured block:

```
- File: <path>
- Lines: <start>-<end>
- Category: <category>
- Title: <one-line summary>
- Explanation: <why this is a problem>
```

The six agents:

**a. CLAUDE.md Compliance** — Audit changes against CLAUDE.md rules. Key rules to check verbatim from the CLAUDE.md(s) loaded in Step 4. The example repo's recurring rules include: no try-catch unless the exception can actually be handled; no `#region` in C#; follow existing patterns rather than introducing new ones; SOLID/DRY; Clean Architecture layering; payment pipeline in C# is the source of truth, not legacy SPs.

**b. Bug Scan** — Shallow scan of the changes themselves for obvious bugs (null deref, off-by-one, wrong operator, swallowed exceptions, unreachable code, identity vs equality mistakes, etc.). Focus on real bugs introduced by THIS diff. Ignore likely false positives and pre-existing issues.

**c. Historical Context** — Read git blame and short history of each modified file. For files with substantive changes, run `git log --oneline -10 -- <filepath>` and skim recent commit messages for context. Flag changes that contradict the recent direction of the file (e.g., re-adding logic that was just removed, undoing a fix from last week).

**d. Pattern Consistency** — Look for new patterns this diff introduces that the codebase doesn't already use: new NuGet packages, new project structures, new base classes, new utility helpers, new naming conventions, new file layouts. Flag only when the existing codebase has an established alternative.

**e. Test Coverage** — For new functionality, are there tests? For modified behavior, are existing tests updated? For new conditional branches, are they exercised? Note: per the scoring rules in Step 7, untested new conditional branches in production code score 80 minimum.

**f. Requirements Check** (only if `WI_CONTEXT` is present) — For each acceptance-criteria bullet in the work item, decide whether the diff appears to satisfy it. Flag any AC that looks unmet by the code changes.

## Step 7: Confidence scoring

Take all findings from all agents and consolidate. For each finding, assign a confidence score 0-100 using this rubric:

- **0** — False positive. Doesn't stand up to scrutiny, or is a pre-existing issue not introduced by this diff.
- **25** — Might be real, might be a false positive. If purely stylistic, must be explicitly called out in CLAUDE.md to count.
- **50** — Real but a nitpick or unimportant relative to the rest of the diff.
- **75** — Verified real issue. Directly impacts functionality, or is explicitly mentioned in CLAUDE.md.
- **100** — Confirmed real. Will happen frequently in practice. Evidence directly confirms.

### Special scoring rules (apply after the base score):

**Untested new conditional branches.** When the diff adds new branching logic (`if`, `switch case`, early return, new code path) and there is no unit test covering that branch, score **80 minimum**. Integration tests do not count toward this unless they specifically exercise the new conditional. Untested logic is untested logic — don't downgrade just because it's "only a test gap".

**Cross-validation between agents.** If the Bug Scan agent flagged a real bug on a code path AND the Test Coverage agent flagged the same path as untested, the test coverage gap is validated by the bug itself — score it **85+**. The bug is proof the missing test would have mattered. This rule applies even if each finding alone would score below 80.

**Configurability / flexibility suggestions.** Issues of the form "make X configurable", "move to appsettings", "add a feature flag", "extract a constant" should score **max 50** unless there is specific evidence the value needs to vary at runtime (different per environment, per customer tier, per deployment, etc.). Without that evidence, it's a preference, not an issue.

## Step 8: Render the review

Filter to findings with score ≥ 80. These are the "reported" findings. Findings below 80 are "filtered".

Print the review to the user using this format (Markdown, rendered inline):

```
### Code Review — `<BRANCH>` vs `main`

Found N issue(s):

1. **<Category>**: <title>
   File: `<path>`, Lines: <range>
   Confidence: <score>/100

   <explanation>

2. ...

<details><summary>Full scoring detail (click to expand)</summary>

| Issue | Found By | Confidence | Disposition |
|---|---|---|---|
| <title> | <agent(s)> | <score>/100 | Reported |
| <title> | <agent(s)> | <score>/100 | Filtered |
| ... | ... | ... | ... |

Summary: N issues found, X reported (≥ 80), Y filtered (< 80).

</details>
```

If no findings ≥ 80, print a single line: a fun positive emoji of your choice (be creative, different every time — 🌈 🧸 🚀 🦄 🍀 🐬 🌻 anything goes), plus "Nothing above the 80-confidence threshold." Still emit the scoring detail block for transparency. Still write the marker. Then stop.

## Step 8.5: Propose fixes

Skip this entire step if `--review-only` was passed.

For each **reported** finding (score ≥ 80), decide whether you can write a concrete, surgical fix. **Quality bar: signal over noise. Skip rather than suggest a bad fix.**

A fix qualifies only if all of these are true:

- You can name the exact file and the exact code to change.
- The fix is localized (under ~20 lines) and touches a single file.
- The fix is clearly correct and aligns with CLAUDE.md, codebase patterns, and the PR's intent.
- The fix does NOT require: design discussions, adding new dependencies, adding new test files, refactoring across multiple files, or human judgment about intent.
- The change is to code that this branch already modified (a line in `git diff main...HEAD`'s touched lines). Don't suggest fixes to unrelated lines.

Skip fixes for issues like "add tests", "introduces new pattern, discuss", "missing acceptance criteria", or anything where the right answer is structural or organizational.

For each fix that qualifies, apply it according to the mode flag:

**`--manual` (default):** Print the proposed change:

```
### Fix 1 of N: <issue title>
File: <path>, near line <N>

Proposed change:
─────────────
- <old line(s)>
+ <new line(s)>
─────────────

Apply this fix? (y/N/edit/skip)
```

Wait for the user's response.
- `y` — call the Edit tool to apply the change. Print `✓ Applied`.
- `N` (default) or `skip` — record as Declined. Move on.
- `edit` — print "Type the replacement text (end with `--- END ---` on its own line):", read the user's input, then Edit with the user-provided replacement.

**`--auto`:** Edit directly. Print `✓ Applied: <path>:<line>`.

Track every proposed fix as `Applied`, `Declined`, `Skipped`, or `Edited`.

## Step 9: Write the marker

Always at the end (even on no-issues, even on `--review-only`), write `${BRANCH}@${HEAD_SHA}` to `${REPO_ROOT}/.git/.panel-review-marker`. Use the Bash tool — the path is local and one line.

Note: if `--auto` or `--manual` accepted changes mean the dev will commit new code, the HEAD sha after those commits will differ from the marker — that's expected. The marker says "review was performed on the diff at this sha". The next time the PR-create hook fires, it will see a stale marker and rerun the review on the new sha.

## Step 10: Final summary

Print a summary block:

```
Review complete on `<BRANCH>@<short-sha>`.
  Reported:  N issues (≥ 80 confidence)
  Applied:   X fix(es)
  Declined:  Y fix(es)
  Skipped:   Z fix(es) (no concrete fix available)
```

Then add the next-steps reminder:

```
Next:
  - Review changes:  git diff
  - Commit fixes:    git add -p && git commit -m "Apply suggested fixes from review"
  - Open the PR:     /pr create "<title>"
```

If no fixes were applied, drop the first two bullets.

## False positives to ignore

Pass this list to the review agents and to the scorer:

- Pre-existing issues not introduced by this branch's diff
- Something that looks like a bug but is not
- Pedantic nitpicks a senior engineer wouldn't flag
- Issues a linter, typechecker, or compiler would catch
- General code quality unless explicitly required in CLAUDE.md
- Issues silenced in code via explicit lint-ignore / suppression comments
- Intentional functionality changes directly related to the PR's purpose
- Real issues on lines this branch did not modify

## Important

- Do NOT build, compile, or run tests. CI handles that.
- Keep output brief and actionable. Cite file paths and line numbers.
- If work item acceptance criteria were found, evaluate the diff against them.
- The marker write in Step 9 is what unblocks the PR-create hook. Never skip it.

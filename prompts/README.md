# Prompts

Standalone prompts for headless runs: a service, a scheduled job, or `claude -p`. They are not skills; there is no `$ARGUMENTS`, and the caller is a program that parses the output.

## `automated-pr-reviewer.md`

The prompt behind an automated PR reviewer: a Windows service polls Azure DevOps for active PRs on a repository, runs this prompt against a checkout of the repo (through the Anthropic API, with a Haiku model for the cheap steps and a stronger model for the five parallel reviewers), and posts the result back as PR threads.

### Template variables

| Variable | Filled by the orchestrator with |
|---|---|
| `{{PR_ID}}` | The pull request id |
| `{{FORCE_NOTE}}` | Empty, or a note that this is a forced re-review (skips the eligibility step) |

### Output contract

The orchestrator looks for these markers in the model's final text:

| Marker | Meaning |
|---|---|
| `SKIP <emoji>` | Draft / trivial / already reviewed. Nothing posted. |
| `NO_ISSUES <emoji>` | Reviewed, nothing at or above the confidence threshold. |
| `REVIEW_START` ... `REVIEW_END` | Markdown to post as the review thread. Each issue may end with `{{FIX_BRANCH:<slug>}}`, which the orchestrator replaces with a branch link after applying the matching fix. |
| `FIXES_START` ... `FIXES_END` | JSON array of `{slug, issue, file, oldText, newText, summary}`. The orchestrator applies each as a literal single-occurrence string replacement on a fix branch off the PR source commit. If `oldText` is missing or ambiguous the fix is dropped. |
| `SCORES_START` ... `SCORES_END` | A table of every issue found, who found it, its score and whether it was reported. Posted separately for transparency. |

The rotating emoji after `SKIP` / `NO_ISSUES` is deliberate: it makes it obvious in the thread history that a run happened even when nothing was reported.

### The scoring rubric

Steps 7 and 8 are the part to reuse even if nothing else fits: a 0 / 25 / 50 / 75 / 100 rubric, three special rules (untested new conditional branches score 80 minimum; a bug and a missing test on the same path cross-validate to 85+; "make it configurable" caps at 50 without evidence), a threshold of 80, and an explicit false-positive list handed to both the reviewers and the scorer.

The same rubric appears in `skills/project/panel-review-fix/SKILL.md` for the interactive, branch-local version.

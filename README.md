# Claude Code Harness

The instructions, skills, agents, hooks and `CLAUDE.md` files I use to run [Claude Code](https://docs.anthropic.com/en/docs/claude-code) as a daily engineering harness. They grew out of about a year of shipping on a large .NET / SQL Server monorepo with on-prem Azure DevOps, Windows workstations and a team that reviews every PR.

Everything here is generalized. Company, product, host and person names are replaced with obvious placeholders (`Contoso.Payments`, `devops.example.com`, `MainDb`, work item `12345`). See [docs/placeholders.md](docs/placeholders.md) for the legend and for what was deliberately left out. The point is the shape of the harness, not the specifics of one shop.

## Why a harness

Most of the leverage in AI-assisted engineering sits outside the model:

- **Skills** turn a repeatable workflow into one command with the guardrails baked in (`/finalize-task` squashes, force-pushes with lease, opens the PR, refuses to run on `main`).
- **`CLAUDE.md`** files hold the things the model must never get wrong: which database is prod, what "success" means in a metric, which patterns are legacy-but-intentional.
- **Hooks** inject context and track sessions without anyone remembering to.
- **Agents and prompts** encode a review process (parallel reviewers, confidence scoring, false-positive lists) so that "review this PR" means the same thing every time.

The interesting design decisions are called out below; the files themselves are the reference.

## Layout

```
claude-code-harness/
├── skills/
│   ├── user/        user-scope skills  -> ~/.claude/skills/<name>/
│   └── project/     repo-scope skills  -> <repo>/.claude/skills/<name>/
├── agents/          subagent definitions -> <repo>/.claude/agents/
├── prompts/         standalone prompts for headless runs (services, claude -p)
├── hooks/           hook scripts + example settings.json wiring
├── claude-md/       CLAUDE.md templates (workspace level, repo level)
├── docs/            conventions the skills depend on, placeholder legend
└── scripts/         lint-placeholders.ps1 (keeps this repo free of real identifiers)
```

Skills are plain `SKILL.md` files with frontmatter. Copy a folder to the right location and it is live; there is no build step.

## Start here

If you only read five things:

1. [`skills/project/panel-review`](skills/project/panel-review/SKILL.md). Ten-step review of a PR, a branch or a set of paths: eligibility gate (a PR with no linked work item is a hard stop), five parallel reviewer agents (standards, bugs, git history, test quality, requirements vs. the work item), confidence scoring, an explicit list of intentional-legacy patterns to ignore, and the human decides whether anything gets posted.
2. [`skills/project/panel-review-fix`](skills/project/panel-review-fix/SKILL.md) and [`prompts/automated-pr-reviewer.md`](prompts/automated-pr-reviewer.md). The same review idea in two other shapes: a branch-local skill that proposes surgical fixes (manual / auto / review-only, marker file gates the PR-create hook) and a headless prompt for a review service (`{{PR_ID}}` templating, `REVIEW_START` / `FIXES_START` / `SCORES_START` output contract, `oldText` must appear exactly once). The scoring rubric with its special rules (untested new branches score 80 minimum, bug + missing test cross-validate to 85+, "make it configurable" caps at 50) is the part worth stealing.
3. [`skills/user/daily`](skills/user/daily/SKILL.md) and [`skills/user/find-session`](skills/user/find-session/SKILL.md). Two PowerShell helpers that mine Claude Code's own transcripts: a stand-up report from what actually happened across every session, and a session finder that searches full conversation bodies. The `find-session` notes explain why naive grep over `.jsonl` transcripts is wrong in three specific ways.
4. [`skills/project/devops-workitem-create`](skills/project/devops-workitem-create/SKILL.md). Work item content shapes (Story / Enabler / Spike) with one rule that matters: do not invent a fake actor. If the honest beneficiary is "the system", it is an enabler, not a user story.
5. [`claude-md/dotnet-monorepo.CLAUDE.md`](claude-md/dotnet-monorepo.CLAUDE.md). A repo-level `CLAUDE.md` with the rules learned the hard way: never query prod (with the incident that made it a rule), staging is the source of truth for stored procedures because the repo copies drift, and the honesty / anti-hallucination block at the end.

## Skills

### User scope (`skills/user/`)

| Skill | What it does |
|---|---|
| `q` | Answer-only mode. One or two sentences, no preamble, no next steps, minimal tool use. Triggered by `/q` or a `q:` prefix. |
| `council` | Convene Claude + Gemini + Codex on a decision: frame, gather in parallel, map agreement / disagreement zones, at most two rounds, Claude decides and logs. |
| `ask-gemini`, `ask-codex` | The two single-model consults the council is built from. Treat the answer as one voice, not an oracle. |
| `daily` | Stand-up / end-of-day report reconstructed from every session in a window, cross-referenced with git and PR state. Hard rules: one line per item, group by work item not by session, state the true shipped state (`merged` / `PR open` / `committed, not pushed` / `local only`), do not invent progress. |
| `find-session` | Find or resume a past session by directory, branch, work item or any topic discussed mid-conversation. |
| `merged-prs` | What got merged across all DevOps projects in the last N hours / days, grouped by repo, with a themes paragraph. |
| `mm-notify` | Post a message to your own Mattermost DM (credentials from env vars). |
| `optimize-prompt` | Rewrite a vague prompt into a precise one. Preserve intent, do not add requirements, output only the prompt. |

### Project scope (`skills/project/`)

| Group | Skills | Notes |
|---|---|---|
| Git workflow | `starttask`, `cleanup-worktree`, `finalize-task`, `merge-main`, `rebase-main`, `pr` | Worktree-per-work-item flow with short Windows-safe paths. `finalize-task` squashes, pushes with `--force-with-lease`, opens the PR. `rebase-main` aborts rather than guess on ambiguous conflicts and never touches `main`. |
| Azure DevOps | `devops-workitem-create`, `devops-workitem-read`, `devops-workitem-update`, `devops-wiki-update` | REST API via PowerShell `Invoke-RestMethod -UseDefaultCredentials` (Windows Integrated auth). Wiki update handles ETags and the non-standard Mermaid fence Azure DevOps wants. |
| Review | `panel-review`, `panel-review-fix` | See "Start here". `panel-review` takes a PR id, a branch, or paths. |
| Build and test | `build`, `test`, `find-code` | Thin, but they encode the things that bite: warnings suppressed by default, never run all integration tests (over an hour), where each layer lives. |
| Database | `db-query`, `db-search` | `sqlcmd` against staging / dev only; search over nightly scripted-out DB objects. |
| Observability | `dd-errors` | Datadog logs search with flexible argument parsing and env-var keys. |

## Agents and prompts

- [`agents/product-owner-expert.md`](agents/product-owner-expert.md): a read-only subagent that answers "what should the system do" from the project's documentation, distinguishes documented requirements from inference, and says so when the spec is silent.
- [`prompts/automated-pr-reviewer.md`](prompts/automated-pr-reviewer.md): the prompt behind a Windows service that polls Azure DevOps for active PRs, reviews them through the API and posts threads back. See [`prompts/README.md`](prompts/README.md) for the orchestrator contract.

## Hooks

| Hook | Event | What it does |
|---|---|---|
| `kiss.py` | `UserPromptSubmit` | Injects a short principles line into every turn (DRY, YAGNI, KISS, halt for confirmation after plans, speak plainly, end with an animal emoji so you can see the hook fired). |
| `track-session.ps1` | `UserPromptSubmit`, `Stop` | Appends `{ts, session, cwd, branch, work items, prompt snippet}` to a JSONL tracker. |
| `track-tooluse.ps1` | `PostToolUse` | Writes the last tool name to a per-session temp file for a status line to read. |
| `load-context.ps1` | `SessionStart` | Fetches centralized context for the current directory from a local HTTP service and injects it. |

Wiring is in [`hooks/README.md`](hooks/README.md) and [`hooks/settings.example.json`](hooks/settings.example.json).

## CLAUDE.md layering

Three levels, each narrower than the last:

1. **Global** (`~/.claude/CLAUDE.md`): personal conventions. The two this repo depends on are in [docs/conventions.md](docs/conventions.md): the end-of-turn `**Did:**` footer that `/daily` parses, and the `q:` prefix.
2. **Workspace** ([`claude-md/workspace.CLAUDE.md`](claude-md/workspace.CLAUDE.md)): sits above all repos and worktrees. Branch and directory naming, worktree rules, DB connection policy, coding standards shared across repos, where temp files go.
3. **Repo** ([`claude-md/dotnet-monorepo.CLAUDE.md`](claude-md/dotnet-monorepo.CLAUDE.md)): solutions, databases, safety rules, C# conventions, testing conventions, honesty rules.

## Design principles you will see repeated

- **Safety rails are explicit and have no exceptions.** Never rebase `main`. `--force-with-lease`, never `--force`. Never query prod, not even `SELECT TOP 5`. Scope process kills to PIDs. Abort a rebase rather than guess.
- **The human takes the irreversible step.** Reviews are shown before they are posted. Remote branches are deleted only after asking. Fixes are applied one at a time unless `--auto` was requested.
- **Signal over noise.** Confidence thresholds, explicit false-positive lists, "skip rather than suggest a bad fix", never fabricate work item IDs.
- **Honesty is a feature.** "Give your honest assessment." "Do not invent progress." A commit is not a PR, a PR is not merged, SQL written is not SQL run.
- **Configuration lives in `CLAUDE.md`, procedure lives in the skill.** `db-query` says "connection details are in CLAUDE.md"; the skill does not need editing when a server moves.
- **Windows first.** PowerShell over curl for anything with Windows auth, temp files over inline strings for anything with quotes, short paths everywhere.

## Environment assumptions

Windows 11, PowerShell 7, Git for Windows (Git Bash), Azure DevOps Server (on-prem, Windows Integrated auth), SQL Server with `sqlcmd`, .NET 8 with NUnit, Datadog, Mattermost, and the `codex` / `gemini` CLIs for the council. GitHub users can swap the DevOps REST calls for `gh`; the flow is the same.

## Installing

```powershell
# user-scope skills
Copy-Item -Recurse skills\user\* "$env:USERPROFILE\.claude\skills\"

# project-scope skills, agents (inside your repo)
Copy-Item -Recurse skills\project\* <repo>\.claude\skills\
Copy-Item agents\*.md <repo>\.claude\agents\

# hooks: see hooks\README.md
```

Then replace the placeholders (`docs/placeholders.md`) with your own values, mostly in `claude-md/*` and the DevOps skills.

## License

MIT. Use what is useful, keep what works.

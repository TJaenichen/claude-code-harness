# CLAUDE.md templates

Two levels of the three-level layering described in the main README (global, workspace, repo). The global level is personal and lives in `~/.claude/CLAUDE.md`; the conventions the skills need from it are in `docs/conventions.md`.

| File | Goes to | Holds |
|---|---|---|
| `workspace.CLAUDE.md` | The parent folder of all repos and worktrees (`C:\work\CLAUDE.md`) | Environment notes, safety, branch and worktree naming, DB connection policy, coding and testing standards shared across repos, scratchpad rule |
| `dotnet-monorepo.CLAUDE.md` | The repo root | What the repo is, solutions, databases with the never-query-prod rule, stored-procedure source-of-truth rule, C# conventions, unit and integration test conventions, git workflow, honesty and anti-hallucination rules |

Both files carry an HTML comment at the top explaining what is placeholder. Strip the comment when you adopt them.

Things worth keeping even if the rest does not fit your stack:

- The **never query prod** block, including the incident that made it a rule and the explicit "this applies to automated workloads too". Rules with a story behind them get followed.
- **STG is the source of truth for stored procedures**: repo copies of SQL drift when DBAs hotfix in place. Anywhere you have a second copy of something, say which one wins.
- The **Honest Assessment** and **Anti-Hallucination Rules** sections at the end. Four lines that noticeably change how the model reports uncertain findings.
- **Every test must provide real value.** One sentence that stops coverage-padding.

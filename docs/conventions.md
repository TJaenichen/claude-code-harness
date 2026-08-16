# Conventions the skills depend on

A few skills in this repo assume conventions that live in the user's global `~/.claude/CLAUDE.md`, not in the skill files. This page states the minimum those skills need, as copy-pasteable blocks.

## 1. End-of-turn footer with a `Did:` line

`/daily` (`Get-DailyWork.ps1`) builds its stand-up report primarily from a one-line `**Did:**` summary the model writes at the end of every real-work turn. That is a far better signal than reconstructing intent from prompts. Without the convention `/daily` still works, but it falls back to prompts and edited files.

Add to your global `CLAUDE.md`:

```markdown
## End-of-turn footer

End every turn that did real work (edited files, ran commands that changed
state, produced an artifact) with a short orientation footer as the last
lines of the response:

**Did:** <one line: what was actually accomplished this turn>
**Next:** <one line: the obvious next step, or "none">

Rules: one line each, no sub-bullets. Say the true state (committed vs pushed
vs PR open vs merged). Pure Q&A turns and answer-only (`q:`) turns have no
footer.
```

The parser (see `Read-SessionDigest` in `skills/user/daily/Get-DailyWork.ps1`) anchors on a line that *starts* with `**Did:**`, so keep it at the start of its own line and keep the bold markers.

## 2. `q:` prefix for answer-only turns

`/q` is a skill, but the same behaviour is also triggered by prefixing a prompt with `q:`. That needs one line in the global `CLAUDE.md`:

```markdown
## Answer-only mode

If a prompt starts with `q:` (or `/q`), answer the question and nothing else:
no preamble, no context, no next steps, no footer, minimal tool use, one or
two sentences. See the `q` skill for the full rules.
```

`/daily` deliberately omits `q:` sessions from the report.

## 3. Worktree and branch naming

Several project skills (`starttask`, `cleanup-worktree`, `finalize-task`, `track-session.ps1`, `daily`) assume:

- Branch: `feature/<workitemid>_<ShortTitle>` (ShortTitle at most 15 characters)
- Directory: `C:\work\<workitemid>_<ShortTitle>` (no `feature-` prefix, keeps Windows paths short)
- All worktrees live next to the main checkout, one worktree per work item

The full rules are in `claude-md/workspace.CLAUDE.md`.

## 4. Scratchpad, not the worktree

Temporary scripts, SQL, JSON bodies for API calls and notes go under `C:\work\scratchpad`, never inside a repo or worktree. Several skills say "save the PowerShell script to a temp file to avoid escaping issues"; that temp file goes to the scratchpad.

## 5. Windows Integrated auth everywhere

The Azure DevOps skills assume the workstation is domain-joined and the DevOps server accepts Kerberos / NTLM:

- PowerShell: `Invoke-RestMethod ... -UseDefaultCredentials`
- curl: `curl -L --negotiate -u : <url>` (or `--ntlm`)

No PATs are stored anywhere. If your server needs a token, add an `Authorization` header sourced from an environment variable and read it with `printenv`, the same way `dd-errors` and `mm-notify` do.

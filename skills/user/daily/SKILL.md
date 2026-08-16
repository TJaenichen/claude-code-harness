---
name: daily
description: Summarize everything worked on across all Claude Code sessions in a time window — a stand-up / end-of-day report. Defaults to the last 24 hours, and automatically reaches back to Friday when run on a Monday or weekend. Use when the user asks "what did I do today / yesterday / since Friday", wants a stand-up summary, or a recap of recent work.
argument-hint: "[window, e.g. 24h, 48h, 3d, week, or 'since 2026-08-01' — omit for auto (24h, or Friday->now on Mon/weekend)]"
user-invocable: true
---

# Daily Work Report

Reconstructs what was actually worked on by digesting every Claude Code session
transcript active in a time window, then cross-referencing git commits so the
report reflects real output rather than just conversation.

## Arguments

`$ARGUMENTS` — optional window. Accepted forms:

| Input | Meaning |
|---|---|
| *(empty)* | Auto: last 24h, or **back to Friday 00:00** when run on Sat/Sun/Mon |
| `24h`, `48h`, `72h` | Hours back from now |
| `2d`, `3d`, `7d`, `week` | Days back from now (`week` = 7d) |
| `since <date>` / `<date>` | Explicit start, e.g. `since 2026-08-01`, `2026-08-01 09:00` |
| `yesterday` | 00:00 of yesterday → now |

Map that onto the helper's `-Hours` / `-Since` parameters. Never pass both.

## Step 1 — Digest the sessions

```powershell
& "$env:USERPROFILE\.claude\skills\daily\Get-DailyWork.ps1"            # auto window
& "$env:USERPROFILE\.claude\skills\daily\Get-DailyWork.ps1" -Hours 48
& "$env:USERPROFILE\.claude\skills\daily\Get-DailyWork.ps1" -Since '2026-08-01'
```

Per session it reports: launch dir, branch, work item, active span, whether the
session was resumed, the user's prompts, slash commands invoked, files
written/edited, PR/WI numbers referenced, and — most importantly — the
**`Did:`** lines from the mandated end-of-turn orientation footer. Those are
self-authored one-line summaries of each real-work turn and are the backbone of
the report; prefer them over re-deriving intent from prompts.

Filtering is **per entry, not per file**: a session resumed today but started
weeks ago contributes only its in-window slice. Sessions marked *(resumed)*
began before the window — do not describe their earlier work as today's.

For a stand-up the `Did:` lines carry almost all the signal, so keep the prompt
and file noise down: `-MaxPrompts 6 -MaxFiles 6`. Raise them only for a session
that has no `Did:` lines and needs its topic inferred from what was asked.
`-MaxDids` and `-Json` are also available. Expect ~5s for a 24h window (it
streams 100+ MB of transcripts).

## Step 2 — Cross-reference git

Sessions show intent; commits show what landed. All `C:\work\<ID>_<Title>`
worktrees share the main repo, so one `--all` log covers every worktree:

```bash
git -C /c/work/Payments log --all --no-merges --since="<window start>" \
    --author="$(git -C /c/work/Payments config user.name)" \
    --date=format:'%m-%d %H:%M' --pretty=format:'%ad %h %d %s'
```

If the digest shows sessions in launch dirs outside `C:\work\Payments` (e.g.
`C:\work\other-repo`), run the same log in those repos too. Also list
uncommitted work-in-progress where it matters: `git -C <dir> status --short`.

## Step 3 — Resolve PR state

Each line has to say whether the work is merged or still open, so look up every
PR the digest referenced — one call each, cheap:

```bash
for id in <ids from the digest>; do
  curl -s -L --negotiate -u : \
    "https://devops.example.com/DefaultCollection/MyProject/_apis/git/pullrequests/$id?api-version=7.0" \
    | grep -oE '"(status|title)":"[^"]*"' | head -2
done
```

`active` = open, `completed` = merged. The PR title is also the most reliable
source for an item's **name** and work item number.

For a window ≥48h the `merged-prs` skill gives the broader shipped-to-main view,
but skip it when the git log and PR states already answer the question.

## Step 4 — Render the report

This is a **stand-up list**. One line per item, three fields, nothing else:

```
<WI/PR ID>, <Name>, <one line summary>
```

Output exactly this shape — a flat bullet list, most substantial work first:

```markdown
## Stand-up — Fri 2026-08-07 (last 24h)

- **#12345**, Auto-payout customer block, PR 4321 open; 6-agent review closed, all fixes in, both release tasks done.
- **#12346**, Auto-payout processing + shadow report, built end to end, 21 tests green, committed but not pushed — no PR yet.
- **PR 4310**, Deposit limits review, reviewed on request; findings shared in-session only, not posted.
- **#12290**, Routing report data gap, not a bug — localhost reads staging, whose prod snapshot ends 08-02.
```

Hard rules:

- **One line per item. No sub-bullets, no per-item detail block, no session
  IDs, no file counts, no timestamps, no branch names.** If a line needs a
  second line, cut it down instead.
- **Group by work item / topic, not by session.** One topic often spans several
  sessions, and one long session often spans several topics. Merge them into
  one line.
- **The ID comes from the work, not the branch.** Take it from `#NNNNN` in
  commit subjects, the digest's `WIs referenced` / `PRs referenced` lines, or
  the PR title. Do **not** use the digest's branch-derived `WI` field — when
  sessions are launched from `C:\work\Payments` rather than a per-WI worktree, every
  one of them inherits that checkout's unrelated work item. Use `PR <id>` as
  the ID when there is no work item (e.g. reviewing someone else's PR).
- **State the true shipped state in the summary clause**, in the fewest words:
  *merged* / *PR open* / *committed, not pushed* / *local only* / *analysis
  only*. A commit is not a PR; a PR is not merged; SQL written is not SQL run.
- **Do not invent progress.** A session with a few prompts, no `Did:` lines, no
  commits and no files is not an accomplishment — either give it an honest
  "explored X, no conclusion" line or leave it out.
- **Omit noise entirely**: `q:` answer-only sessions, aborted sessions, and
  sessions with no meaningful activity. No "N sessions skipped" reconciliation
  line — this is a stand-up, not an audit.
- Include the current session only if actual work happened in it.
- Add a `Blocked:` line at the end **only** if something genuinely cannot
  proceed without someone else. Otherwise end after the list.

## Notes

- Everything here is read-only — no repo, DB or DevOps state is modified.
- The `Did:` extraction depends on the end-of-turn footer convention in the
  user's global CLAUDE.md (see `docs/conventions.md` in this repo). Answer-only (`q:`) turns and pure Q&A turns have no
  footer by design, so a session can be legitimately `Did:`-less; fall back to
  prompts and files for those.
- Subagent sidechain transcripts (`agent-*.jsonl`) are excluded — their work
  shows up under the parent session.

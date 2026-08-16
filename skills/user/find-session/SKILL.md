---
name: find-session
description: List or search recent Claude Code sessions with their IDs, original launch directories, and last-active times, so you can resume the right one. Searches full conversation bodies, so it finds a topic discussed mid-session. Use when you need to find or resume a past session by recency, directory, branch, work item, or keyword.
argument-hint: "[search term — work item ID, directory, branch, or any topic discussed] (omit to list most recent)"
user-invocable: true
---

# Find Session

Lists recent Claude Code sessions (or searches them) using the
`Get-ClaudeSessions.ps1` helper in this skill directory. The helper reads each
session transcript under `~/.claude/projects/` and reports, per session:
its **session ID**, **original launch directory** (where it must be resumed
from), **last-active time**, git branch, and first prompt.

With `-Match`, it also scans **every message in the transcript**, so a topic
raised in the middle of a long session is found — not just one named in the
opening prompt.

## Instructions

1. **Run the helper.** It lives next to this file. Pass `$ARGUMENTS` as the
   `-Match` filter when the user gave a search term; omit it to list the most
   recent sessions.

   ```powershell
   # List the 15 most recently active sessions
   & "$env:USERPROFILE\.claude\skills\find-session\Get-ClaudeSessions.ps1" -Limit 15

   # Search everything — id, dir, branch, first prompt, and full conversation
   & "$env:USERPROFILE\.claude\skills\find-session\Get-ClaudeSessions.ps1" -Match "$ARGUMENTS" -Limit 15
   ```

   **Always pass `-ExcludeSession <current session id>` when searching.** The
   live conversation contains the search term by definition — the user just
   typed it — so without this it ranks first and buries the real answer. Take
   the id from the scratchpad path in your system prompt (the UUID segment).

   ```powershell
   & "$env:USERPROFILE\.claude\skills\find-session\Get-ClaudeSessions.ps1" `
       -Match "$ARGUMENTS" -ExcludeSession '<this-session-uuid>' -Limit 15
   ```

   A full-corpus body scan takes ~1-3s. Add `-HeadOnly` to restrict the match to
   id / dir / branch / first prompt if you only want to identify a session by
   where it ran.

2. **Display** the returned objects as a clear list, best match first. The
   **launch directory** is the single most important field — it's where the
   user must `cd` before resuming. For each session show:

   ```
   <ShortId> — "<Summary>"
     Launch dir  : C:\work\12345_ShortTitle   ← cd here to resume
     Branch      : feature/12345_ShortTitle
     Last active : 2026-06-16 14:02  (0d 2h ago)
     Mentioned   : 2026-06-16 13:41  (16 times, last by assistant)
     Context     : "...<Snippet>..."
     Resume      : cd "C:\work\12345_ShortTitle"; claude --resume <full SessionId>
   ```

   Report `LastMention` when it's present — for "when did we last discuss X"
   that is the answer, and it can differ a lot from `LastActive` (a session
   touched today for unrelated work may have discussed the term days ago). Quote
   the `Snippet` so the user can confirm it's the thread they meant.

   The helper emits a ready-to-paste `ResumeCmd`. You can also format the raw
   objects directly, e.g.
   `... | Format-Table ShortId, MatchedIn, MatchHits, LastMention, Branch, Summary -AutoSize -Wrap`.

3. **Rank and qualify by `MatchedIn`.** Results are already ordered so real
   mentions come first, but say which kind each is:

   | `MatchedIn` | Meaning |
   |---|---|
   | `Head` | id / launch dir / branch / first prompt |
   | `Body` | said in conversation by the user or Claude — the strongest signal |
   | `Head+Body` | both |
   | `Tool` | **only** inside tool traffic (a grep result, an API response, a file read) — usually incidental, e.g. a `/daily` run that swept the transcripts. Mention these as "possibly incidental", don't lead with them. |

   `MatchHits` counts spoken occurrences; `ToolHits` counts tool traffic.

4. **No matches / no sessions.** If the helper returns nothing with a filter,
   say so and offer to list recent sessions instead (re-run with no `-Match`).
   If `~/.claude/projects` doesn't exist, tell the user no sessions are tracked
   yet.

## Notes

- Last-active comes from the transcript file's modified time — the real signal
  for "which session did I touch most recently."
- Subagent sidechain transcripts (`agent-*.jsonl`) and empty/aborted sessions
  are excluded automatically.
- The per-directory `sessions-index.json` files are unreliable placeholders in
  this environment, so the helper deliberately reads the transcripts directly.
- **Don't hand-roll this with `rg` / `Select-String` over the `.jsonl` files.**
  The helper exists because raw grep on transcripts is wrong in three ways, all
  observed in practice:
  - **False positives** — a bare number matches metadata. Searching `12345`
    "hit" a session that never discussed it: the digits sit inside the message
    UUID `c1234567-...`. Token counts and request ids collide the same way. The
    helper only matches inside message content.
  - **Injected context** — every session carries `CLAUDE.md`/`MEMORY.md` inside
    `<system-reminder>` blocks, so grepping any term those files mention matches
    nearly every session. The helper strips those blocks before counting.
  - **Missed files** — `Select-String -List` silently skipped a transcript
    holding 13 occurrences (very long single-line JSON). The helper's per-line
    `IndexOf` scan does not.
- Only lines whose raw text contains the needle get parsed as JSON, which keeps
  the scan fast (~1-3s over ~175 MB / ~95 transcripts, incl. a 46 MB one).

# Hooks

Small scripts Claude Code runs on lifecycle events. Each one reads the event JSON from stdin (or a parameter), does one thing, and exits 0 no matter what so it can never block a session.

| Script | Event | Effect |
|---|---|---|
| `kiss.py` | `UserPromptSubmit` | Returns `additionalContext` with a one-line principles reminder (DRY, YAGNI, KISS, halt after plans for confirmation, speak plainly, end with an animal emoji). The emoji is a cheap visual check that the hook is firing. |
| `track-session.ps1` | `UserPromptSubmit`, `Stop` | Appends one compact JSON line per event to `~/.claude/session-tracker.jsonl`: timestamp, session id, cwd, git branch, work item ids extracted from branch / cwd / prompt, a 200-char prompt snippet, transcript path. Cheap to write, useful later for "what was I doing on Tuesday". |
| `track-tooluse.ps1` | `PostToolUse` | Writes `<epoch>|<tool name>` to `%TEMP%\claude-sl-tool-<session8>.tmp`, overwritten each time. A status line script can poll it to show the last tool used. |
| `load-context.ps1` | `SessionStart` | Calls a local HTTP service with the session's cwd and prints whatever context it returns; stdout of a `SessionStart` hook is injected into the conversation. Point the URI at your own service (anything that maps a path to a block of markdown). Logs to `~/.claude/hooks/load-context-debug.log`. |

## Wiring

Copy the scripts to `~/.claude/hooks/` and merge `settings.example.json` into `~/.claude/settings.json` (or a project's `.claude/settings.json`).

Notes on the command strings:

- Hook commands run through a shell. On Windows the JSON payload arrives on stdin, so the PowerShell scripts are invoked as `pwsh -NoProfile -Command "[Console]::In.ReadToEnd() | pwsh -NoProfile -File <script>"`. `load-context.ps1` takes the JSON as a parameter instead, which is why its command reads stdin into `$j` first.
- Quoting is the fragile part. If a hook silently does nothing, run `claude --debug` and watch for the hook's stderr, or add a `Write-DebugLog` like `load-context.ps1` does.
- Keep hooks fast. `SessionStart` runs before the first prompt; the context call has a 5-second timeout for that reason.

## Event payloads used

| Field | Used by |
|---|---|
| `session_id` | all three PowerShell hooks |
| `cwd` | `track-session.ps1`, `load-context.ps1` |
| `hook_event_name` | `track-session.ps1` |
| `prompt` (`UserPromptSubmit` only) | `track-session.ps1` |
| `transcript_path` | `track-session.ps1` |
| `tool_name` (`PostToolUse`) | `track-tooluse.ps1` |

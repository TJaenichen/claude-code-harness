# track-tooluse.ps1 — PostToolUse hook
# Writes last tool name to a per-session temp file for the statusline to read.
# One file per session, overwritten each time — no accumulation.
param(
    [Parameter(ValueFromPipeline=$true)]
    [string]$PipedInput
)
$ErrorActionPreference = 'SilentlyContinue'

$jsonInput = if ($PipedInput) { $PipedInput } else { [Console]::In.ReadToEnd() }
if (-not $jsonInput) { exit 0 }
$data = $jsonInput | ConvertFrom-Json
if (-not $data.session_id -or -not $data.tool_name) { exit 0 }

# Write tool name + epoch seconds to a per-session file
$sid = $data.session_id.Substring(0, 8)
$file = "$env:TEMP\claude-sl-tool-${sid}.tmp"
$ts = [math]::Floor((Get-Date -UFormat %s))
[System.IO.File]::WriteAllText($file, "${ts}|$($data.tool_name)")

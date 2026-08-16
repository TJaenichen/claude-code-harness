# track-session.ps1 — Hook script for Stop and UserPromptSubmit events
# Appends session tracking data to ~/.claude/session-tracker.jsonl
#
# Called via: pwsh -NoProfile -Command "... | pwsh -NoProfile -File track-session.ps1"
# or via:    pwsh -NoProfile -Command "[Console]::In.ReadToEnd() | ... "
param(
    [Parameter(ValueFromPipeline=$true)]
    [string]$PipedInput
)
$ErrorActionPreference = 'SilentlyContinue'

# Accept input from pipeline param or stdin
$jsonInput = if ($PipedInput) { $PipedInput } else { [Console]::In.ReadToEnd() }
if (-not $jsonInput) { exit 0 }
$data = $jsonInput | ConvertFrom-Json
if (-not $data.session_id) { exit 0 }

$sessionId = $data.session_id
$cwd = if ($data.cwd) { $data.cwd } else { $PWD.Path }
$event = $data.hook_event_name
$timestamp = Get-Date -Format "o"
$transcriptPath = $data.transcript_path

# Get git branch from cwd
$branch = ""
try {
    $branch = (git -C $cwd rev-parse --abbrev-ref HEAD 2>$null)
    if ($branch -eq "HEAD") { $branch = "" }
} catch {}

# Collect work item IDs
$workItems = [System.Collections.Generic.HashSet[string]]::new()

# Extract from branch name: feature/<id>_...
if ($branch -match '(\d{4,6})') {
    [void]$workItems.Add($Matches[1])
}

# Extract from cwd path (e.g. C:\work\12345_ShortTitle)
if ($cwd -match '[\\/](\d{4,6})[-_]') {
    [void]$workItems.Add($Matches[1])
}

# Extract from prompt text (UserPromptSubmit only)
$promptSnippet = ""
if ($event -eq "UserPromptSubmit" -and $data.prompt) {
    $promptSnippet = if ($data.prompt.Length -gt 200) { $data.prompt.Substring(0, 200) } else { $data.prompt }
    $rx = [regex]'\b(\d{5})\b'
    $found = $rx.Matches($data.prompt)
    foreach ($m in $found) {
        [void]$workItems.Add($m.Groups[1].Value)
    }
}

# Build entry — short keys to keep file compact
$entry = [ordered]@{
    ts = $timestamp
    sid = $sessionId
    ev = $event
    cwd = $cwd
    br = $branch
    wi = @($workItems)
}
if ($promptSnippet) { $entry.pr = $promptSnippet }
if ($transcriptPath) { $entry.tp = $transcriptPath }

$line = $entry | ConvertTo-Json -Compress
$trackerFile = Join-Path $env:USERPROFILE ".claude\session-tracker.jsonl"
[System.IO.File]::AppendAllText($trackerFile, "$line`n", [System.Text.Encoding]::UTF8)

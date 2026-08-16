<#
.SYNOPSIS
    Lists recent Claude Code sessions with their IDs, original launch directories,
    and last-active times so you can pick the right one to resume.

.DESCRIPTION
    Sessions live as UUID-named .jsonl transcripts under
    ~/.claude/projects/<encoded-launch-dir>/. This helper reads each transcript
    directly (the per-dir sessions-index.json files are unreliable placeholders in
    this environment), pulling the original launch cwd, git branch, and first
    prompt from the transcript, and the real last-active time from the file mtime.

    When -Match is supplied, every transcript is also scanned end-to-end so
    mid-conversation mentions are found, not just the first prompt. Hits are
    counted separately for conversation text (MatchHits) and tool traffic
    (ToolHits), and the timestamp/snippet of the last mention is reported.

    Returns PSCustomObjects sorted by most-recent activity — or, when -Match is
    used, by most-recent mention. Pipe to Format-List or Format-Table.

.PARAMETER Match
    Case-insensitive substring filter. Matched against session id, launch dir,
    branch, first prompt, and (unless -HeadOnly) the whole transcript body.
    Omit to list everything (most recent first).

.PARAMETER HeadOnly
    Restrict -Match to the head fields (id / dir / branch / first prompt) only.
    Much faster on a large transcript corpus, but misses mid-conversation topics.

.PARAMETER ExcludeSession
    Session id(s) to drop from the results. Pass the current session's id so the
    live conversation — which contains the search term by definition, because the
    user just typed it — doesn't crowd out the real hit.

.PARAMETER Limit
    Max number of sessions to return. Default 15.

.PARAMETER ProjectsRoot
    Override the projects directory (default ~/.claude/projects).

.EXAMPLE
    .\Get-ClaudeSessions.ps1
    Lists the 15 most recently active sessions.

.EXAMPLE
    .\Get-ClaudeSessions.ps1 -Match 12345 -Limit 5
    Finds sessions that mention "12345" anywhere — path, branch, or conversation.

.EXAMPLE
    .\Get-ClaudeSessions.ps1 -Match 12345 -ExcludeSession <this-session-uuid>
    Same, ignoring the session doing the searching.
#>
[CmdletBinding()]
param(
    [string]$Match,
    [switch]$HeadOnly,
    [string[]]$ExcludeSession,
    [int]$Limit = 15,
    [string]$ProjectsRoot = (Join-Path $env:USERPROFILE '.claude\projects')
)

if (-not (Test-Path $ProjectsRoot)) {
    Write-Warning "No projects directory at $ProjectsRoot — no sessions to list yet."
    return
}

# Read launch cwd, branch, and first user prompt in a single streaming pass.
# First prompt sits near the top, so we stop as soon as we have everything.
function Read-SessionHead {
    param([string]$Path)

    $cwd = $null; $branch = $null; $prompt = $null
    $reader = [System.IO.StreamReader]::new($Path)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($cwd -and $null -ne $prompt) { break }
            if ($line -notmatch '"cwd"' -and $line -notmatch '"type":"user"') { continue }

            try { $obj = $line | ConvertFrom-Json -ErrorAction Stop }
            catch { continue }   # snapshot / non-JSON line, keep scanning

            if (-not $cwd -and $obj.cwd) {
                $cwd = $obj.cwd
                $branch = $obj.gitBranch
            }
            if ($null -eq $prompt -and $obj.type -eq 'user' -and $obj.message) {
                $c = $obj.message.content
                $text = if ($c -is [string]) { $c }
                        else { ($c | Where-Object { $_.type -eq 'text' } | Select-Object -First 1 -ExpandProperty text -ErrorAction SilentlyContinue) }
                if ($text) {
                    $text = ($text -replace '\s+', ' ').Trim()
                    # Skip command stubs / injected reminders — not a real first prompt.
                    if ($text -and $text -notmatch '^<(command|local-command|system-reminder)') {
                        $prompt = $text
                    }
                }
            }
        }
    } finally {
        $reader.Dispose()
    }
    return [pscustomobject]@{ Cwd = $cwd; Branch = $branch; Prompt = $prompt }
}

function Measure-Occurrence {
    param([string]$Haystack, [string]$Needle)

    $count = 0
    $at = 0
    while (($at = $Haystack.IndexOf($Needle, $at, [StringComparison]::OrdinalIgnoreCase)) -ge 0) {
        $count++
        $at += $Needle.Length
    }
    return $count
}

function Get-Snippet {
    param([string]$Haystack, [string]$Needle)

    $at = $Haystack.LastIndexOf($Needle, [StringComparison]::OrdinalIgnoreCase)
    if ($at -lt 0) { return '' }

    $start = [Math]::Max(0, $at - 70)
    $len = [Math]::Min($Haystack.Length - $start, $Needle.Length + 160)
    $snip = $Haystack.Substring($start, $len).Trim()
    if ($start -gt 0) { $snip = '...' + $snip }
    if (($start + $len) -lt $Haystack.Length) { $snip = $snip + '...' }
    return $snip
}

# Scan the whole transcript for $Needle. Only lines that contain it as a raw
# substring get parsed as JSON — that keeps a 46 MB transcript cheap, since the
# per-line IndexOf is a .NET call and ConvertFrom-Json runs on a handful of hits.
#
# Conversation text and tool traffic are counted separately: a term the user or
# Claude actually said is a far stronger "we discussed this" signal than one that
# only appears inside a grep result or an API response body.
function Read-SessionBodyMatch {
    param([string]$Path, [string]$Needle)

    $textHits = 0; $toolHits = 0
    $lastStamp = $null; $lastRole = $null; $lastText = $null

    # The pre-filter runs against raw JSON, where `"` is stored as `\"` and `\`
    # as `\\`. A needle like ToTable("x") or C:\work\foo would never survive it,
    # so test the JSON-escaped spelling too and let the decoded pass do the
    # real counting.
    $escaped = ($Needle | ConvertTo-Json -Compress).Trim('"')
    $variants = if ($escaped -ceq $Needle) { @($Needle) } else { @($Needle, $escaped) }

    $reader = [System.IO.StreamReader]::new($Path)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            $hit = $false
            foreach ($v in $variants) {
                if ($line.IndexOf($v, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hit = $true; break }
            }
            if (-not $hit) { continue }

            try { $obj = $line | ConvertFrom-Json -ErrorAction Stop }
            catch { continue }
            if ($obj.type -ne 'user' -and $obj.type -ne 'assistant') { continue }
            if (-not $obj.message) { continue }

            # Split this message into what was said vs what tools carried.
            $said = [System.Text.StringBuilder]::new()
            $carried = [System.Text.StringBuilder]::new()

            $content = $obj.message.content
            $blocks = if ($content -is [string]) { @([pscustomobject]@{ type = 'text'; text = $content }) } else { @($content) }

            foreach ($block in $blocks) {
                switch ($block.type) {
                    'text'        { [void]$said.Append(' ').Append($block.text) }
                    'thinking'    { [void]$said.Append(' ').Append($block.thinking) }
                    'tool_use'    { [void]$carried.Append(' ').Append(($block.input | ConvertTo-Json -Depth 6 -Compress)) }
                    'tool_result' {
                        $rc = $block.content
                        if ($rc -is [string]) { [void]$carried.Append(' ').Append($rc) }
                        else { foreach ($rb in @($rc)) { [void]$carried.Append(' ').Append($rb.text) } }
                    }
                }
            }

            # Injected CLAUDE.md / MEMORY.md / reminders ride along inside user
            # messages and mention half the codebase — they are not a discussion.
            $saidText = $said.ToString() -replace '(?s)<system-reminder>.*?</system-reminder>', ' '
            $saidText = $saidText -replace '(?s)<local-command-stdout>.*?</local-command-stdout>', ' '
            $saidText = ($saidText -replace '\s+', ' ').Trim()

            $n = Measure-Occurrence -Haystack $saidText -Needle $Needle
            if ($n -gt 0) {
                $textHits += $n
                $lastStamp = $obj.timestamp
                $lastRole = $obj.type
                $lastText = $saidText
            }

            if ($carried.Length -gt 0) {
                $toolText = ($carried.ToString() -replace '\s+', ' ')
                $m = Measure-Occurrence -Haystack $toolText -Needle $Needle
                if ($m -gt 0) {
                    $toolHits += $m
                    if ($n -eq 0 -and -not $lastText) {
                        # No spoken mention yet — keep the tool one as a fallback.
                        $lastStamp = $obj.timestamp
                        $lastRole = "$($obj.type) (tool)"
                        $lastText = $toolText
                    }
                }
            }
        }
    } finally {
        $reader.Dispose()
    }

    $stamp = $null
    if ($lastStamp) {
        try { $stamp = ([datetime]$lastStamp).ToLocalTime() } catch { $stamp = $null }
    }

    return [pscustomobject]@{
        TextHits    = $textHits
        ToolHits    = $toolHits
        LastMention = $stamp
        LastRole    = $lastRole
        Snippet     = if ($lastText) { Get-Snippet -Haystack $lastText -Needle $Needle } else { '' }
    }
}

# Enumerate every real session transcript (UUID-named, excluding agent sidechains).
$sessions = foreach ($file in Get-ChildItem $ProjectsRoot -Recurse -File -Filter '*.jsonl') {
    if ($file.Name -like 'agent-*')                    { continue }   # subagent sidechain
    if ($file.Length -eq 0)                            { continue }   # empty / aborted
    if ($file.BaseName -notmatch '^[0-9a-fA-F-]{36}$') { continue }   # not a session UUID
    if ($ExcludeSession -contains $file.BaseName)      { continue }   # e.g. the caller itself

    $head = Read-SessionHead -Path $file.FullName

    $summary = if ($head.Prompt) {
        if ($head.Prompt.Length -gt 100) { $head.Prompt.Substring(0, 99) + '...' } else { $head.Prompt }
    } else { '' }

    $headMatch = $false
    $body = $null
    if ($Match) {
        $headMatch = "$($file.BaseName) $($head.Cwd) $($head.Branch) $($summary)".IndexOf($Match, [StringComparison]::OrdinalIgnoreCase) -ge 0
        if (-not $HeadOnly) {
            $body = Read-SessionBodyMatch -Path $file.FullName -Needle $Match
        }
        $bodyMatch = $body -and (($body.TextHits + $body.ToolHits) -gt 0)
        if (-not $headMatch -and -not $bodyMatch) { continue }
    }

    $last = $file.LastWriteTime   # authoritative last-active (real mtime)
    $age  = (Get-Date) - $last

    $where = if (-not $Match) { $null }
             elseif ($headMatch -and $body -and $body.TextHits -gt 0) { 'Head+Body' }
             elseif ($headMatch -and $body -and $body.ToolHits -gt 0) { 'Head+Tool' }
             elseif ($headMatch) { 'Head' }
             elseif ($body.TextHits -gt 0) { 'Body' }
             else { 'Tool' }

    # Rank tier: anything actually said (or matched on dir/branch/first prompt)
    # beats a term that only turned up inside tool traffic — otherwise a /daily
    # report that grepped the corpus outranks the session that discussed the topic.
    $tier = if (-not $Match) { 0 }
            elseif ($headMatch -or $body.TextHits -gt 0) { 0 }
            else { 1 }

    [pscustomobject]@{
        SessionId   = $file.BaseName
        ShortId     = $file.BaseName.Substring(0, 8)
        Tier        = $tier
        LaunchDir   = $head.Cwd
        Branch      = $head.Branch
        Summary     = $summary
        LastActive  = $last
        Age         = '{0,2}d {1,2}h ago' -f [int]$age.TotalDays, $age.Hours
        MatchedIn   = $where
        MatchHits   = if ($body) { $body.TextHits } else { $null }
        ToolHits    = if ($body) { $body.ToolHits } else { $null }
        LastMention = if ($body) { $body.LastMention } else { $null }
        MentionRole = if ($body) { $body.LastRole } else { $null }
        Snippet     = if ($body) { $body.Snippet } else { $null }
        ResumeCmd   = if ($head.Cwd) { "cd `"$($head.Cwd)`"; claude --resume $($file.BaseName)" }
                      else { "claude --resume $($file.BaseName)" }
    }
}

# With -Match, "when did we last talk about this" beats raw file mtime; a session
# touched today for unrelated work shouldn't outrank one that discussed the term.
$sessions |
    Sort-Object -Property @{ Expression = 'Tier'; Descending = $false },
                          @{ Expression = { if ($_.LastMention) { $_.LastMention } else { $_.LastActive } }; Descending = $true } |
    Select-Object -First $Limit |
    Select-Object -ExcludeProperty Tier -Property *

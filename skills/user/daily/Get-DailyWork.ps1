<#
.SYNOPSIS
    Digests every Claude Code session that was active in a time window into a
    compact, readable summary of what was actually worked on.

.DESCRIPTION
    Sessions live as UUID-named .jsonl transcripts under ~/.claude/projects/.
    This helper streams each transcript whose mtime falls in the window and
    extracts, for entries timestamped inside the window only:

      * real user prompts (tool results, hook injections, skill preambles and
        system reminders are filtered out)
      * slash commands invoked
      * the "**Did:**" lines from the mandated end-of-turn orientation footer
        (the single best per-turn summary of work performed)
      * files created/edited (Edit / Write / NotebookEdit tool calls)
      * pull request and work item IDs referenced anywhere in the session

    Entry-level (not file-level) window filtering matters: a long-running
    session resumed today may have started weeks ago, and only today's slice
    belongs in today's report.

    Output is a text digest on stdout (token-cheap, meant to be read by Claude
    or a human). Use -Json for structured output instead.

.PARAMETER Hours
    Window length in hours, counted back from now. Ignored if -Since is given.

.PARAMETER Since
    Explicit window start (local time). Overrides -Hours.

.PARAMETER Auto
    Pick the window automatically: 24h normally, but back to 00:00 of the most
    recent Friday when run on a Saturday, Sunday or Monday (so a Monday morning
    report covers Friday plus the weekend). This is the default when neither
    -Hours nor -Since is supplied.

.PARAMETER MaxPrompts
    Max user prompts reported per session (default 25). Excess is noted.

.PARAMETER MaxFiles
    Max distinct file names reported per session (default 20).

.PARAMETER MaxDids
    Max "**Did:**" footer lines reported per session (default 25).

.PARAMETER Json
    Emit structured JSON instead of the text digest.

.EXAMPLE
    .\Get-DailyWork.ps1
    Auto window (24h, or Friday-to-now if it is the weekend / Monday).

.EXAMPLE
    .\Get-DailyWork.ps1 -Hours 72

.EXAMPLE
    .\Get-DailyWork.ps1 -Since '2026-08-01 09:00' -MaxPrompts 10
#>
[CmdletBinding()]
param(
    [int]$Hours,
    [datetime]$Since,
    [switch]$Auto,
    [int]$MaxPrompts = 25,
    [int]$MaxFiles = 20,
    [int]$MaxDids = 25,
    [switch]$Json,
    [string]$ProjectsRoot = (Join-Path $env:USERPROFILE '.claude\projects')
)

$now = Get-Date

# --- Resolve the window ------------------------------------------------------
if ($PSBoundParameters.ContainsKey('Since'))
{
    $cutoff = $Since
    $windowLabel = 'explicit'
}
elseif ($PSBoundParameters.ContainsKey('Hours') -and -not $Auto)
{
    $cutoff = $now.AddHours(-$Hours)
    $windowLabel = "${Hours}h"
}
else
{
    # Weekend / Monday runs reach back to Friday 00:00 so nothing falls in the gap.
    switch ($now.DayOfWeek)
    {
        'Monday'   { $back = 3 }
        'Sunday'   { $back = 2 }
        'Saturday' { $back = 1 }
        default    { $back = $null }
    }

    if ($null -ne $back)
    {
        $cutoff = $now.Date.AddDays(-$back)
        $windowLabel = "since Friday 00:00 ($($now.DayOfWeek) run)"
    }
    else
    {
        $cutoff = $now.AddHours(-24)
        $windowLabel = '24h'
    }
}

if (-not (Test-Path $ProjectsRoot))
{
    Write-Warning "No projects directory at $ProjectsRoot - nothing to report."
    return
}

# --- Helpers -----------------------------------------------------------------

# Lines that are machinery, not something the user actually typed.
$noiseHeads = @(
    '<command-name', '<command-message', '<command-args', '<local-command',
    '<system-reminder', '<user-prompt-submit-hook', '<bash-input', '<bash-stdout',
    '<post-tool-use-hook', '<session-start-hook', 'Base directory for this skill:',
    'Caveat: The messages below were generated', 'This session is being continued from'
)

function Test-IsNoisePrompt
{
    param([string]$Text)

    foreach ($head in $noiseHeads)
    {
        if ($Text.StartsWith($head, [StringComparison]::OrdinalIgnoreCase))
        {
            return $true
        }
    }
    return $false
}

function Get-Truncated
{
    param([string]$Text, [int]$Length)

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $clean = ($Text -replace '\s+', ' ').Trim()
    if ($clean.Length -le $Length) { return $clean }
    return $clean.Substring(0, $Length - 3) + '...'
}

function ConvertTo-LocalTime
{
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime])
    {
        if ($Value.Kind -eq [DateTimeKind]::Utc) { return $Value.ToLocalTime() }
        return $Value
    }
    $parsed = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse([string]$Value, [ref]$parsed))
    {
        return $parsed.LocalDateTime
    }
    return $null
}

# --- Digest one transcript ---------------------------------------------------
function Read-SessionDigest
{
    param([System.IO.FileInfo]$File, [datetime]$Cutoff)

    $cwd = $null; $branch = $null
    $firstEver = $null; $firstIn = $null; $lastIn = $null
    $prompts = [System.Collections.Generic.List[object]]::new()
    $dids = [System.Collections.Generic.List[string]]::new()
    $commands = [System.Collections.Generic.List[string]]::new()
    $files = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $prs = [System.Collections.Generic.HashSet[string]]::new()
    $items = [System.Collections.Generic.HashSet[string]]::new()
    $promptTotal = 0
    $assistantTurns = 0
    $ts = $null

    $reader = [System.IO.StreamReader]::new($File.FullName)
    try
    {
        while ($null -ne ($line = $reader.ReadLine()))
        {
            # Cheap timestamp scrape first - drives all window filtering below.
            if ($line -match '"timestamp":"([^"]+)"')
            {
                $parsed = ConvertTo-LocalTime $Matches[1]
                if ($parsed)
                {
                    $ts = $parsed
                    if ((-not $firstEver) -or ($ts -lt $firstEver)) { $firstEver = $ts }
                }
            }

            # Launch dir / branch come from the head of the file, window or not.
            if ((-not $cwd) -and $line -match '"cwd":"([^"]+)"')
            {
                $cwd = $Matches[1] -replace '\\\\', '\'
                if ($line -match '"gitBranch":"([^"]*)"') { $branch = $Matches[1] }
            }

            $inWindow = ($null -ne $ts) -and ($ts -ge $Cutoff)
            if (-not $inWindow) { continue }

            if ((-not $firstIn) -or ($ts -lt $firstIn)) { $firstIn = $ts }
            if ((-not $lastIn) -or ($ts -gt $lastIn)) { $lastIn = $ts }

            # PR / work item references, wherever they appear.
            foreach ($m in [regex]::Matches($line, 'pullrequest/(\d+)'))
            {
                [void]$prs.Add($m.Groups[1].Value)
            }
            foreach ($m in [regex]::Matches($line, '_workitems/edit/(\d+)'))
            {
                [void]$items.Add($m.Groups[1].Value)
            }

            # Files written or edited - regex only, these lines are huge.
            if ($line -match '"name":"(Edit|Write|NotebookEdit|MultiEdit)"')
            {
                foreach ($m in [regex]::Matches($line, '"(?:file_path|notebook_path)":"((?:[^"\\]|\\.)*)"'))
                {
                    $path = $m.Groups[1].Value -replace '\\\\', '\'
                    [void]$files.Add($path)
                }
            }

            # Slash commands invoked.
            foreach ($m in [regex]::Matches($line, '<command-name>/?([A-Za-z0-9_:-]+)</command-name>'))
            {
                $commands.Add('/' + $m.Groups[1].Value)
            }

            if ($line -match '"type":"assistant"')
            {
                $assistantTurns++

                # The mandated end-of-turn footer: the best one-line work summary.
                # The leading newline is required - it anchors on the real footer
                # instead of prose or file content that merely mentions "**Did:**".
                if ($line -match '(?:\\n|\\r)\*\*Did:\*\*\s*(.*?)(\\n|\\r|")')
                {
                    $did = $Matches[1] -replace '\\"', '"' -replace '\\\\', '\'
                    $did = Get-Truncated $did 220
                    if ($did -and -not $dids.Contains($did)) { $dids.Add($did) }
                }
                continue
            }

            if ($line -notmatch '"type":"user"') { continue }
            if ($line -match '"tool_result"') { continue }          # tool output, not a prompt
            if ($line -match '"isMeta":true') { continue }          # injected context
            if ($line -match '"isCompactSummary":true') { continue }

            $obj = $null
            try { $obj = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
            if ($obj.type -ne 'user' -or -not $obj.message) { continue }

            $content = $obj.message.content
            $text = if ($content -is [string])
                    {
                        $content
                    }
                    else
                    {
                        ($content | Where-Object { $_.type -eq 'text' } |
                            ForEach-Object { $_.text }) -join ' '
                    }

            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $text = ($text -replace '\s+', ' ').Trim()
            if (Test-IsNoisePrompt $text) { continue }

            $promptTotal++
            if ($prompts.Count -lt $MaxPrompts)
            {
                $prompts.Add([pscustomobject]@{
                    Time = $ts
                    Text = Get-Truncated $text 300
                })
            }
        }
    }
    finally
    {
        $reader.Dispose()
    }

    if (-not $lastIn) { return $null }   # touched in window but nothing real happened

    return [pscustomobject]@{
        SessionId      = $File.BaseName
        ShortId        = $File.BaseName.Substring(0, 8)
        LaunchDir      = $cwd
        Branch         = $branch
        WorkItem       = if ($branch -match '(\d{4,6})') { $Matches[1] }
                         elseif ($cwd -match '\\(\d{4,6})_') { $Matches[1] }
                         else { $null }
        StartedAt      = $firstEver
        WasResumed     = ($firstEver -and ($firstEver -lt $Cutoff))
        FirstInWindow  = $firstIn
        LastInWindow   = $lastIn
        PromptCount    = $promptTotal
        AssistantTurns = $assistantTurns
        Prompts        = $prompts
        Dids           = $dids | Select-Object -First $MaxDids
        DidTotal       = $dids.Count
        Commands       = ($commands | Group-Object | Sort-Object Count -Descending |
                            ForEach-Object { if ($_.Count -gt 1) { "$($_.Name) x$($_.Count)" } else { $_.Name } })
        Files          = $files
        PullRequests   = ($prs | Sort-Object)
        WorkItems      = ($items | Sort-Object)
    }
}

# --- Collect -----------------------------------------------------------------
$candidates = Get-ChildItem $ProjectsRoot -Recurse -File -Filter '*.jsonl' |
    Where-Object {
        $_.Name -notlike 'agent-*' -and
        $_.Length -gt 0 -and
        $_.BaseName -match '^[0-9a-fA-F-]{36}$' -and
        $_.LastWriteTime -ge $cutoff
    }

$digests = foreach ($file in $candidates)
{
    Write-Verbose "Reading $($file.Name) ($([math]::Round($file.Length/1MB,1)) MB)"
    Read-SessionDigest -File $file -Cutoff $cutoff
}

$digests = $digests | Where-Object { $_ } | Sort-Object LastInWindow -Descending

if ($Json)
{
    [pscustomobject]@{
        WindowStart = $cutoff.ToString('yyyy-MM-dd HH:mm')
        WindowEnd   = $now.ToString('yyyy-MM-dd HH:mm')
        WindowLabel = $windowLabel
        Sessions    = @($digests | ForEach-Object {
            $_ | Select-Object * -ExcludeProperty Files |
                Add-Member -NotePropertyName Files -NotePropertyValue @($_.Files) -PassThru
        })
    } | ConvertTo-Json -Depth 6
    return
}

# --- Render text digest ------------------------------------------------------
$out = [System.Text.StringBuilder]::new()
[void]$out.AppendLine('=== DAILY WORK DIGEST ===')
[void]$out.AppendLine("Window: $($cutoff.ToString('yyyy-MM-dd HH:mm')) -> $($now.ToString('yyyy-MM-dd HH:mm'))  (local, $windowLabel)")
[void]$out.AppendLine("Sessions with activity in window: $(@($digests).Count)  (transcripts scanned: $(@($candidates).Count))")

if (-not @($digests).Count)
{
    [void]$out.AppendLine('')
    [void]$out.AppendLine('No session activity in this window.')
    $out.ToString()
    return
}

$i = 0
foreach ($d in $digests)
{
    $i++
    $span = '{0} -> {1}' -f $d.FirstInWindow.ToString('MM-dd HH:mm'), $d.LastInWindow.ToString('MM-dd HH:mm')
    $wi = if ($d.WorkItem) { "  WI $($d.WorkItem)" } else { '' }

    [void]$out.AppendLine('')
    [void]$out.AppendLine("--- [$i] $($d.ShortId)  $($d.LaunchDir)$wi")
    [void]$out.AppendLine("    Branch : $($d.Branch)")
    $resumed = if ($d.WasResumed) { "  (resumed; session began $($d.StartedAt.ToString('yyyy-MM-dd')))" } else { '  (started in window)' }
    [void]$out.AppendLine("    Active : $span$resumed")
    [void]$out.AppendLine("    Volume : $($d.PromptCount) prompts, $($d.AssistantTurns) assistant turns")

    if (@($d.Commands).Count)
    {
        [void]$out.AppendLine("    Commands: $(($d.Commands) -join ', ')")
    }

    if (@($d.Dids).Count)
    {
        $more = if ($d.DidTotal -gt @($d.Dids).Count) { " (showing $(@($d.Dids).Count) of $($d.DidTotal))" } else { '' }
        [void]$out.AppendLine("    Did${more}:")
        foreach ($did in $d.Dids) { [void]$out.AppendLine("      * $did") }
    }

    if (@($d.Prompts).Count)
    {
        $more = if ($d.PromptCount -gt @($d.Prompts).Count) { " (showing $(@($d.Prompts).Count) of $($d.PromptCount))" } else { '' }
        [void]$out.AppendLine("    Asks${more}:")
        foreach ($p in $d.Prompts)
        {
            [void]$out.AppendLine("      > [$($p.Time.ToString('MM-dd HH:mm'))] $($p.Text)")
        }
    }

    $fileList = @($d.Files)
    if ($fileList.Count)
    {
        $names = $fileList | ForEach-Object { Split-Path $_ -Leaf } | Select-Object -Unique
        $shown = $names | Select-Object -First $MaxFiles
        $more = if ($names.Count -gt $shown.Count) { " (+$($names.Count - $shown.Count) more)" } else { '' }
        [void]$out.AppendLine("    Files written/edited ($($fileList.Count)): $(($shown) -join ', ')$more")
    }

    if (@($d.PullRequests).Count)
    {
        [void]$out.AppendLine("    PRs referenced : $(($d.PullRequests) -join ', ')")
    }
    if (@($d.WorkItems).Count)
    {
        [void]$out.AppendLine("    WIs referenced : $(($d.WorkItems) -join ', ')")
    }
}

$out.ToString()

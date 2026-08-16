<#
.SYNOPSIS
    Flags things that should not be in a public copy of this repo.

.DESCRIPTION
    Pattern-based (so the script itself contains no real identifiers):
      * GUID-looking strings (repo / project ids)
      * "Bearer <literal>" tokens that are not $VARS or placeholders
      * https:// hosts outside a small allowlist
      * user-profile paths (C:\Users\<name>\..., /c/Users/<name>/...)
    Exit code 1 if anything is flagged.

.EXAMPLE
    pwsh scripts/lint-placeholders.ps1
#>
[CmdletBinding()]
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$allowedHosts = @(
    'example.com', 'devops.example.com', 'mattermost.example.com',
    'sql-staging.example.com', 'sql-dev.example.com', 'sql-prod.example.com', 'sql-prod-mirror.example.com',
    'learn.microsoft.com', 'docs.anthropic.com', 'docs.github.com', 'github.com',
    'api.datadoghq.eu', 'api.datadoghq.com', 'localhost'
)

$checks = @(
    @{ Name = 'GUID';        Regex = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' }
    @{ Name = 'BearerToken'; Regex = 'Bearer\s+(?![\$<(\{])[A-Za-z0-9_\-]{8,}' }
    @{ Name = 'UserPath';    Regex = '(?i)(?:[a-z]:\\|/[a-z]/)Users[\\/](?!<)[^\\/\s"''`]+[\\/]' }
)

$hits = [System.Collections.Generic.List[string]]::new()
$files = Get-ChildItem $Root -Recurse -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Extension -in '.md', '.ps1', '.py', '.json', '.txt', '.yml', '.yaml' }

foreach ($file in $files)
{
    $rel = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
    $lineNo = 0
    foreach ($line in [System.IO.File]::ReadLines($file.FullName))
    {
        $lineNo++
        foreach ($c in $checks)
        {
            if ($line -match $c.Regex) { $hits.Add("$rel`:$lineNo [$($c.Name)] $($line.Trim())") }
        }
        foreach ($m in [regex]::Matches($line, 'https?://([^/\s"''`)\]>]+)'))
        {
            $h = $m.Groups[1].Value.ToLowerInvariant() -replace ':\d+$', ''
            if ($h -notin $allowedHosts -and -not $h.EndsWith('.example.com'))
            {
                $hits.Add("$rel`:$lineNo [Host:$h] $($line.Trim())")
            }
        }
    }
}

if ($hits.Count)
{
    $hits | ForEach-Object { Write-Output $_ }
    Write-Output ""
    Write-Output "$($hits.Count) finding(s). Review before publishing."
    exit 1
}
Write-Output "No findings."
exit 0

# SessionStart hook script for Claude Code
# Loads centralized context based on current working directory from a local HTTP
# service (a small MCP/REST server that returns team-wide context for a path).
# Swap the URI below for whatever serves your context; the hook shape stays the same.
#
# This script is called by Claude Code when a session starts.
# It receives JSON input: { "session_id": "...", "cwd": "C:\path\to\dir" }
# Output (stdout) is injected into the conversation context.

param(
    [Parameter(Mandatory=$false)]
    [string]$InputJson
)

# Debug log file
$debugLog = "$env:USERPROFILE\.claude\hooks\load-context-debug.log"

function Write-DebugLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Add-Content -Path $debugLog
}

Write-DebugLog "=== Script started ==="
Write-DebugLog "InputJson param: '$InputJson'"

try {
    if ([string]::IsNullOrWhiteSpace($InputJson)) {
        Write-DebugLog "No input received, exiting"
        exit 0
    }

    $data = $InputJson | ConvertFrom-Json
    $cwd = $data.cwd
    Write-DebugLog "Parsed cwd: '$cwd'"

    if ([string]::IsNullOrWhiteSpace($cwd)) {
        Write-DebugLog "cwd is empty, exiting"
        exit 0
    }

    # Call the local context service (any HTTP endpoint that maps a path to context text)
    $encodedPath = [System.Uri]::EscapeDataString($cwd)
    $uri = "http://localhost:5299/context?path=$encodedPath"
    Write-DebugLog "Calling URI: $uri"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 5
        Write-DebugLog "Response received, context length: $($response.context.Length)"

        if ($response.context -and $response.context.Trim().Length -gt 0) {
            # Output the context - this will be injected into Claude's context
            Write-Output ""
            Write-Output "# Centralized Context"
            Write-Output ""
            Write-Output $response.context

            # Add a note about what sources were matched
            if ($response.matchedSources -and $response.matchedSources.Count -gt 0) {
                Write-Output ""
                Write-Output "---"
                Write-Output "_Context loaded from: $($response.matchedSources.Name -join ', ')_"
            }
            Write-DebugLog "Context output successfully"
        } else {
            Write-DebugLog "Response context was empty"
        }
    }
    catch {
        Write-DebugLog "REST call failed: $_"
        exit 0
    }
}
catch {
    Write-DebugLog "Error in main try block: $_"
    exit 0
}

Write-DebugLog "=== Script completed ==="

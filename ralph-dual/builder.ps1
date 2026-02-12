# Builder Loop - Implement Linear tasks
# Usage: .\ralph-dual\builder.ps1 [-Sleep 5] [-Max 0] [-Project "name"]

param(
    [int]$Sleep = 5,
    [int]$Max = 0,
    [int]$MaxIdle = 10,
    [string]$Project = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GuidanceFile = Join-Path $ScriptDir "epic-guidance.json"
$BuilderPrompt = Join-Path $ScriptDir "builder.md"
$ProgressFile = Join-Path $ScriptDir "progress.txt"

# Check files
if (-not (Test-Path $BuilderPrompt)) {
    Write-Host "Error: builder.md not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $GuidanceFile)) {
    Write-Host "Error: epic-guidance.json not found" -ForegroundColor Red
    Write-Host "Run Watcher first or create from template:"
    Write-Host "  cp ralph-dual/epic-guidance.json.example ralph-dual/epic-guidance.json"
    exit 1
}

# Initialize progress file
if (-not (Test-Path $ProgressFile)) {
    @"
## Codebase Patterns

<!-- Curated patterns - max 20 entries -->
<!-- Builder adds genuinely reusable patterns here -->
<!-- Watcher curates during maintenance phase -->

---

## Recent Sessions

<!-- Keep only last 10 sessions -->
<!-- Older sessions get deleted to save context -->

"@ | Set-Content $ProgressFile
}

Write-Host "========================================"
Write-Host "  Builder Loop"
Write-Host "========================================"
Write-Host "  Sleep: ${Sleep}s"
Write-Host "  Max: $(if ($Max -eq 0) { 'infinite' } else { $Max }) iterations"
if ($Project) {
    Write-Host "  Project: $Project"
}
Write-Host "========================================"
Write-Host ""

$iteration = 0
$idleCount = 0

while ($true) {
    $iteration++

    if ($Max -gt 0 -and $iteration -gt $Max) {
        Write-Host "Max iterations reached. Exiting."
        exit 0
    }

    Write-Host ""
    Write-Host "=== Builder Session $iteration - $(Get-Date) ===" -ForegroundColor Cyan

    # Prepare prompt with directory-aware path substitution
    $PromptContent = Get-Content $BuilderPrompt -Raw
    $RalphDir = [System.IO.Path]::GetRelativePath((Get-Location).Path, $ScriptDir) -replace '\\', '/'
    if (-not $RalphDir -or $RalphDir -eq '.') { $RalphDir = Split-Path -Leaf $ScriptDir }
    $PromptContent = $PromptContent.Replace('{RALPH_DIR}', $RalphDir)
    if ($Project) {
        $PromptContent = "**PROJECT**: Use Linear project '$Project'`n`n$PromptContent"
    }

    # Run Claude Code
    $Output = ""
    try {
        $Output = $PromptContent | claude --dangerously-skip-permissions --print 2>&1 | Tee-Object -Variable Output
        Write-Host $Output
    } catch {
        Write-Host "Claude execution failed: $_" -ForegroundColor Red
    }

    # Check for no tasks
    if ($Output -match "NO_TASKS") {
        $idleCount++
        Write-Host ""
        Write-Host "No tasks. Idle: $idleCount/$MaxIdle" -ForegroundColor Yellow

        if ($idleCount -ge $MaxIdle) {
            Write-Host "Max idle reached. Exiting." -ForegroundColor Yellow
            Write-Host "Watcher may not be running or queue is empty."
            exit 0
        }

        # Longer sleep when idle
        $idleSleep = $Sleep * 3
        Write-Host "Sleeping ${idleSleep}s..."
        Start-Sleep -Seconds $idleSleep
        continue
    }

    # Reset idle on activity
    $idleCount = 0

    # Check for blocked
    if ($Output -match "BLOCKED") {
        Write-Host ""
        Write-Host "Task blocked. See output above." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Sleeping ${Sleep}s..."
    Start-Sleep -Seconds $Sleep
}

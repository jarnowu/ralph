# Watcher Loop - Test app and create Linear tasks for REAL issues
# Usage: .\watcher.ps1 [-Sleep 30] [-Max 0] [-Project "name"]

param(
    [int]$Sleep = 30,
    [int]$MaintenanceSleep = 300,
    [int]$Max = 0,
    [string]$Project = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GuidanceFile = Join-Path $ScriptDir "epic-guidance.json"
$StateFile = Join-Path $ScriptDir "watcher-state.json"
$WatcherPrompt = Join-Path $ScriptDir "watcher.md"

# Check files
if (-not (Test-Path $WatcherPrompt)) {
    Write-Host "Error: watcher.md not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $GuidanceFile)) {
    $ExampleFile = Join-Path $ScriptDir "epic-guidance.json.example"
    if (Test-Path $ExampleFile) {
        Copy-Item $ExampleFile $GuidanceFile
        Write-Host "Created epic-guidance.json - please configure Linear settings" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Error: epic-guidance.json not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $StateFile)) {
    $ExampleFile = Join-Path $ScriptDir "watcher-state.json.example"
    if (Test-Path $ExampleFile) {
        Copy-Item $ExampleFile $StateFile
        Write-Host "Created watcher-state.json in discovery phase" -ForegroundColor Green
    } else {
        Write-Host "Error: watcher-state.json.example not found" -ForegroundColor Red
        exit 1
    }
}

Write-Host "========================================"
Write-Host "  Watcher Loop - Quality Guardian"
Write-Host "========================================"
Write-Host "  Sleep: ${Sleep}s (${MaintenanceSleep}s in maintenance)"
Write-Host "  Max: $(if ($Max -eq 0) { 'infinite' } else { $Max }) iterations"
if ($Project) {
    Write-Host "  Project: $Project"
}
Write-Host "========================================"
Write-Host ""

$iteration = 0

while ($true) {
    $iteration++

    if ($Max -gt 0 -and $iteration -gt $Max) {
        Write-Host "Max iterations reached. Exiting."
        exit 0
    }

    # Check current phase
    $CurrentPhase = "unknown"
    try {
        $state = Get-Content $StateFile | ConvertFrom-Json
        $CurrentPhase = $state.phase
    } catch {}

    Write-Host ""
    Write-Host "=== Session $iteration [$CurrentPhase] - $(Get-Date) ===" -ForegroundColor Cyan

    # Prepare prompt with directory-aware path substitution
    $PromptContent = Get-Content $WatcherPrompt -Raw
    $RalphDir = [System.IO.Path]::GetRelativePath((Get-Location).Path, $ScriptDir) -replace '\\', '/'
    if (-not $RalphDir -or $RalphDir -eq '.') { $RalphDir = Split-Path -Leaf $ScriptDir }
    $PromptContent = $PromptContent.Replace('{RALPH_DIR}', $RalphDir)
    if ($Project) {
        $PromptContent = "**PROJECT**: Use Linear project '$Project'`n`n$PromptContent"
    }

    # Run Claude Code
    try {
        $Output = $PromptContent | claude --dangerously-skip-permissions --print 2>&1 | Tee-Object -Variable Output
        Write-Host $Output
    } catch {
        Write-Host "Claude execution failed: $_" -ForegroundColor Red
    }

    # Check phase for sleep duration
    $NewPhase = "testing"
    try {
        $state = Get-Content $StateFile | ConvertFrom-Json
        $NewPhase = $state.phase
    } catch {}

    if ($NewPhase -eq "maintenance") {
        Write-Host ""
        Write-Host "App is in good shape. Sleeping ${MaintenanceSleep}s..." -ForegroundColor Green
        Start-Sleep -Seconds $MaintenanceSleep
    } else {
        Write-Host ""
        Write-Host "Sleeping ${Sleep}s..."
        Start-Sleep -Seconds $Sleep
    }
}

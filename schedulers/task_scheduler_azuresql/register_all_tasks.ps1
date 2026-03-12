# Register All NatGas Scheduled Tasks
# This script registers the delta, hourly, and metadata task schedulers
# Run this script as Administrator to register the scheduled tasks

$scriptDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "wm_natgasdatafeed_import"
$taskScripts = @(".ts.delta.ps1", ".ts.hourly.ps1", ".ts.metadata.ps1")

Write-Host "Registering $($taskScripts.Count) NatGas task scripts:" -ForegroundColor Cyan
Write-Host ""

$successful = 0
$failed = 0

foreach ($scriptName in $taskScripts) {
    $scriptPath = Join-Path $scriptDir $scriptName
    Write-Host "Registering: $scriptName" -ForegroundColor Yellow

    try {
        & $scriptPath
        Write-Host "  Success" -ForegroundColor Green
        $successful++
    }
    catch {
        Write-Host "  Failed: $_" -ForegroundColor Red
        $failed++
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Registration Complete" -ForegroundColor Cyan
Write-Host "  Successful: $successful" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan

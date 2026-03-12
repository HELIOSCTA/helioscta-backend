$tasks = Get-ScheduledTask -TaskPath "\helioscta-backend\NatGas\*" | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo
    $resultCode = $info.LastTaskResult
    $status = switch ($resultCode) {
        0          { "OK" }
        267011     { "NEVER RAN" }
        267009     { "RUNNING" }
        267014     { "DISABLED" }
        1          { "FAILED (1)" }
        2          { "FAILED (2)" }
        2147750687 { "ALREADY RUNNING" }
        2147942401 { "BAD FUNCTION" }
        2147946720 { "TERMINATED" }
        default    { "FAILED (0x$("{0:X}" -f $resultCode))" }
    }

    [PSCustomObject]@{
        TaskName    = $_.TaskName
        State       = $_.State
        LastRun     = if ($info.LastRunTime.Year -eq 1999) { "Never" } else { $info.LastRunTime.ToString("MM/dd HH:mm") }
        NextRun     = if ($info.NextRunTime.Year -eq 1999) { "N/A" } else { $info.NextRunTime.ToString("MM/dd HH:mm") }
        Status      = $status
        ResultCode  = $resultCode
        MissedRuns  = $info.NumberOfMissedRuns
    }
}

# --- Summary ---
$total    = $tasks.Count
$ok       = ($tasks | Where-Object Status -eq "OK").Count
$running  = ($tasks | Where-Object Status -eq "RUNNING").Count
$neverRan = ($tasks | Where-Object Status -eq "NEVER RAN").Count
$failed   = ($tasks | Where-Object { $_.Status -like "FAILED*" }).Count
$other    = $total - $ok - $running - $neverRan - $failed

Write-Host ""
Write-Host "===============================" -ForegroundColor Cyan
Write-Host "  NatGas Task Status Report" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total: $total  |  " -NoNewline
Write-Host "OK: $ok" -ForegroundColor Green -NoNewline
Write-Host "  |  " -NoNewline
Write-Host "Running: $running" -ForegroundColor Yellow -NoNewline
Write-Host "  |  " -NoNewline
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" }) -NoNewline
Write-Host "  |  " -NoNewline
Write-Host "Never Ran: $neverRan" -ForegroundColor DarkGray
Write-Host ""

# --- Detail table ---
$tasks | Sort-Object TaskName |
    Format-Table TaskName, State, LastRun, NextRun, Status, MissedRuns -AutoSize

# --- Show failures separately if any ---
$failedTasks = $tasks | Where-Object { $_.Status -like "FAILED*" }
if ($failedTasks.Count -gt 0) {
    Write-Host "FAILED TASKS:" -ForegroundColor Red
    Write-Host "-------------" -ForegroundColor Red
    $failedTasks | Sort-Object LastRun -Descending |
        Format-Table TaskName, LastRun, Status, ResultCode -AutoSize
    Write-Host "Tip: Non-zero result codes mean the PowerShell import script exited with an error." -ForegroundColor DarkGray
    Write-Host "     Check administration.error_log and natgas.load_status in GenscapeDataFeed for details." -ForegroundColor DarkGray
    Write-Host ""
}

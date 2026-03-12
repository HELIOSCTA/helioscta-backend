# Unregister All NatGas Scheduled Tasks
# This script removes all scheduled tasks under \helioscta-backend\NatGas\
# Run this script as Administrator to unregister the scheduled tasks

$taskPath = "\helioscta-backend\NatGas\"
$allTasks = Get-ScheduledTask -TaskPath "$taskPath*" -ErrorAction SilentlyContinue

if ($null -eq $allTasks -or $allTasks.Count -eq 0) {
    Write-Host "No scheduled tasks found under $taskPath" -ForegroundColor Yellow
    exit
}

Write-Host "Found $($allTasks.Count) scheduled tasks to unregister:" -ForegroundColor Cyan
Write-Host ""

foreach ($task in $allTasks) {
    Write-Host "  $($task.TaskPath)$($task.TaskName)" -ForegroundColor Yellow
}

Write-Host ""
$confirm = Read-Host "Are you sure you want to unregister all NatGas tasks? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""

$successful = 0
$failed = 0

foreach ($task in $allTasks) {
    $fullPath = "$($task.TaskPath)$($task.TaskName)"
    Write-Host "Unregistering: $fullPath" -ForegroundColor Yellow

    try {
        Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false
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
Write-Host "Unregistration Complete" -ForegroundColor Cyan
Write-Host "  Successful: $successful" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan

# Remove empty NatGas folder from Task Scheduler
Write-Host ""
Write-Host "Cleaning up empty task folders..." -ForegroundColor Cyan

$scheduleService = New-Object -ComObject "Schedule.Service"
$scheduleService.Connect()

try {
    $natgasFolder = $scheduleService.GetFolder("\helioscta-backend\NatGas")
    if ($natgasFolder.GetTasks(0).Count -eq 0 -and $natgasFolder.GetFolders(0).Count -eq 0) {
        $parentFolder = $scheduleService.GetFolder("\helioscta-backend")
        $parentFolder.DeleteFolder("NatGas", 0)
        Write-Host "  Removed empty folder: \helioscta-backend\NatGas" -ForegroundColor Green
    }
}
catch {
    Write-Host "  No folders to clean up or already removed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Cleanup complete." -ForegroundColor Cyan

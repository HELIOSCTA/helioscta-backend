$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$PythonScript1 = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\postions_and_trades\tasks\email_sftp_files\send_marex_allocated_trades_to_nav_v1_2026_feb_02.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$PythonScript1`" `""

# Define the days and times
$days = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
$times = @('19:00')

$triggers = @()
foreach ($day in $days) {
    foreach ($time in $times) {
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $day -At $time
        $triggers += $trigger
    }
}
    
# Create a separate task for each day
Register-ScheduledTask `
    -TaskName "Send Marex Allocated Trades to NAV" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\Positions and Trades\Send Trade Files\Marex Allocated Trades\" `
    -Force
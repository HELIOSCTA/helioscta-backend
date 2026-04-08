$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$PythonScript1 = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\postions_and_trades\tasks\pull_from_sftp\trades\marex\helios_allocated_trades_v2_2026_feb_23.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$PythonScript1`" `""

# Define the days and times
$days = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
$times = @('17:00', '17:30', '18:00', '18:30')

$triggers = @()
foreach ($day in $days) {
    foreach ($time in $times) {
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $day -At $time
        $triggers += $trigger
    }
}

# Create a separate task for each day
Register-ScheduledTask `
    -TaskName "SFTP Marex Allocated Trades v2" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\Positions and Trades\Trade Files SFTP\Marex Allocated Trades\" `
    -Force

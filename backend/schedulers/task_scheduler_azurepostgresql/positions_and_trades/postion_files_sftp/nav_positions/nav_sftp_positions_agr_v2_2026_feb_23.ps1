$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$PythonScript1 = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\postions_and_trades\tasks\pull_from_sftp\positions\nav\nav_sftp_positions_agr_v2_2026_feb_23.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$PythonScript1`" `""

# Define the days and times
$days = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
$times = @('4:30', '5:00', '5:15', '5:30', '5:45', '6:00', '7:00', '8:00')

$triggers = @()
foreach ($day in $days) {
    foreach ($time in $times) {
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $day -At $time
        $triggers += $trigger
    }
}

# Create a separate task for each day
Register-ScheduledTask `
    -TaskName "AGR SFTP NAV Positions v2" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\Positions and Trades\Position Files SFTP\NAV Positions\" `
    -Force

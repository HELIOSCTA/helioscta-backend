$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\eia\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all`""

# Run daily at the required trigger times.
$triggerTimes = @(
    "6:00AM",
    "6:05AM",
    "6:10AM",
    "6:15AM",
    "6:30AM",
    "6:45AM",
    "7:00AM",
    "8:00AM",
    "12:30PM"
)

$triggers = foreach ($triggerTime in $triggerTimes) {
    New-ScheduledTaskTrigger -Daily -At $triggerTime
}

Register-ScheduledTask `
    -TaskName "EIA (All Scripts)" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\EIA\" `
    -Force

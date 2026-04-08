$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\genscape\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all`""

# Run daily at the required trigger times.
$triggerTimes = @(
    "5:00AM",
    "5:15AM",
    "5:30AM",
    "5:45AM",
    "6:00AM",
    "6:15AM",
    "6:30AM",
    "7:00AM",
    "10:00AM",
    "11:00AM",
    "12:30PM"
)

$triggers = foreach ($triggerTime in $triggerTimes) {
    New-ScheduledTaskTrigger -Daily -At $triggerTime
}

Register-ScheduledTask `
    -TaskName "Genscape (All Scripts)" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\Genscape\" `
    -Force

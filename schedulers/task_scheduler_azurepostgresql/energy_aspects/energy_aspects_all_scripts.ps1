$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\energy_aspects\timeseries\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all`""

# Run twice daily — EA data is monthly, so daily refresh is sufficient.
# Morning run catches overnight updates; evening run catches same-day updates.
$triggerTimes = @(
    "6:00AM",
    "6:00PM"
)

$triggers = foreach ($triggerTime in $triggerTimes) {
    New-ScheduledTaskTrigger -Daily -At $triggerTime
}

Register-ScheduledTask `
    -TaskName "Energy Aspects (All Scripts)" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\Energy Aspects\" `
    -Force

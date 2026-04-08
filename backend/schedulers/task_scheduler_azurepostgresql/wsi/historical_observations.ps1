$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\wsi\historical_observations\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all`""

# Run once per day (historical data updates daily)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 12)

Register-ScheduledTask `
    -TaskName "WSI Historical Observations Daily" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\WSI\" `
    -Force

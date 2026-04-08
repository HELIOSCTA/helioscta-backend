$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\wsi\weighted_forecast_city\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all`""

# Run every 6 hours (Primary forecast at 6:30am ET, plus model-run-driven updates)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 6)

Register-ScheduledTask `
    -TaskName "WSI Weighted Forecast City Every 6 Hours" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\WSI\" `
    -Force

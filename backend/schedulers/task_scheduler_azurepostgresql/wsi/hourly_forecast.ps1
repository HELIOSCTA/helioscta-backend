$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\wsi\hourly_forecast\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all`""

# Run every 6 hours (aligned with NWP model run cadence: 00Z, 06Z, 12Z, 18Z)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 6)

Register-ScheduledTask `
    -TaskName "WSI Hourly Forecast Every 6 Hours" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\WSI\" `
    -Force

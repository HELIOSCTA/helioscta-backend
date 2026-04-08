$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\power\pjm\transmission_outages.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`"`""

# Run once daily at 07:00 ET (after PJM publishes the morning file)
$trigger = New-ScheduledTaskTrigger -Daily -At "07:00"

Register-ScheduledTask `
    -TaskName "PJM Transmission Outages (eDART)" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\Power\" `
    -Force

$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\ice_python\future_contracts\future_contracts_v1_2025_dec_16.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" `""

# Run every hour, 24/7
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 1)

Register-ScheduledTask `
    -TaskName "Futures" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\ICE Python\" `
    -Force

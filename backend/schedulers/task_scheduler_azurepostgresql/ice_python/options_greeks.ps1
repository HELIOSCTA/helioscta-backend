$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\ice_python\options\options_greeks_v1_2026_mar_20.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" `""

$days = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
$trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek $days `
    -At 6:00AM

# Capture Greeks every 15 minutes during market hours (6 AM - 4 PM).
$repetition = New-ScheduledTaskTrigger `
    -Once `
    -At 6:00AM `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration (New-TimeSpan -Hours 10 -Minutes 5)
$trigger.Repetition = $repetition.Repetition

Register-ScheduledTask `
    -TaskName "Options Greeks" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\ICE Python\" `
    -Force

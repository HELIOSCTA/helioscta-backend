$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\ice_python\intraday_quotes\runs.py"
$runArgs = "all"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" $runArgs`""

$days = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
$trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek $days `
    -At 6:00AM

# Use a repetition window that includes the 4:00 PM run.
$repetition = New-ScheduledTaskTrigger `
    -Once `
    -At 6:00AM `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Hours 10 -Minutes 5)
$trigger.Repetition = $repetition.Repetition

Register-ScheduledTask `
    -TaskName "Intraday Quotes" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\ICE Python\" `
    -Force

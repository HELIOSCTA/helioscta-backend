$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$projectDir = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\gas_ebbs"
$runScript = "$projectDir\runs.py"
$monitorScript = "$projectDir\monitor.py"

# Scrape all pipelines, then run monitor alert
$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all && python `"$monitorScript`" --alert`""

# Run every hour, 24/7
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 1)

Register-ScheduledTask `
    -TaskName "Gas EBBs (NAESB Pipeline Notices)" `
    -Action $action `
    -Trigger $trigger `
    -TaskPath "\helioscta-backend\Gas EBBs\" `
    -Force

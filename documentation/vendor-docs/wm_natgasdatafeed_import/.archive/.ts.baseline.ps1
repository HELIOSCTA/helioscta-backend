$pwshPath = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

$userProfile = $env:USERPROFILE
$scriptDir = Join-Path $userProfile "Documents\github\airflow_admin\task_scheduler\genscape\wm_natgasdatafeed_import"
$scriptPath = Join-Path $scriptDir "gasdatafeed_import.ps1"

# ----------------------
# gas_quality
# ----------------------
$trigger1 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At "08:30PM"

$action1 = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -sourceType baseline -sourceName gas_quality -writeLog true -Verbose" `
    -WorkingDirectory $scriptDir

Register-ScheduledTask `
    -TaskName "wm_natgasdatafeed_import baseline - gas_quality" `
    -Action $action1 `
    -Trigger $trigger1 `
    -RunLevel Highest `
    -TaskPath "\Airflow\Genscape\" `
    -Force

# ----------------------
# gas_burn
# ----------------------
$trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At "00:30AM"

$action2 = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -sourceType baseline -sourceName gas_burn -writeLog true -Verbose" `
    -WorkingDirectory $scriptDir

Register-ScheduledTask `
    -TaskName "wm_natgasdatafeed_import baseline - gas_burn" `
    -Action $action2 `
    -Trigger $trigger2 `
    -RunLevel Highest `
    -TaskPath "\Airflow\Genscape\" `
    -Force

# ----------------------
# nominations
# ----------------------
$trigger3 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At "04:30AM"

$action3 = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -sourceType baseline -sourceName nominations -writeLog true -Verbose" `
    -WorkingDirectory $scriptDir

Register-ScheduledTask `
    -TaskName "wm_natgasdatafeed_import baseline - nominations" `
    -Action $action3 `
    -Trigger $trigger3 `
    -RunLevel Highest `
    -TaskPath "\Airflow\Genscape\" `
    -Force

# ----------------------
# no_notice
# ----------------------
$trigger4 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At "08:30PM"

$action4 = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -sourceType baseline -sourceName no_notice -writeLog true -Verbose" `
    -WorkingDirectory $scriptDir

Register-ScheduledTask `
    -TaskName "wm_natgasdatafeed_import baseline - no_notice" `
    -Action $action4 `
    -Trigger $trigger4 `
    -RunLevel Highest `
    -TaskPath "\Airflow\Genscape\" `
    -Force

# ----------------------
# all_cycles
# ----------------------
$trigger5 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "12:30AM"

$action5 = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -sourceType baseline -sourceName all_cycles -writeLog true -Verbose" `
    -WorkingDirectory $scriptDir

Register-ScheduledTask `
    -TaskName "wm_natgasdatafeed_import baseline - all_cycles" `
    -Action $action5 `
    -Trigger $trigger5 `
    -RunLevel Highest `
    -TaskPath "\Airflow\Genscape\" `
    -Force

# ----------------------
# baseline
# ----------------------
$trigger6 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "08:30PM"

$action6 = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -sourceType baseline -writeLog true -Verbose" `
    -WorkingDirectory $scriptDir

Register-ScheduledTask `
    -TaskName "wm_natgasdatafeed_import baseline" `
    -Action $action6 `
    -Trigger $trigger6 `
    -RunLevel Highest `
    -TaskPath "\Airflow\Genscape\" `
    -Force



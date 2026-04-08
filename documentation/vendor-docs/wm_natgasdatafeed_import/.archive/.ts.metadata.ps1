$pwshPath = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

$userProfile = $env:USERPROFILE
$scriptDir = Join-Path $userProfile "Documents\github\airflow_admin\task_scheduler\genscape\wm_natgasdatafeed_import"
$scriptPath = Join-Path $scriptDir "gasdatafeed_import.ps1"

$action = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -sourceType metadata -writeLog true -Verbose" `
    -WorkingDirectory $scriptDir

$triggers = @()
for ($hour = 0; $hour -le 23; $hour++) {
    $time1 = "{0:D2}:00" -f $hour
    $triggers += New-ScheduledTaskTrigger -Daily -At $time1
}

Register-ScheduledTask `
    -TaskName "wm_natgasdatafeed_import metadata" `
    -Action $action `
    -Trigger $triggers `
    -RunLevel Highest `
    -TaskPath "\Airflow\Genscape\" `
    -Force

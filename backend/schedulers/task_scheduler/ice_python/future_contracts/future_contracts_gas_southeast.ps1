# Registers the ICE future contracts (gas / southeast region) Task Scheduler job.
# Fires every 30 min from 07:00 to 11:00 MT, daily. The Python
# orchestration's trading-hours gate backstops weekend / off-hour misfires.
#
# One of eight sibling .ps1 files (six gas regions + power_pjm + power_ercot)
# that fan out the original Future Contracts job into concurrent processes so
# each gets its own ICE XL / COM apartment.
#
# Requires: Administrator. ICE XL + conda env `helioscta-backend-dev` on the host.

$condaPath   = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$condaEnv    = "helioscta-backend-dev"
$repoRoot    = (Resolve-Path "$PSScriptRoot\..\..\..\..\..").Path
$moduleName  = "backend.orchestration.ice_python.future_contracts.future_contracts_gas_southeast"

$cmdArgs = "/c `"call `"$condaPath`" $condaEnv && cd /d `"$repoRoot`" && python -m $moduleName`""

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument $cmdArgs

# Every 30 min from 07:00 for 4h (fires at 07:00, 07:30, ..., 11:00 MT).
# Trading-hours gating lives in Python.
# Repetition is copied from a throwaway -Once trigger because Windows
# PowerShell 5.1 won't let you set .Repetition.Interval directly on a -Daily.
$trigger = New-ScheduledTaskTrigger -Daily -At "07:00"
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At "07:00" `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Hours 4)).Repetition

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

Register-ScheduledTask `
    -TaskName "Future Contracts Gas Southeast" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -TaskPath "\helioscta-backend-dev\ICE Python\" `
    -Force

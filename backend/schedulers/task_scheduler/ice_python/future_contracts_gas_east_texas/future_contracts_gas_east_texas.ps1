# Registers the ICE future contracts (gas / east_texas region) Task Scheduler job.
# Fires every 30 min from 12:15 to 15:45 MT, daily. The Python
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
$moduleName  = "backend.orchestration.ice_python.future_contracts.future_contracts_gas_east_texas"

$cmdArgs = "/c `"call `"$condaPath`" $condaEnv && cd /d `"$repoRoot`" && python -m $moduleName`""

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument $cmdArgs

# Every 30 min from 12:15 for 3h30m (fires at 12:15, 12:45, ..., 15:45 MT).
# Trading-hours gating lives in Python.
# Repetition is copied from a throwaway -Once trigger because Windows
# PowerShell 5.1 won't let you set .Repetition.Interval directly on a -Daily.
$trigger = New-ScheduledTaskTrigger -Daily -At "12:15"
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At "12:15" `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Hours 3 -Minutes 30)).Repetition

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

Register-ScheduledTask `
    -TaskName "Future Contracts Gas East Texas" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -TaskPath "\helioscta-backend-dev\ICE Python\" `
    -Force

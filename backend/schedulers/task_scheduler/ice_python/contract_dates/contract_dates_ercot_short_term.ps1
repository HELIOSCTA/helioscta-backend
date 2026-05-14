# Registers the ICE contract-dates (ERCOT short-term power) Task Scheduler job.
# Fires hourly 07:00–11:00 MT (5 fires per day). The Python orchestration's
# weekday gate backstops weekend misfires. The short-term curve rolls within
# the day, so multiple morning refreshes are worth the extra fires; the
# `(trade_date, symbol)` PK makes each pull idempotent.
#
# Sibling of `contract_dates_pjm_short_term.ps1` — same cadence, different
# product registry.
#
# Requires: Administrator. ICE XL + conda env `helioscta-backend-dev` on the host.

$condaPath   = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$condaEnv    = "helioscta-backend-dev"
$repoRoot    = (Resolve-Path "$PSScriptRoot\..\..\..\..\..").Path
$moduleName  = "backend.orchestration.ice_python.contract_dates.contract_dates_ercot_short_term"

$cmdArgs = "/c `"call `"$condaPath`" $condaEnv && cd /d `"$repoRoot`" && python -m $moduleName`""

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument $cmdArgs

# Hourly from 07:00 for 4h (fires at 07:00, 08:00, ..., 11:00 MT).
# Weekday gating lives in Python.
# Repetition is copied from a throwaway -Once trigger because Windows
# PowerShell 5.1 won't let you set .Repetition.Interval directly on a -Daily.
$trigger = New-ScheduledTaskTrigger -Daily -At "07:00"
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At "07:00" `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Hours 4)).Repetition

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask `
    -TaskName "Contract Dates ERCOT Short Term" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -TaskPath "\helioscta-backend-dev\ICE Python\" `
    -Force

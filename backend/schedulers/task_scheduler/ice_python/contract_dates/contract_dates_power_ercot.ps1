# Registers the ICE contract-dates (ERCOT power futures) Task Scheduler job.
# Fires once daily at 07:00 MT (start of the 07:00–11:00 ICE Python window).
# Contract dates change rarely (calendar rolls / new months), so a single
# early-morning refresh is enough. The Python orchestration's weekday gate
# backstops weekend misfires.
#
# One of three sibling .ps1 files (gas / power_ercot / power_pjm) that
# refresh `ice_python.contract_dates` per product registry.
#
# Requires: Administrator. ICE XL + conda env `helioscta-backend-dev` on the host.

$condaPath   = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$condaEnv    = "helioscta-backend-dev"
$repoRoot    = (Resolve-Path "$PSScriptRoot\..\..\..\..\..").Path
$moduleName  = "backend.orchestration.ice_python.contract_dates.contract_dates_power_ercot"

$cmdArgs = "/c `"call `"$condaPath`" $condaEnv && cd /d `"$repoRoot`" && python -m $moduleName`""

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument $cmdArgs

# Once daily at 07:00 MT. Weekday gating lives in Python.
$trigger = New-ScheduledTaskTrigger -Daily -At "07:00"

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask `
    -TaskName "Contract Dates Power ERCOT" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -TaskPath "\helioscta-backend-dev\ICE Python\" `
    -Force

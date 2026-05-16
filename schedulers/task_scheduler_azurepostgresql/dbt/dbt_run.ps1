# dbt run (Azure PostgreSQL)
#
# Registers a single scheduled task that runs the Python dbt runner every hour.
# The Python runner handles overlap via PostgreSQL advisory locks, retry/backoff,
# and structured logging.
#
# Python entrypoint: backend\dbt\dbt_azure_postgresql\runner_dbt_azure_postgresql.py
# Task path:         \helioscta-backend\dbt\
# Task name:         dbt run (Azure PostgreSQL)
# Cadence:           every 1 hour, indefinitely
#
# To register: Run this script in an elevated PowerShell session.
# To remove:   Unregister-ScheduledTask -TaskName "dbt run (Azure PostgreSQL)" -TaskPath "\helioscta-backend\dbt\"

$repoRoot = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend"
$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "$repoRoot\backend\dbt\dbt_azure_postgresql\runner_dbt_azure_postgresql.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" --timeout 1800 --max-attempts 3 --retry-backoff-seconds 30`"" `
    -WorkingDirectory $repoRoot

# Run every 1 hour, starting one minute from registration time.
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Hours 1)

# OS-level protections:
# - Ignore overlapping instances
# - Hard execution ceiling in case the process is stuck
# - No OS-level restart — the Python runner handles retry/backoff internally
#   to avoid compounding retries (OS 3x * runner 3x = 9 attempts)
$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
    -TaskName "dbt run (Azure PostgreSQL)" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -TaskPath "\helioscta-backend\dbt\" `
    -Force

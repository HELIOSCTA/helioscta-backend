# ── dbt run (Azure PostgreSQL) ────────────────────────────────────────────────
#
# Registers a single scheduled task that runs the Python dbt runner every 10
# minutes.  The Python script handles overlap via PostgreSQL advisory locks,
# structured logging, and configurable timeout.
#
# Python entrypoint: backend\dbt\dbt_azure_postgresql\runner_dbt_azure_postgresql.py
# Task path:         \helioscta-backend\dbt\
# Task name:         dbt run (Azure PostgreSQL)
# Cadence:           every 10 minutes, indefinitely
#
# To register:  Run this script in an elevated PowerShell session.
# To remove:    Unregister-ScheduledTask -TaskName "dbt run (Azure PostgreSQL)" -TaskPath "\helioscta-backend\dbt\"
#
# NOTE: This replaces the previous 7 per-day tasks. Remove orphans first:
#   $days = @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
#   foreach ($day in $days) {
#       Unregister-ScheduledTask -TaskName "dbt run (Azure PostgreSQL) ($day)" -TaskPath "\helioscta-backend\dbt\" -Confirm:$false -ErrorAction SilentlyContinue
#   }
# ──────────────────────────────────────────────────────────────────────────────

$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\dbt\dbt_azure_postgresql\runner_dbt_azure_postgresql.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`"`""

# Run every 10 minutes, starting now, indefinitely
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 10)

# Prevent overlapping instances at the OS level (Python advisory lock is the primary guard)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName "dbt run (Azure PostgreSQL)" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -TaskPath "\helioscta-backend\dbt\" `
    -Force

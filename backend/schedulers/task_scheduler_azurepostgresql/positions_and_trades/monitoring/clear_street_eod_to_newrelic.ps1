$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$PythonScript1 = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\monitoring\postions_and_trades\clear_street_eod\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$PythonScript1`" `""

# SFTP-aligned triggers fire 5 minutes after each pull cycle
# (helios_transactions_v2_2026_feb_23.ps1 runs at 19:30/20:00/20:30/21:00/23:50 MT)
# so the ingest job sees freshly upserted rows.
#
# The standalone 22:05 trigger drives the wall-clock late check in
# events.build_eod_file_late_event(); without it, no run between 22:00 and
# 23:50 would notice that today's file is late.
$days = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
$times = @('19:35', '20:05', '20:35', '21:05', '22:05', '23:55')

$triggers = @()
foreach ($day in $days) {
    foreach ($time in $times) {
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $day -At $time
        $triggers += $trigger
    }
}

Register-ScheduledTask `
    -TaskName "Monitoring Clear Street EOD to New Relic" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\Positions and Trades\Monitoring\" `
    -Force

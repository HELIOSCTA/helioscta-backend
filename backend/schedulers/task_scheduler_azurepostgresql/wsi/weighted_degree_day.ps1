$condaPath = "$env:USERPROFILE\miniconda3\Scripts\activate.bat"
$runScript = "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\src\wsi\weighted_degree_day\runs.py"

$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"call `"$condaPath`" helioscta-backend && python `"$runScript`" all`""

# Run at :00, :15, :30, :45 during the hours 00, 06, 12, 18 (aligned with NWP model runs)
$triggers = @()
foreach ($hour in @(0, 6, 12, 18)) {
    foreach ($minute in @(0, 15, 30, 45)) {
        $triggers += New-ScheduledTaskTrigger -Daily -At ("{0:D2}:{1:D2}" -f $hour, $minute)
    }
}

Register-ScheduledTask `
    -TaskName "WSI Weighted Degree Day" `
    -Action $action `
    -Trigger $triggers `
    -TaskPath "\helioscta-backend\WSI\" `
    -Force

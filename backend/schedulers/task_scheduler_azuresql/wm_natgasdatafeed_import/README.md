<!-- POWER SHELL -->
Set-ExecutionPolicy unrestricted
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
Unblock-File -Path 'C:\Users\AidanKeaveny\Documents\github\helioscta-backend\schedulers\task_scheduler_azuresql\wm_natgasdatafeed_import\gasdatafeed_import.ps1'

<!-- CWD -->
cd C:\Users\AidanKeaveny\Documents\github\helioscta-backend\schedulers\task_scheduler_azuresql\wm_natgasdatafeed_import

<!-- BASELINE -->
./gasdatafeed_import.ps1 -sourceType metadata -writeLog true -Verbose
./gasdatafeed_import.ps1 -sourceType baseline -writeLog true -Verbose

./gasdatafeed_import.ps1 -sourceType baseline -sourceName gas_quality -writeLog true -Verbose
./gasdatafeed_import.ps1 -sourceType baseline -sourceName gas_burn -writeLog true -Verbose
./gasdatafeed_import.ps1 -sourceType baseline -sourceName nominations -writeLog true -Verbose
./gasdatafeed_import.ps1 -sourceType baseline -sourceName no_notice -writeLog true -Verbose
./gasdatafeed_import.ps1 -sourceType baseline -sourceName all_cycles -writeLog true -Verbose

<!-- HOURLY -->
./gasdatafeed_import.ps1 -sourceType metadata -writeLog true -Verbose
./gasdatafeed_import.ps1 -sourceType hourly -writeLog true -Verbose

<!-- DELTA -->
./gasdatafeed_import.ps1 -sourceType metadata -writeLog true -Verbose
./gasdatafeed_import.ps1 -sourceType delta -writeLog true -Verbose
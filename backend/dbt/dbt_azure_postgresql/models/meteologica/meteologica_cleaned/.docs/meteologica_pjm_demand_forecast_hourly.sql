select
  forecast_rank
  ,forecast_execution_datetime
  ,forecast_execution_date
  ,forecast_datetime
  ,forecast_date
  ,hour_ending
  ,date_utc
  ,hour_ending_utc
  ,region
  ,forecast_load_mw
from meteologica_cleaned.meteologica_pjm_demand_forecast_hourly

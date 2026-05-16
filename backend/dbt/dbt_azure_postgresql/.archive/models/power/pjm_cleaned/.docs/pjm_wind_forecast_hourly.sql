select
  forecast_rank
  ,forecast_execution_datetime
  ,forecast_execution_date
  ,forecast_datetime
  ,forecast_date
  ,hour_ending
  ,wind_forecast
from pjm_cleaned.pjm_wind_forecast_hourly

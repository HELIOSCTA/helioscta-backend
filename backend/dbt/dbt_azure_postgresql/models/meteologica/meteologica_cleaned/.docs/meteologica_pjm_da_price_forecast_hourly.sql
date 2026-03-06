select
  forecast_rank
  ,forecast_execution_datetime
  ,forecast_execution_date
  ,forecast_datetime
  ,forecast_date
  ,hour_ending
  ,date_utc
  ,hour_ending_utc
  ,hub
  ,forecast_da_price
from meteologica_cleaned.meteologica_pjm_da_price_forecast_hourly

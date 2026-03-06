select
  forecast_rank
  ,forecast_date
  ,region
  ,period
  ,forecast_load_mw
from pjm_cleaned.pjm_load_forecast_daily

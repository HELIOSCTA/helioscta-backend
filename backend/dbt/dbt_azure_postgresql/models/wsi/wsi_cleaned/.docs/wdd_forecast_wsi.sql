select
  rank_forecast_execution_timestamps
  ,labelled_forecast_execution_timestamp
  ,forecast_execution_datetime
  ,forecast_execution_date
  ,forecast_date
  ,count_forecast_days
  ,max_forecast_days
  ,model
  ,bias_corrected
  ,region
  ,electric_cdd
  ,electric_hdd
  ,gas_cdd
  ,gas_hdd
  ,pw_cdd
  ,pw_hdd
from wsi_cleaned.wdd_forecast_wsi

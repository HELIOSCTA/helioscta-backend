"""
Prefect flow definitions for Energy Aspects timeseries scripts.

Each flow wraps the corresponding script's main() function.
Entrypoints in prefect.yaml point here instead of the scripts directly.
"""

import importlib.util
import sys
from pathlib import Path

from prefect import flow

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


def _load_main(script_name: str):
    """Load main() from an Energy Aspects script by filename."""
    spec = importlib.util.spec_from_file_location(
        script_name,
        SCRIPT_DIR / f"{script_name}.py",
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.main


@flow(name="iso_dispatch_costs", retries=2, retry_delay_seconds=60, log_prints=True)
def iso_dispatch_costs(**kwargs):
    return _load_main("iso_dispatch_costs")(**kwargs)


@flow(name="lower_48_average_power_demand_mw", retries=2, retry_delay_seconds=60, log_prints=True)
def lower_48_average_power_demand_mw(**kwargs):
    return _load_main("lower_48_average_power_demand_mw")(**kwargs)


@flow(name="lower_48_gas_generation_forecast_mw", retries=2, retry_delay_seconds=60, log_prints=True)
def lower_48_gas_generation_forecast_mw(**kwargs):
    return _load_main("lower_48_gas_generation_forecast_mw")(**kwargs)


@flow(name="lower_48_generation_forecast_mw", retries=2, retry_delay_seconds=60, log_prints=True)
def lower_48_generation_forecast_mw(**kwargs):
    return _load_main("lower_48_generation_forecast_mw")(**kwargs)


@flow(name="lower_48_installed_capacity_mw", retries=2, retry_delay_seconds=60, log_prints=True)
def lower_48_installed_capacity_mw(**kwargs):
    return _load_main("lower_48_installed_capacity_mw")(**kwargs)


@flow(name="monthly_iso_load_model", retries=2, retry_delay_seconds=60, log_prints=True)
def monthly_iso_load_model(**kwargs):
    return _load_main("monthly_iso_load_model")(**kwargs)


@flow(name="na_power_price_heat_rate_spark_forecasts", retries=2, retry_delay_seconds=60, log_prints=True)
def na_power_price_heat_rate_spark_forecasts(**kwargs):
    return _load_main("na_power_price_heat_rate_spark_forecasts")(**kwargs)


@flow(name="us_installed_capacity_by_iso_and_fuel_type", retries=2, retry_delay_seconds=60, log_prints=True)
def us_installed_capacity_by_iso_and_fuel_type(**kwargs):
    return _load_main("us_installed_capacity_by_iso_and_fuel_type")(**kwargs)


@flow(name="us_regional_power_model", retries=2, retry_delay_seconds=60, log_prints=True)
def us_regional_power_model(**kwargs):
    return _load_main("us_regional_power_model")(**kwargs)

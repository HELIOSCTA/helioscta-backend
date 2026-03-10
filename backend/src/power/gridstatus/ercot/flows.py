"""
Prefect flow definitions for GridStatus ERCOT scripts.

Each flow wraps the corresponding script's main() function.
Entrypoints in prefect.yaml point here instead of the scripts directly.
"""

import sys
import importlib.util
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from prefect import flow


def _load_main(script_name: str):
    """Load main() from a script by filename."""
    spec = importlib.util.spec_from_file_location(
        script_name, SCRIPT_DIR / f"{script_name}.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.main


@flow(name="ercot_energy_storage_resources", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_energy_storage_resources():
    return _load_main("ercot_energy_storage_resources")()


@flow(name="ercot_fuel_mix", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_fuel_mix():
    return _load_main("ercot_fuel_mix")()


@flow(name="ercot_lmp_by_settlement_point", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_lmp_by_settlement_point():
    return _load_main("ercot_lmp_by_settlement_point")()


@flow(name="ercot_load_by_forecast_zone", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_load_by_forecast_zone():
    return _load_main("ercot_load_by_forecast_zone")()


@flow(name="ercot_load_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_load_forecast():
    return _load_main("ercot_load_forecast")()


@flow(name="ercot_load_forecast_by_forecast_zone", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_load_forecast_by_forecast_zone():
    return _load_main("ercot_load_forecast_by_forecast_zone")()


@flow(name="ercot_reported_outages", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_reported_outages():
    return _load_main("ercot_reported_outages")()


@flow(name="ercot_solar_actual_and_forecast_by_geo_region_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_solar_actual_and_forecast_by_geo_region_hourly():
    return _load_main("ercot_solar_actual_and_forecast_by_geo_region_hourly")()


@flow(name="ercot_spp_real_time_15_min", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_spp_real_time_15_min():
    return _load_main("ercot_spp_real_time_15_min")()


@flow(name="ercot_wind_actual_and_forecast_by_geo_region_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def ercot_wind_actual_and_forecast_by_geo_region_hourly():
    return _load_main("ercot_wind_actual_and_forecast_by_geo_region_hourly")()

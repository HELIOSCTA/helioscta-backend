"""
Prefect flow definitions for GridStatus SPP scripts.

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


@flow(name="spp_fuel_mix", retries=2, retry_delay_seconds=60, log_prints=True)
def spp_fuel_mix():
    return _load_main("spp_fuel_mix")()


@flow(name="spp_hourly_load", retries=2, retry_delay_seconds=60, log_prints=True)
def spp_hourly_load():
    return _load_main("spp_hourly_load")()


@flow(name="spp_lmp_day_ahead_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def spp_lmp_day_ahead_hourly():
    return _load_main("spp_lmp_day_ahead_hourly")()


@flow(name="spp_lmp_real_time_5_min", retries=2, retry_delay_seconds=60, log_prints=True)
def spp_lmp_real_time_5_min():
    return _load_main("spp_lmp_real_time_5_min")()


@flow(name="spp_load_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def spp_load_forecast():
    return _load_main("spp_load_forecast")()


@flow(name="spp_solar_and_wind_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def spp_solar_and_wind_forecast():
    return _load_main("spp_solar_and_wind_forecast")()

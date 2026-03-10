"""
Prefect flow definitions for GridStatus MISO scripts.

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


@flow(name="miso_fuel_mix", retries=2, retry_delay_seconds=60, log_prints=True)
def miso_fuel_mix():
    return _load_main("miso_fuel_mix")()


@flow(name="miso_lmp_day_ahead_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def miso_lmp_day_ahead_hourly():
    return _load_main("miso_lmp_day_ahead_hourly")()


@flow(name="miso_lmp_real_time_5_min", retries=2, retry_delay_seconds=60, log_prints=True)
def miso_lmp_real_time_5_min():
    return _load_main("miso_lmp_real_time_5_min")()


@flow(name="miso_load", retries=2, retry_delay_seconds=60, log_prints=True)
def miso_load():
    return _load_main("miso_load")()


@flow(name="miso_load_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def miso_load_forecast():
    return _load_main("miso_load_forecast")()


@flow(name="miso_solar_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def miso_solar_forecast():
    return _load_main("miso_solar_forecast")()


@flow(name="miso_wind_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def miso_wind_forecast():
    return _load_main("miso_wind_forecast")()

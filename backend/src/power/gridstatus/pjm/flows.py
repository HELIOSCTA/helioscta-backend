"""
Prefect flow definitions for GridStatus PJM scripts.

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


@flow(name="pjm_da_lmp", retries=2, retry_delay_seconds=60, log_prints=True)
def pjm_da_lmp():
    return _load_main("pjm_da_lmp")()


@flow(name="pjm_fuel_mix_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def pjm_fuel_mix_hourly():
    return _load_main("pjm_fuel_mix_hourly")()


@flow(name="pjm_load", retries=2, retry_delay_seconds=60, log_prints=True)
def pjm_load():
    return _load_main("pjm_load")()


@flow(name="pjm_load_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def pjm_load_forecast():
    return _load_main("pjm_load_forecast")()


@flow(name="pjm_rt_lmp", retries=2, retry_delay_seconds=60, log_prints=True)
def pjm_rt_lmp():
    return _load_main("pjm_rt_lmp")()


@flow(name="pjm_solar_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def pjm_solar_forecast_hourly():
    return _load_main("pjm_solar_forecast_hourly")()


@flow(name="pjm_wind_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def pjm_wind_forecast_hourly():
    return _load_main("pjm_wind_forecast_hourly")()

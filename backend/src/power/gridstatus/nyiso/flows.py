"""
Prefect flow definitions for GridStatus NYISO scripts.

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


@flow(name="nyiso_btm_solar_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def nyiso_btm_solar_forecast():
    return _load_main("nyiso_btm_solar_forecast")()


@flow(name="nyiso_fuel_mix", retries=2, retry_delay_seconds=60, log_prints=True)
def nyiso_fuel_mix():
    return _load_main("nyiso_fuel_mix")()


@flow(name="nyiso_lmp_day_ahead_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def nyiso_lmp_day_ahead_hourly():
    return _load_main("nyiso_lmp_day_ahead_hourly")()


@flow(name="nyiso_lmp_real_time_5_min", retries=2, retry_delay_seconds=60, log_prints=True)
def nyiso_lmp_real_time_5_min():
    return _load_main("nyiso_lmp_real_time_5_min")()


@flow(name="nyiso_load", retries=2, retry_delay_seconds=60, log_prints=True)
def nyiso_load():
    return _load_main("nyiso_load")()


@flow(name="nyiso_load_forecast", retries=2, retry_delay_seconds=60, log_prints=True)
def nyiso_load_forecast():
    return _load_main("nyiso_load_forecast")()

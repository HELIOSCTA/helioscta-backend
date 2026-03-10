"""
Prefect flow definitions for GridStatus CAISO scripts.

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


@flow(name="caiso_fuel_mix", retries=2, retry_delay_seconds=60, log_prints=True)
def caiso_fuel_mix():
    return _load_main("caiso_fuel_mix")()


@flow(name="caiso_lmp_day_ahead_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def caiso_lmp_day_ahead_hourly():
    return _load_main("caiso_lmp_day_ahead_hourly")()


@flow(name="caiso_lmp_real_time_15_min", retries=2, retry_delay_seconds=60, log_prints=True)
def caiso_lmp_real_time_15_min():
    return _load_main("caiso_lmp_real_time_15_min")()


@flow(name="caiso_load_forecast_7_day", retries=2, retry_delay_seconds=60, log_prints=True)
def caiso_load_forecast_7_day():
    return _load_main("caiso_load_forecast_7_day")()


@flow(name="caiso_load_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def caiso_load_hourly():
    return _load_main("caiso_load_hourly")()

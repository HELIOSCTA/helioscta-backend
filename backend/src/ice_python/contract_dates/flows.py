"""
Prefect flow definitions for ICE contract dates scripts.
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
    spec = importlib.util.spec_from_file_location(
        script_name, SCRIPT_DIR / f"{script_name}.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.main


@flow(name="runner_pjm_short_term_contract_dates", retries=2, retry_delay_seconds=60, log_prints=True)
def runner_pjm_short_term_contract_dates(**kwargs):
    return _load_main("runner_pjm_short_term")(**kwargs)


@flow(name="runner_next_day_gas_contract_dates", retries=2, retry_delay_seconds=60, log_prints=True)
def runner_next_day_gas_contract_dates(**kwargs):
    return _load_main("runner_next_day_gas")(**kwargs)


@flow(name="runner_balmo_contract_dates", retries=2, retry_delay_seconds=60, log_prints=True)
def runner_balmo_contract_dates(**kwargs):
    return _load_main("runner_balmo")(**kwargs)


@flow(name="runner_future_contracts_gas_contract_dates", retries=2, retry_delay_seconds=60, log_prints=True)
def runner_future_contracts_gas_contract_dates(**kwargs):
    return _load_main("runner_future_contracts_gas")(**kwargs)


@flow(name="runner_future_contracts_power_pjm_contract_dates", retries=2, retry_delay_seconds=60, log_prints=True)
def runner_future_contracts_power_pjm_contract_dates(**kwargs):
    return _load_main("runner_future_contracts_power_pjm")(**kwargs)


@flow(name="runner_future_contracts_power_ercot_contract_dates", retries=2, retry_delay_seconds=60, log_prints=True)
def runner_future_contracts_power_ercot_contract_dates(**kwargs):
    return _load_main("runner_future_contracts_power_ercot")(**kwargs)

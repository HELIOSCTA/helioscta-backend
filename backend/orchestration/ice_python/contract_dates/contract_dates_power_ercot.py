"""Task Scheduler entry point for the ERCOT power-futures contract-dates scrape.

Wraps `contract_dates_v1.main` with a weekday gate and an ICE-transient
retry. Sibling of `contract_dates_gas` / `contract_dates_power_pjm`.

Usage (Task Scheduler):
    python -m backend.orchestration.ice_python.contract_dates.contract_dates_power_ercot
"""
from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

from backend.orchestration.ice_python._policies import (
    ice_transient_retry_policy,
    is_weekday,
    TRADING_TZ,
)
from backend.scrapes.ice_python.contract_dates import (
    contract_dates_v1,
    ice_contract_dates_utils,
)
from backend.scrapes.ice_python.symbols.futures.power_ercot import (
    get_ercot_power_futures_product_codes,
)
from backend.utils import logging_utils

PIPELINE_NAME = "runner_future_contracts_power_ercot_contract_dates"
PRODUCT_LABEL = "ERCOT power futures"

logger = logging_utils.init_logging(
    name=f"orchestration_{PIPELINE_NAME}",
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)


@ice_transient_retry_policy(attempts=2)
def _run_scrape() -> None:
    symbols = ice_contract_dates_utils.build_futures_symbols(
        product_codes=get_ercot_power_futures_product_codes(),
    )
    contract_dates_v1.main(
        symbols=symbols,
        pipeline_name=PIPELINE_NAME,
        product_label=PRODUCT_LABEL,
    )


def main() -> int:
    try:
        logger.header(PIPELINE_NAME)

        now = datetime.now(TRADING_TZ)
        if not is_weekday(now):
            logger.info(
                f"Weekend fire ({now:%Y-%m-%d %H:%M %Z}, "
                f"{now.strftime('%a')}) — skipping."
            )
            return 0

        logger.section(
            f"Weekday ({now:%Y-%m-%d %H:%M %Z}) — invoking {PIPELINE_NAME}"
        )
        _run_scrape()
        logger.success(f"{PIPELINE_NAME} completed")
        return 0

    except Exception as exc:
        logger.exception(f"Orchestration failed: {exc}")
        return 1

    finally:
        logging_utils.close_logging()


if __name__ == "__main__":
    sys.exit(main())

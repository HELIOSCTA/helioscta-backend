"""Task Scheduler entry point for the ERCOT short-term ICE contract-dates scrape.

Wraps `contract_dates_v1.main` with a weekday gate and an ICE-transient
retry. Sibling of `contract_dates_pjm_short_term` — the only difference
is which short-term symbol registry feeds the symbol list.

Intended cadence: hourly 05:00–10:00 MT Mon–Fri. Task Scheduler owns the
window via .ps1; the weekday gate only catches off-schedule invocations.

Usage (local Windows host, via Task Scheduler):
    python -m backend.orchestration.ice_python.contract_dates.contract_dates_ercot_short_term
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
from backend.scrapes.ice_python.contract_dates import contract_dates_v1
from backend.scrapes.ice_python.symbols.short_term.ercot import (
    get_ercot_symbol_codes,
    resolve_ercot_symbol_entries,
)
from backend.utils import logging_utils

PIPELINE_NAME = "runner_ercot_short_term_contract_dates"
PRODUCT_LABEL = "ERCOT short-term"

logger = logging_utils.init_logging(
    name=f"orchestration_{PIPELINE_NAME}",
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)


@ice_transient_retry_policy(attempts=2)
def _run_scrape() -> None:
    symbols = get_ercot_symbol_codes(resolve_ercot_symbol_entries(symbols=None))
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

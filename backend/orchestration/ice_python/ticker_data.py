"""Task Scheduler entry point for the PJM short-term ICE ticker data scrape.

Wraps `backend.scrapes.ice_python.intraday_quotes.runner_pjm_short_term`
with:
  1. A post-pull freshness check. If the snapshot produced no rows for
     today's MT trade date, the run is marked degraded (warning logged) but
     not failed. Task Scheduler's .ps1 owns the firing cadence; this wrapper
     no longer pre-empts on the wall clock.
  2. A narrow ICE-transient retry for cold-start COM failures that raise
     before the per-symbol retry loop in get_timesales_batch can catch them.

Usage (local Windows host, via Task Scheduler):
    python -m backend.orchestration.ice_python.ticker_data
"""
from __future__ import annotations

import sys
from pathlib import Path

from backend.orchestration.ice_python._policies import (
    ice_transient_retry_policy,
    is_today_landed,
)
from backend.scrapes.ice_python.intraday_quotes import runner_pjm_short_term
from backend.utils import logging_utils

API_SCRAPE_NAME = "orchestration_ice_python_ticker_data"

logger = logging_utils.init_logging(
    name=API_SCRAPE_NAME,
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)


@ice_transient_retry_policy(attempts=2)
def _run_scrape() -> dict:
    return runner_pjm_short_term.main()


def main() -> int:
    """Run the ICE ticker scrape and verify today's snapshot landed."""
    try:
        logger.header(API_SCRAPE_NAME)
        logger.section(f"Invoking {API_SCRAPE_NAME}")
        summary = _run_scrape()

        is_fresh, today, latest = is_today_landed(
            summary.get("latest_trade_date") if summary else None
        )
        if is_fresh:
            logger.success(
                f"Ticker scrape completed -- snapshot landed for today "
                f"({latest}, rows={summary.get('rows_processed', 0)})"
            )
        else:
            logger.warning(
                f"Ticker scrape completed but no rows for today "
                f"(today={today}, latest_trade_date={latest}) -- "
                f"ICE may be quiet or off-hours, will catch on the next fire"
            )
        return 0

    except Exception as exc:
        logger.exception(f"Orchestration failed: {exc}")
        return 1

    finally:
        logging_utils.close_logging()


if __name__ == "__main__":
    sys.exit(main())

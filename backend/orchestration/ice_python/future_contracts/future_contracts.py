"""Task Scheduler entry point for the ICE future contracts settles scrape.

Wraps `backend.scrapes.ice_python.future_contracts.future_contracts_v1_2025_dec_16`
with:
  1. A trading-hours gate (weekday 05:00-16:00 MT). Backstops off-schedule
     fires; the .ps1 already constrains the window to 12:15-15:45 MT.
  2. A narrow ICE-transient retry for cold-start COM failures.

Intended cadence: every 30 min 12:15-15:45 MT, daily. Task Scheduler owns
the window via .ps1; this gate only catches off-schedule invocations.

Usage (local Windows host, via Task Scheduler):
    python -m backend.orchestration.ice_python.future_contracts

The three sibling modules `future_contracts_gas`, `future_contracts_power_pjm`,
and `future_contracts_power_ercot` import `run()` from this file and pass a
region-specific slice of products, so a single fire can be split across three
concurrent processes (each gets its own ICE XL / COM apartment).
"""
from __future__ import annotations

from datetime import datetime
from pathlib import Path

from backend.orchestration.ice_python._policies import (
    ice_transient_retry_policy,
    is_within_trading_hours,
    TRADING_TZ,
)
from backend.scrapes.ice_python.future_contracts import future_contracts_v1_2025_dec_16
from backend.scrapes.ice_python.symbols.futures.gas import get_gas_futures_products
from backend.utils import logging_utils

API_SCRAPE_NAME = "orchestration_ice_python_future_contracts"

logger = logging_utils.init_logging(
    name=API_SCRAPE_NAME,
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)


@ice_transient_retry_policy(attempts=2)
def _run_scrape(specific_products: list[str] | None) -> None:
    future_contracts_v1_2025_dec_16.main(specific_products=specific_products)


def _log_products(specific_products: list[str] | None) -> None:
    """Log the product list the scrape will pull, grouped by region."""
    products = future_contracts_v1_2025_dec_16._load_products()
    if specific_products:
        wanted = set(specific_products)
        products = [p for p in products if p["product"] in wanted]

    by_region: dict[str, list[dict]] = {}
    for entry in products:
        by_region.setdefault(entry.get("region", "unknown"), []).append(entry)

    logger.info(f"Pulling {len(products)} products across {len(by_region)} regions:")
    for region in sorted(by_region):
        logger.info(f"  [{region}] {len(by_region[region])} products")
        for entry in by_region[region]:
            logger.info(
                f"    {entry['product']:<6} | {entry['description']}"
            )


def run(
    specific_products: list[str] | None = None,
    label: str = API_SCRAPE_NAME,
) -> int:
    """Run the future-contracts scrape if the market is open.

    Args:
        specific_products: Optional list of ICE product codes to restrict the
            scrape to (e.g. ["HNG", "TRZ", ...] for the gas slice). None runs
            the full registry. Passed through to the scrape's `main()`.
        label: Used only in log headers so concurrent fan-out fires are easy
            to attribute when tailing logs.

    Returns the process exit code.
    """
    try:
        logger.header(label)

        now = datetime.now(TRADING_TZ)
        if not is_within_trading_hours(now):
            logger.info(
                f"Outside trading hours ({now:%Y-%m-%d %H:%M %Z}, "
                f"weekday={now.strftime('%a')}) - skipping."
            )
            return 0

        _log_products(specific_products)

        logger.section(
            f"Trading hours ({now:%Y-%m-%d %H:%M %Z}) - invoking {label}"
        )
        _run_scrape(specific_products=specific_products)
        logger.success(f"{label} completed")
        return 0

    except Exception as exc:
        logger.exception(f"Orchestration failed: {exc}")
        return 1

    finally:
        logging_utils.close_logging()


def run_gas_region(region: str) -> int:
    """Run the future-contracts scrape restricted to a single gas region.

    Filters `get_gas_futures_products()` by the entry's `region` field. Raises
    if the region matches nothing — easier to catch a typo at job-start time
    than to silently no-op for a quarter and notice in the dashboards.
    """
    products = [
        entry["product"]
        for entry in get_gas_futures_products()
        if entry.get("region") == region
    ]
    if not products:
        raise ValueError(
            f"No gas products found for region={region!r}. "
            f"Check backend/scrapes/ice_python/symbols/futures/gas.py"
        )
    return run(
        specific_products=products,
        label=f"orchestration_ice_python_future_contracts__gas_{region}",
    )



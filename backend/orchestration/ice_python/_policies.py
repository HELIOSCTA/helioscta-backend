"""Reusable policies for ICE Python orchestration wrappers."""
from __future__ import annotations

import logging
from datetime import date, datetime
from typing import Any

import pandas as pd
import pytz
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential_jitter,
)

logger = logging.getLogger("orchestration.ice_python")


# ICE XL publisher runs on the host's local time (Mountain). Timestamps in
# this module — and the post-pull freshness check below — are anchored to MT
# so they line up with what the .ps1 schedules and what ICE prints.
TRADING_TZ = pytz.timezone("America/Edmonton")


def is_weekday(now: datetime | None = None) -> bool:
    """True Mon–Fri in MT. Used by once-a-day scrapes (next-day gas settles,
    etc.) where the hour doesn't matter but weekend fires should no-op."""
    now = now or datetime.now(TRADING_TZ)
    if now.tzinfo is None:
        now = TRADING_TZ.localize(now)
    return now.weekday() < 5


# ────── Post-pull data-freshness check ──────
# Preferred over the wall-clock gate above for intraday-cadence ICE scrapes:
# proceed with the pull, then ask "did today's settle land?" off the data the
# scrape just returned. Avoids the false-negative case where today's settle
# is published but the wall-clock fires after the window closes.

def _coerce_to_date(value: Any) -> date | None:
    """Best-effort coerce pd.Timestamp / datetime / date / ISO str → date."""
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return None
    if isinstance(value, pd.Timestamp):
        return value.date()
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        return date.fromisoformat(value[:10])
    raise TypeError(f"Cannot coerce {type(value).__name__} to date: {value!r}")


def is_today_landed(
    latest_trade_date: Any,
    now: datetime | None = None,
) -> tuple[bool, date, date | None]:
    """Did the most recent row in the pull cover today's (MT) trade date?

    Returns ``(is_fresh, today, latest)``. Pure function — no DB round-trip.
    Callers pass the max trade_date observed during the scrape (or ``None``
    if the scrape returned no rows).
    """
    now = now or datetime.now(TRADING_TZ)
    if now.tzinfo is None:
        now = TRADING_TZ.localize(now)
    today = now.date()
    latest = _coerce_to_date(latest_trade_date)
    is_fresh = latest is not None and latest >= today
    return is_fresh, today, latest


# ────── Transient-error retry policy ──────
# ICE XL's COM bridge occasionally throws on cold-start (publisher waking,
# auth handshake, DCOM reconnect). These bubble up as OSError / RuntimeError
# before the per-symbol retry loop in ice_ticker_data_utils can catch them,
# so we wrap the whole orchestration `main()` with a narrow outer retry.
#
# pywintypes is only present on Windows + pywin32; we probe for it so the
# module stays importable on CI / Linux without the ICE XL dependency.
_ICE_TRANSIENT: tuple[type[BaseException], ...] = (
    OSError,
    RuntimeError,
    ConnectionError,
    TimeoutError,
)
try:
    import pywintypes

    _ICE_TRANSIENT = _ICE_TRANSIENT + (pywintypes.com_error,)
except ImportError:
    pass


def ice_transient_retry_policy(attempts: int = 2):
    """Short retry around ICE XL cold-start / COM-layer flakes.

    Narrow by design: per-symbol retries already live inside
    `ice_ticker_data_utils.get_timesales_batch`. This outer layer only
    exists to survive ICE XL publisher hiccups that raise before the
    batch loop gets a chance to retry.
    """
    return retry(
        stop=stop_after_attempt(attempts),
        wait=wait_exponential_jitter(initial=10, max=120),
        retry=retry_if_exception_type(_ICE_TRANSIENT),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )

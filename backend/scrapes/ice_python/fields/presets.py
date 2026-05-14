"""Curated field subsets for each ice_python scrape family.

Each preset is the *fallback* list a scrape uses when ICE field discovery
fails (no XL on the host, auth lapsed, etc). On a healthy host, scrapes
discover fields at runtime via ``ice.get_timeseries_fields()``; these
presets exist so the scrape still produces useful data when discovery is
unavailable.

Edit a preset here rather than hardcoding a field list inside a scrape.
"""
from __future__ import annotations

from backend.scrapes.ice_python.fields.catalog import (
    SETTLE, SETTLEMENT,
    OPEN, HIGH, LOW, CLOSE, LAST,
    VOLUME, OPEN_INTEREST,
    VWAP_OPEN, VWAP_HIGH, VWAP_LOW, VWAP_CLOSE,
    IMPLIED_VOLATILITY,
)

# Future contracts: daily OHLCV + settlement + open interest + VWAP close.
# Uses SETTLEMENT (not SETTLE) — the historical helioscta table and the
# spark-spread-viz frontend both key on data_type='Settlement' for futures.
FUTURE_CONTRACTS_FIELDS: list[str] = [
    SETTLEMENT,
    OPEN, HIGH, LOW, CLOSE, LAST,
    VOLUME, OPEN_INTEREST,
    VWAP_CLOSE,
]

# Options: futures daily set plus Implied Volatility (only options expose it).
# Starter set — refine when the options scrape is rewired.
OPTIONS_FIELDS: list[str] = [
    SETTLEMENT,
    OPEN, HIGH, LOW, CLOSE, LAST,
    VOLUME, OPEN_INTEREST,
    IMPLIED_VOLATILITY,
]

# Intraday short-term curves. Starter set — refine when intraday_quotes is
# rewired through discovery.
INTRADAY_QUOTES_FIELDS: list[str] = [
    LAST, OPEN, HIGH, LOW, CLOSE, VOLUME, SETTLE,
]

# Single-day balance-of-month strip. SETTLE (not SETTLEMENT) — balmo
# products write the canonical ICE "Settle" label, distinct from the
# "Settlement" futures use.
BALMO_FIELDS: list[str] = [SETTLE]

# Daily next-day gas settles. SETTLE matches today's behavior (no historical
# rename needed).
NEXT_DAY_GAS_FIELDS: list[str] = [SETTLE]

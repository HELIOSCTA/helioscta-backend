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
    SETTLE,
    OPEN, HIGH, LOW, CLOSE, LAST,
    VOLUME, OPEN_INTEREST,
    VWAP_OPEN, VWAP_HIGH, VWAP_LOW, VWAP_CLOSE,
    IMPLIED_VOLATILITY,
)

# Future contracts: daily OHLCV + settlement + open interest + VWAP four-pack.
# Drops Block / Combined / ICE Theoretical (synthetic or sparse) and Implied
# Volatility (structurally empty on non-options). Confirmed against a PMI
# K26-IUS run on 2026-05-13.
FUTURE_CONTRACTS_FIELDS: list[str] = [
    SETTLE,
    OPEN, HIGH, LOW, CLOSE, LAST,
    VOLUME, OPEN_INTEREST,
    VWAP_CLOSE,
]

# Options: same daily set as futures plus Implied Volatility, which futures
# leave empty. Starter set — refine when the options scrape is rewired.
OPTIONS_FIELDS: list[str] = [
    SETTLE,
    OPEN, HIGH, LOW, CLOSE, LAST,
    VOLUME, OPEN_INTEREST,
    IMPLIED_VOLATILITY,
]

# Intraday short-term curves. Starter set — refine when intraday_quotes is
# rewired through discovery.
INTRADAY_QUOTES_FIELDS: list[str] = [
    LAST, OPEN, HIGH, LOW, CLOSE, VOLUME, SETTLE,
]

# Single-day balance-of-month strip. Matches today's settle-only behavior.
BALMO_FIELDS: list[str] = [SETTLE]

# Daily next-day gas settles. Matches today's settle-only behavior.
NEXT_DAY_GAS_FIELDS: list[str] = [SETTLE]

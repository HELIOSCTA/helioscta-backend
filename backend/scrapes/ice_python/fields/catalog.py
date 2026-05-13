"""ICE Connect Python timeseries field catalog.

Source: ``ice.get_timeseries_fields(symbol)`` on a futures contract
(probed against PMI K26-IUS on 2026-05-13 — 33 fields). The exposed set
is stable across futures products; options also expose Implied Volatility.

Convention:
- One module-level constant per field; the value is the exact string ICE
  expects as ``data_type`` in ``ice.get_timeseries(symbol, data_type, ...)``.
- ``ALL_FIELDS`` preserves ICE's native ordering so anything that needs to
  match ICE's response columns doesn't have to re-derive it.

Why centralize:
- Typo-proof — misspelling SETTL vs SETTLE fails at import, not at runtime.
- Greppable — every consumer of a field shows up in one search.
- Single point of truth if ICE renames or adds a field.
"""
from __future__ import annotations

OPEN = "Open"
HIGH = "High"
LOW = "Low"
CLOSE = "Close"
LAST = "Last"
VOLUME = "Volume"
OPEN_INTEREST = "Open Interest"
VWAP_OPEN = "VWAP Open"
VWAP_HIGH = "VWAP High"
VWAP_LOW = "VWAP Low"
VWAP_CLOSE = "VWAP Close"
SETTLE = "Settle"
BLOCK_VOLUME = "Block Volume"
EFS_VOLUME = "EFS Volume"
EFP_VOLUME = "EFP Volume"
ORDERBOOK_VOLUME = "Orderbook Volume"
BLOCK_PRICE_OPEN = "Block Price Open"
BLOCK_PRICE_HIGH = "Block Price High"
BLOCK_PRICE_LOW = "Block Price Low"
BLOCK_PRICE_CLOSE = "Block Price Close"
COMBINED_PRICE_OPEN = "Combined Price Open"
COMBINED_PRICE_HIGH = "Combined Price High"
COMBINED_PRICE_LOW = "Combined Price Low"
COMBINED_PRICE_CLOSE = "Combined Price Close"
VERTICALLY_IMPLIED_VOLUME = "Vertically Implied Volume"
SPREAD_VOLUME = "Spread Volume"
SCREEN_VOLUME = "Screen Volume"
CLEARING_VOLUME = "Clearing Volume"
ICE_THEORETICAL_PRICE_OPEN = "ICE Theoretical Price Open"
ICE_THEORETICAL_PRICE_HIGH = "ICE Theoretical Price High"
ICE_THEORETICAL_PRICE_LOW = "ICE Theoretical Price Low"
ICE_THEORETICAL_PRICE_CLOSE = "ICE Theoretical Price Close"
IMPLIED_VOLATILITY = "Implied Volatility"


ALL_FIELDS: list[str] = [
    OPEN, HIGH, LOW, CLOSE, LAST, VOLUME, OPEN_INTEREST,
    VWAP_OPEN, VWAP_HIGH, VWAP_LOW, VWAP_CLOSE, SETTLE,
    BLOCK_VOLUME, EFS_VOLUME, EFP_VOLUME, ORDERBOOK_VOLUME,
    BLOCK_PRICE_OPEN, BLOCK_PRICE_HIGH, BLOCK_PRICE_LOW, BLOCK_PRICE_CLOSE,
    COMBINED_PRICE_OPEN, COMBINED_PRICE_HIGH, COMBINED_PRICE_LOW, COMBINED_PRICE_CLOSE,
    VERTICALLY_IMPLIED_VOLUME, SPREAD_VOLUME, SCREEN_VOLUME, CLEARING_VOLUME,
    ICE_THEORETICAL_PRICE_OPEN, ICE_THEORETICAL_PRICE_HIGH,
    ICE_THEORETICAL_PRICE_LOW, ICE_THEORETICAL_PRICE_CLOSE,
    IMPLIED_VOLATILITY,
]

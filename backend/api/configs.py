"""Pipeline monitoring API configuration."""

DEFAULT_LOOKBACK_HOURS = 24
DEFAULT_SCHEDULING_LOOKBACK_HOURS = 168  # 7 days
DEFAULT_STALE_HOURS = 24
DEFAULT_FAILURE_LIMIT = 50
DEFAULT_HISTORY_LIMIT = 20

VALID_SOURCES = [
    "power",
    "eia",
    "energy_aspects",
    "gas_ebbs",
    "gas_ebbs_v2",
    "ice_python",
    "natgas",
    "wsi",
    "meteologica",
    "positions_and_trades",
]

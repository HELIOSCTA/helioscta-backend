"""ICE Connect Python field catalog and per-scrape presets.

Usage:
    from backend.scrapes.ice_python.fields import SETTLE, OPEN, HIGH
    from backend.scrapes.ice_python.fields import FUTURE_CONTRACTS_FIELDS

Add a new field name to ``catalog.py``; add or edit a curated subset in
``presets.py``.
"""
from backend.scrapes.ice_python.fields.catalog import *  # noqa: F401,F403
from backend.scrapes.ice_python.fields.catalog import ALL_FIELDS  # noqa: F401
from backend.scrapes.ice_python.fields.presets import (  # noqa: F401
    FUTURE_CONTRACTS_FIELDS,
    OPTIONS_FIELDS,
    INTRADAY_QUOTES_FIELDS,
    BALMO_FIELDS,
    NEXT_DAY_GAS_FIELDS,
)

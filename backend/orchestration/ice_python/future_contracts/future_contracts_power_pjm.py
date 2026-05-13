"""PJM power slice of the ICE future contracts scrape.

One of three sibling entrypoints (gas / power_pjm / power_ercot) that fan
out the original single-process scrape into three concurrent Task Scheduler
jobs so each gets its own ICE XL / COM apartment.

Usage (Task Scheduler):
    python -m backend.orchestration.ice_python.future_contracts_power_pjm
"""
from __future__ import annotations

import sys

from backend.orchestration.ice_python.future_contracts import run
from backend.scrapes.ice_python.symbols.futures.power_pjm import (
    get_pjm_power_futures_products,
)

LABEL = "orchestration_ice_python_future_contracts__power_pjm"


def main() -> int:
    products = [entry["product"] for entry in get_pjm_power_futures_products()]
    return run(specific_products=products, label=LABEL)


if __name__ == "__main__":
    sys.exit(main())

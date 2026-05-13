"""Louisiana gas slice of the ICE future contracts scrape (Henry Hub).

One of eight sibling entrypoints (six gas regions + power_pjm + power_ercot)
that fan out the original single-process scrape into concurrent Task
Scheduler jobs so each gets its own ICE XL / COM apartment.

Usage (Task Scheduler):
    python -m backend.orchestration.ice_python.future_contracts_gas_louisiana
"""
from __future__ import annotations

import sys

from backend.orchestration.ice_python.future_contracts import run_gas_region

REGION = "louisiana"


def main() -> int:
    return run_gas_region(REGION)


if __name__ == "__main__":
    sys.exit(main())

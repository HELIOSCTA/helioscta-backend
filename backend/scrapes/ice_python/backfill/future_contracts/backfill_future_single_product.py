"""Backfill a single future-contracts product across a date window + years.

Thin wrapper around
``backend.scrapes.ice_python.future_contracts.future_contracts_v1_2025_dec_16.main``
that fixes ``specific_products`` to one ICE product code and turns on
``include_expired`` so historical contract months are pulled.

Defaults match the historical backfill range (OPJ, 2019-2028 date window,
2020-2028 contract years, all strips). To backfill a true single contract
like ``PMI K26-IUS``, pass ``specific_strips=["K"]`` and narrow the year
range.

The fields pulled are whatever ``FUTURE_CONTRACTS_FIELDS`` in
``backend/scrapes/ice_python/fields/presets.py`` currently lists — this
script does not override them.

Usage:
    python -m backend.scrapes.ice_python.backfill.future_contracts.backfill_future_single_product
"""
from __future__ import annotations

from datetime import datetime

from backend.scrapes.ice_python.future_contracts import (
    future_contracts_v1_2025_dec_16,
)


def main(
    product: str = "OPJ",
    contract_start_year: int = 2020,
    contract_end_year: int = 2028,
    start_date: datetime = datetime(2019, 1, 1),
    end_date: datetime = datetime(2028, 12, 31),
    specific_strips: list[str] | None = None,
) -> None:
    print(
        f"\n=== Backfill single product: {product} "
        f"({contract_start_year}-{contract_end_year}, "
        f"strips={specific_strips or 'all'}, "
        f"window {start_date.date()} -> {end_date.date()}) ===\n"
    )

    future_contracts_v1_2025_dec_16.main(
        specific_products=[product],
        specific_strips=specific_strips,
        contract_start_year=contract_start_year,
        contract_end_year=contract_end_year,
        start_date=start_date,
        end_date=end_date,
        include_expired=True,
    )


if __name__ == "__main__":
    main()

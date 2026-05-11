from __future__ import annotations

from datetime import datetime

from backend.src.ice_python.future_contracts.future_contracts_v1_2025_dec_16 import (
    _pull,
    _format,
    _upsert,
    get_relevant_strips,
    API_SCRAPE_NAME,
)
from backend.src.ice_python.symbols.future_contracts_gas_symbols import build_ice_symbol


def main(
    product: str = "OPJ",
    start_date: datetime = datetime(2019, 1, 1),
    end_date: datetime = datetime(2028, 12, 31),
    contract_start_year: int = 2020,
    contract_end_year: int = 2028,
) -> None:
    total_rows = 0

    print(f"\n=== Backfill single product: {product} ===\n")

    for year in range(contract_start_year, contract_end_year + 1):
        strips = get_relevant_strips(contract_year=year, include_expired=True)

        for strip, _, strip_name in strips:
            symbol = build_ice_symbol(product=product, strip=strip, contract_year=year)

            df = _pull(symbol=symbol, start_date=start_date, end_date=end_date)
            df = _format(df)

            if df.empty:
                print(f"  No data for {symbol}")
                continue

            _upsert(df, table_name=API_SCRAPE_NAME)
            total_rows += len(df)
            print(f"  Upserted {len(df)} rows for {symbol}")

    print(f"\nDone. Total rows upserted: {total_rows}")


if __name__ == "__main__":
    main()

"""Pull all PMI futures (PJM Western Hub RT Peak) into a wide DataFrame.

Supersedes the earlier single-symbol pmi_k26_ius_wide test. Filter is
`symbol LIKE 'PMI %-IUS'`, which matches every PMI futures contract
ICE emits.

Reads the committed sql/pmi_wide.sql (rendered by dbt and committed
alongside this module), executes it as a SELECT against Azure
Postgres, times the pull, and returns a DataFrame.

Usage:
    python -m backend.views.ice_python.pmi_wide
"""
from pathlib import Path

import pandas as pd

from backend.utils import azure_postgresql_utils
from backend.utils.logging_utils import init_logging


SQL_PATH = Path(__file__).parent / "sql" / "pmi_wide.sql"


def main(sql_path: Path = SQL_PATH) -> pd.DataFrame:
    logger = init_logging(name="pmi_wide", log_to_file=False)

    query = sql_path.read_text(encoding="utf-8")

    with logger.timer(f"Pulling {sql_path.name}"):
        df = azure_postgresql_utils.pull_from_db(query=query)

    logger.info(
        f"Pulled {len(df):,} rows ({df['symbol'].nunique()} symbols) "
        f"from {sql_path.name}"
    )
    return df


if __name__ == "__main__":
    df = main()
    print(df.head())

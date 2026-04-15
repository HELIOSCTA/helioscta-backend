"""Sync tables between PostgreSQL and Azure Blob Storage as parquet files."""

import time
from pathlib import Path

import pandas as pd

from backend import secrets
from backend.utils import (
    azure_postgresql_utils as azure_postgresql,
    logging_utils,
)

API_SCRAPE_NAME = "sync_to_blob"

logger = logging_utils.init_logging(
    name=API_SCRAPE_NAME,
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)

AZURE_OPTS = {"connection_string": secrets.AZURE_STORAGE_CONNECTION_STRING}
CONTAINER = secrets.AZURE_CONTAINER_NAME


def sync_to_blob(
    schema: str,
    table: str,
    sort_by: list[str] | None = None,
    row_group_size: int = 100_000,
) -> str:
    """Read a table from PostgreSQL and upload as parquet to Azure Blob.

    Args:
        schema: PostgreSQL schema (e.g. "pjm_cleaned").
        table: Table name (e.g. "pjm_lmps_hourly").
        sort_by: Columns to sort by before writing. Sorting clusters values
            so parquet row group statistics enable fast filtered reads.
        row_group_size: Max rows per row group. Smaller groups give finer-
            grained statistics but increase metadata overhead.

    Returns:
        The blob path written to (e.g. "az://helioscta/pjm_cleaned/pjm_lmps_hourly.parquet").
    """
    logger.header("Syncing to Azure Blob Storage")
    logger.section(f"Pulling {schema}.{table} from PostgreSQL ...")
    t0 = time.perf_counter()
    df = azure_postgresql.pull_from_db(
        query=f'SELECT * FROM {schema}."{table}"'
    )
    elapsed = time.perf_counter() - t0
    if df is None or df.empty:
        raise RuntimeError(f"No data returned from {schema}.{table}")
    logger.info(f"Pulled {len(df):,} rows in {elapsed:.1f}s")

    if sort_by:
        logger.section(f"Sorting by {sort_by} ...")
        df = df.sort_values(sort_by).reset_index(drop=True)

    logger.section(f"Uploading to Azure Blob Storage ...")
    blob_path = f"az://{CONTAINER}/{schema}/{table}.parquet"
    df.to_parquet(
        blob_path,
        index=False,
        engine="pyarrow",
        row_group_size=row_group_size,
        storage_options=AZURE_OPTS,
    )

    logger.info(f"Synced {len(df):,} rows → {blob_path}")
    return blob_path


def pull_from_blob(
    schema: str,
    table: str,
    filters: list[tuple] | None = None,
    columns: list[str] | None = None,
) -> pd.DataFrame:
    """Download a parquet file from Azure Blob Storage and return as DataFrame.

    Args:
        schema: Blob folder matching the PostgreSQL schema (e.g. "pjm_cleaned").
        table: File stem matching the table name (e.g. "pjm_lmps_hourly").
        filters: PyArrow row group filters for predicate pushdown. Skips row
            groups whose statistics don't match. Most effective when the
            parquet file was written with sort_by on the filtered columns.
            Example: [("datetime_beginning_utc", ">=", "2026-01-01")]
        columns: Only read these columns (column pruning).

    Returns:
        DataFrame read from the parquet file.
    """
    blob_path = f"az://{CONTAINER}/{schema}/{table}.parquet"
    logger.section(f"Pulling {blob_path} from Azure Blob Storage ...")
    t0 = time.perf_counter()
    df = pd.read_parquet(
        blob_path,
        storage_options=AZURE_OPTS,
        filters=filters,
        columns=columns,
    )
    elapsed = time.perf_counter() - t0
    logger.info(f"Pulled {len(df):,} rows in {elapsed:.1f}s")
    return df


if __name__ == "__main__":

    # upsert to blob
    sync_to_blob(schema="pjm_cleaned", table="pjm_tie_flows_hourly")
    
    # pull from blob
    df = pull_from_blob(schema="pjm_cleaned", table="pjm_tie_flows_hourly")

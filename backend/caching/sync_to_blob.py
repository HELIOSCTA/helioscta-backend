"""Sync tables between PostgreSQL and Azure Blob Storage as parquet files."""

import time
from pathlib import Path

import pandas as pd
import pyarrow as pa

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


# ── PostgreSQL → PyArrow type mapping ──────────────────────────────────────────

PG_TO_PYARROW = {
    "bigint":                       pa.int64(),
    "integer":                      pa.int32(),
    "smallint":                     pa.int16(),
    "double precision":             pa.float64(),
    "real":                         pa.float32(),
    "numeric":                      pa.float64(),
    "boolean":                      pa.bool_(),
    "date":                         pa.date32(),
    "timestamp without time zone":  pa.timestamp("us"),
    "timestamp with time zone":     pa.timestamp("us", tz="UTC"),
    "character varying":            pa.string(),
    "text":                         pa.string(),
}


def _get_pyarrow_schema(schema: str, table: str) -> pa.Schema | None:
    """Query information_schema.columns and return a PyArrow schema."""
    df = azure_postgresql.pull_from_db(
        query=(
            f"SELECT column_name, data_type "
            f"FROM information_schema.columns "
            f"WHERE table_schema = '{schema}' AND table_name = '{table}' "
            f"ORDER BY ordinal_position"
        )
    )
    if df is None or df.empty:
        return None

    fields = []
    for _, row in df.iterrows():
        pa_type = PG_TO_PYARROW.get(row["data_type"], pa.string())
        fields.append(pa.field(row["column_name"], pa_type))

    return pa.schema(fields)


def _cast_df_to_schema(df: pd.DataFrame, pa_schema: pa.Schema) -> pd.DataFrame:
    """Cast DataFrame columns to match the PyArrow schema."""
    for field in pa_schema:
        col = field.name
        if col not in df.columns:
            continue

        if pa.types.is_date(field.type):
            df[col] = pd.to_datetime(df[col]).dt.date
        elif pa.types.is_timestamp(field.type):
            df[col] = pd.to_datetime(df[col])
        elif pa.types.is_integer(field.type):
            df[col] = pd.array(df[col], dtype=pd.Int64Dtype())
        elif pa.types.is_boolean(field.type):
            df[col] = df[col].astype(pd.BooleanDtype())

    return df


# ── Sync ───────────────────────────────────────────────────────────────────────


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

    # ────── Pull data from PostgreSQL ──────
    logger.section(f"Pulling {schema}.{table} from PostgreSQL ...")
    t0 = time.perf_counter()
    df = azure_postgresql.pull_from_db(
        query=f'SELECT * FROM {schema}."{table}"'
    )
    elapsed = time.perf_counter() - t0
    if df is None or df.empty:
        raise RuntimeError(f"No data returned from {schema}.{table}")
    logger.info(f"Pulled {len(df):,} rows in {elapsed:.1f}s")

    # ────── Cast data types from PostgreSQL schema ──────
    pa_schema = _get_pyarrow_schema(schema, table)
    if pa_schema:
        logger.section("Casting data types from PostgreSQL schema ...")
        df = _cast_df_to_schema(df, pa_schema)
        for field in pa_schema:
            logger.info(f"  {field.name}: {field.type}")
    else:
        logger.info("Could not resolve schema — writing with pandas defaults")

    if sort_by:
        logger.section(f"Sorting by {sort_by} ...")
        df = df.sort_values(sort_by).reset_index(drop=True)

    # ────── Upload to Azure Blob Storage ──────
    logger.section(f"Uploading to Azure Blob Storage ...")
    blob_path = f"az://{CONTAINER}/{schema}/{table}.parquet"
    df.to_parquet(
        blob_path,
        index=False,
        engine="pyarrow",
        schema=pa_schema,
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

    # table = "pjm_lmps_hourly"
    table = 'pjm_fuel_mix_hourly'

    # upsert to blob
    sync_to_blob(schema="pjm_cleaned", table=table)

    # pull from blob
    df = pull_from_blob(schema="pjm_cleaned", table=table)

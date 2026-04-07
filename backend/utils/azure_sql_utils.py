"""
Azure SQL Server utilities for gas_ebbs_v2.

Mirror of azure_postgresql_utils.py adapted for SQL Server.
Uses pyodbc with ODBC Driver 18 for SQL Server.

Upsert strategy: temp table + MERGE (equivalent to PG's ON CONFLICT).
"""

import logging
import pytz
from typing import List
from datetime import date as datetime_date
from datetime import time as datetime_time

import numpy as np
import pandas as pd
import pyodbc

import warnings
warnings.simplefilter(action='ignore', category=Warning)

logging.basicConfig(level=logging.DEBUG)
logging.getLogger().handlers[0].setLevel(logging.DEBUG)

from backend import secrets


# ── Data type mapping ────────────────────────────────────────────────────

_PG_TO_SQLSERVER = {
    "VARCHAR": "NVARCHAR",
    "INTEGER": "INT",
    "FLOAT": "FLOAT",
    "BOOLEAN": "BIT",
    "TIMESTAMPTZ": "DATETIMEOFFSET",
    "TIMESTAMP": "DATETIME2",
    "DATE": "DATE",
}


def _map_data_type(pg_type: str, is_primary_key: bool = False) -> str:
    """Map a PostgreSQL-style type name to SQL Server equivalent."""
    base = _PG_TO_SQLSERVER.get(pg_type.upper(), "NVARCHAR")
    if base == "NVARCHAR":
        # PK columns must have a bounded length (max key size = 900 bytes)
        return "NVARCHAR(450)" if is_primary_key else "NVARCHAR(MAX)"
    return base


# ── Connection ───────────────────────────────────────────────────────────


def _connect_to_azure_sql(
    database: str = "GenscapeDataFeed",
) -> pyodbc.Connection:
    """Connect to Azure SQL Server using pyodbc."""
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={secrets.AZURE_SQL_SERVER};"
        f"DATABASE={database};"
        f"UID={secrets.AZURE_SQL_USER};"
        f"PWD={secrets.AZURE_SQL_PASSWORD};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        f"Connection Timeout=30;"
    )
    return pyodbc.connect(conn_str)


# ── Pull ─────────────────────────────────────────────────────────────────


def pull_from_db(
    query: str,
    database: str = "GenscapeDataFeed",
) -> pd.DataFrame:
    """Execute a SELECT query and return a DataFrame."""
    try:
        connection = _connect_to_azure_sql(database=database)
        df = pd.read_sql(query, connection)
        connection.close()
        return df
    except Exception as e:
        logging.info(e)
        return None


# ── Type inference ───────────────────────────────────────────────────────


def infer_sql_data_types(df: pd.DataFrame) -> List[str]:
    """Infer SQL data types from DataFrame column values."""

    def _infer_sql_data_type(df: pd.DataFrame, col: str):
        if isinstance(df[col].iloc[0], str):
            return "VARCHAR"
        elif isinstance(df[col].iloc[0], (int, np.int64, np.int32)):
            return "INTEGER"
        elif isinstance(df[col].iloc[0], (float, np.float64, np.float32)):
            return "FLOAT"
        elif isinstance(df[col].iloc[0], (bool, np.bool_)):
            return "BOOLEAN"
        elif isinstance(df[col].iloc[0], pd.Timestamp):
            return "TIMESTAMP"
        elif isinstance(df[col].iloc[0], datetime_date):
            return "DATE"
        elif isinstance(df[col].iloc[0], datetime_time):
            return "VARCHAR"
        else:
            logging.info(f"{col} dtype: {type(df[col].iloc[0])}")
            raise NotImplementedError

    return [_infer_sql_data_type(df=df, col=col) for col in df.columns]


# ── DDL helpers ──────────────────────────────────────────────────────────


def _get_query_create_table(
    schema: str,
    table_name: str,
    columns: List[str],
    data_types: List[str],
    primary_key: List[str],
) -> str:
    """Generate CREATE TABLE IF NOT EXISTS for SQL Server."""
    pk_set = set(primary_key)
    col_defs = []
    for col, dtype in zip(columns, data_types):
        sql_type = _map_data_type(dtype, is_primary_key=(col in pk_set))
        col_defs.append(f"[{col}] {sql_type}")

    # Audit columns
    col_defs.append("[created_at] DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET()")
    col_defs.append("[updated_at] DATETIMEOFFSET DEFAULT SYSDATETIMEOFFSET()")

    pk_str = ", ".join(f"[{col}]" for col in primary_key)
    cols_str = ",\n            ".join(col_defs)

    return f"""
        IF NOT EXISTS (
            SELECT * FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = '{schema}' AND TABLE_NAME = '{table_name}'
        )
        CREATE TABLE [{schema}].[{table_name}] (
            {cols_str},
            PRIMARY KEY ({pk_str})
        );
    """


def _get_query_create_temp_table(
    table_name: str,
    columns: List[str],
    data_types: List[str],
    primary_key: List[str],
) -> str:
    """Generate CREATE for a SQL Server local temp table (#)."""
    pk_set = set(primary_key)
    col_defs = []
    for col, dtype in zip(columns, data_types):
        sql_type = _map_data_type(dtype, is_primary_key=(col in pk_set))
        col_defs.append(f"[{col}] {sql_type}")

    cols_str = ", ".join(col_defs)
    return f"CREATE TABLE #temp_{table_name} ({cols_str})"


def _get_query_merge(
    schema: str,
    table_name: str,
    columns: List[str],
    primary_key: List[str],
) -> str:
    """Generate MERGE (upsert) statement for SQL Server."""
    pk_conditions = " AND ".join(
        f"target.[{col}] = source.[{col}]" for col in primary_key
    )

    non_pk_cols = [c for c in columns if c not in primary_key]
    update_set = ", ".join(
        f"target.[{col}] = source.[{col}]" for col in non_pk_cols
    )
    update_set += ", target.[updated_at] = SYSDATETIMEOFFSET()"

    insert_cols = ", ".join(f"[{col}]" for col in columns)
    insert_cols += ", [created_at], [updated_at]"

    insert_vals = ", ".join(f"source.[{col}]" for col in columns)
    insert_vals += ", SYSDATETIMEOFFSET(), SYSDATETIMEOFFSET()"

    return f"""
        MERGE [{schema}].[{table_name}] AS target
        USING #temp_{table_name} AS source
        ON {pk_conditions}
        WHEN MATCHED THEN
            UPDATE SET {update_set}
        WHEN NOT MATCHED THEN
            INSERT ({insert_cols})
            VALUES ({insert_vals});
    """


# ── Upsert ───────────────────────────────────────────────────────────────


def upsert_to_azure_sql(
    schema: str,
    table_name: str,
    df: pd.DataFrame,
    columns: List[str],
    primary_key: List[str],
    data_types: List[str] = None,
    database: str = "GenscapeDataFeed",
) -> bool:
    """Upsert a DataFrame to Azure SQL Server using MERGE.

    Strategy (mirrors azure_postgresql_utils):
        1. CREATE SCHEMA IF NOT EXISTS
        2. CREATE TABLE IF NOT EXISTS (main table)
        3. CREATE #temp table (local temp table)
        4. Bulk INSERT into #temp via fast_executemany
        5. MERGE #temp → main table (upsert)
        6. DROP #temp
    """
    # TODO: null values
    df = df.fillna(0)

    if not data_types:
        data_types = infer_sql_data_types(df=df)

    try:
        connection = _connect_to_azure_sql(database=database)
        cursor = connection.cursor()

        # Create schema if not exists
        cursor.execute(f"""
            IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '{schema}')
            EXEC('CREATE SCHEMA [{schema}]')
        """)

        # Create main table if not exists
        create_table_sql = _get_query_create_table(
            schema, table_name, columns, data_types, primary_key
        )
        cursor.execute(create_table_sql)

        # Create temp table
        create_temp_sql = _get_query_create_temp_table(
            table_name, columns, data_types, primary_key
        )
        cursor.execute(create_temp_sql)

        # Bulk insert into temp table using fast_executemany
        col_list = ", ".join(f"[{c}]" for c in columns)
        placeholders = ", ".join(["?"] * len(columns))
        insert_sql = f"INSERT INTO #temp_{table_name} ({col_list}) VALUES ({placeholders})"

        # Convert DataFrame values to Python-native types for pyodbc
        data = []
        for _, row in df[columns].iterrows():
            data.append(tuple(
                None if pd.isna(v) else
                int(v) if isinstance(v, (np.integer,)) else
                float(v) if isinstance(v, (np.floating,)) else
                str(v) if not isinstance(v, (int, float, str)) else
                v
                for v in row
            ))

        cursor.fast_executemany = True
        cursor.executemany(insert_sql, data)

        # MERGE (upsert)
        merge_sql = _get_query_merge(schema, table_name, columns, primary_key)
        cursor.execute(merge_sql)

        logging.info(f"Upserted {len(df)} rows into [{schema}].[{table_name}] ...")

        # Drop temp table
        cursor.execute(f"DROP TABLE IF EXISTS #temp_{table_name}")

        # Commit
        connection.commit()

        if cursor:
            cursor.close()
        if connection:
            connection.close()

    except Exception as e:
        logging.error(f"Error upserting data into Azure SQL: {e}")
        raise

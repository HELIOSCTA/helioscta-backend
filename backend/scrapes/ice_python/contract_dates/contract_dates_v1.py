"""ICE contract-dates scrape for any pre-built symbol list.

Takes a symbol list plus an identity (pipeline name + human-readable
label) and runs the standard `_pull` → `_format` → `_upsert` pipeline
against `ice_python.contract_dates`. The caller decides how to produce
the symbol list — that's the only thing the four scrapes (gas futures,
ercot power futures, pjm power futures, pjm short-term) differ on.

Don't call this directly from Task Scheduler — go through one of the
`backend.orchestration.ice_python.contract_dates.contract_dates_*` entry
points, which add the weekday gate and ICE-transient retry policy.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from backend.utils import logging_utils, pipeline_run_logger

from backend.scrapes.ice_python import utils
from backend.scrapes.ice_python.contract_dates import ice_contract_dates_utils

TARGET_TABLE_NAME = ice_contract_dates_utils.CONTRACT_DATES_TABLE_NAME


# ---------------------------------------------------------------------------
# Pipeline stages
# ---------------------------------------------------------------------------

def _pull(symbols: list[str], product_label: str, logger) -> list:
    if not symbols:
        logger.warning(f"No {product_label} symbols built — nothing to pull")
        return []
    logger.info(f"Requesting contract dates for {len(symbols)} symbols")
    return ice_contract_dates_utils.get_contract_dates_snapshot(symbols=symbols)


def _format(raw_data: list, logger) -> pd.DataFrame:
    trade_date = ice_contract_dates_utils.current_trade_date_mst()
    df = ice_contract_dates_utils.format_contract_dates(
        raw_data=raw_data,
        trade_date=trade_date,
    )
    if df.empty:
        logger.warning("Formatted DataFrame is empty")
    else:
        logger.info(
            f"Formatted {len(df)} contract date rows for "
            f"{trade_date.isoformat()}"
        )
    return df


def _upsert(
    df: pd.DataFrame,
    database: str = utils.DEFAULT_DATABASE,
    schema: str = utils.DEFAULT_SCHEMA,
    table_name: str = TARGET_TABLE_NAME,
) -> None:
    ice_contract_dates_utils.upsert_contract_dates(
        df=df,
        database=database,
        schema=schema,
        table_name=table_name,
    )


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

def main(
    symbols: list[str],
    pipeline_name: str,
    product_label: str,
) -> pd.DataFrame:
    """Run the contract-dates pipeline for one symbol slice.

    Args:
        symbols: ICE symbol codes to fetch contract dates for. Producing
            this list is the caller's concern (futures expansion via
            `build_futures_symbols`, or a direct registry lookup for
            short-term products).
        pipeline_name: `logging.pipeline_runs.pipeline_name` and log-file
            stem. Keep historical names stable so dashboards remain
            continuous.
        product_label: Human-readable phrase used in info/warning logs
            ("gas futures", "PJM short-term", ...).
    """
    logger = logging_utils.init_logging(
        name=pipeline_name,
        log_dir=Path(__file__).parent / "logs",
        log_to_file=True,
        delete_if_no_errors=True,
    )

    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=pipeline_name,
        source="ice_python",
        target_table=f"{utils.DEFAULT_SCHEMA}.{TARGET_TABLE_NAME}",
        operation_type="upsert",
        log_file_path=logger.log_file_path,
    )
    run.start()

    try:
        logger.header(pipeline_name)
        logger.info(f"Selected {len(symbols)} {product_label} symbols")

        raw_data = _pull(symbols=symbols, product_label=product_label, logger=logger)
        if not raw_data or len(raw_data) <= 1:
            logger.warning("No contract date data returned from ICE")
            run.success(
                rows_processed=0,
                metadata={
                    "symbols_requested": len(symbols),
                    "symbols_returned": 0,
                },
            )
            return ice_contract_dates_utils.empty_contract_dates_frame()

        df = _format(raw_data=raw_data, logger=logger)
        if df.empty:
            logger.warning("All rows dropped during formatting")
            run.success(
                rows_processed=0,
                metadata={
                    "symbols_requested": len(symbols),
                    "symbols_returned": 0,
                },
            )
            return ice_contract_dates_utils.empty_contract_dates_frame()

        returned_symbols = set(df["symbol"].unique())
        missing_symbols = set(symbols) - returned_symbols
        if missing_symbols:
            logger.warning(
                f"Missing {len(missing_symbols)}/{len(symbols)} "
                f"symbols: {sorted(missing_symbols)[:20]}"
            )

        logger.section(f"Upserting {len(df)} rows...")
        _upsert(df=df)
        logger.success("Contract dates upserted successfully")

        run.success(
            rows_processed=len(df),
            metadata={
                "symbols_requested": len(symbols),
                "symbols_returned": len(returned_symbols),
                "symbols_missing_count": len(missing_symbols),
                "trade_date": df["trade_date"].iloc[0].isoformat(),
            },
        )
        return df

    except Exception as exc:
        logger.exception(f"Pipeline failed: {exc}")
        run.failure(error=exc)
        raise

    finally:
        logging_utils.close_logging()

import importlib
import logging
from pathlib import Path

from dbt.cli.main import dbtRunner
from prefect import flow

from backend.caching.sync_to_blob import sync_to_blob
from backend.utils import logging_utils, pipeline_run_logger

logger = logging.getLogger(__name__)

DBT_PROJECT_DIR = str(Path(__file__).resolve().parents[4] / "dbt" / "dbt_azure_postgresql")


def run_dbt(select: str) -> None:
    """Run dbt models by selection syntax (e.g. '+pjm_load_forecast_hourly+')."""
    logger = logging_utils.init_logging(
        name="DBT_RUN",
        log_dir=Path(__file__).parent / "logs",
        log_to_file=True,
        delete_if_no_errors=True,
    )
    logger.header("dbt")
    logger.section(f"Running dbt: select={select}")
    result = dbtRunner().invoke([
        "run",
        "--select", select,
        "--project-dir", DBT_PROJECT_DIR,
        "--profiles-dir", DBT_PROJECT_DIR,
    ])
    if not result.success:
        logger.error(f"dbt run failed: {result.exception}")
        raise RuntimeError(f"dbt run failed: {result.exception}")
    logger.info(f"dbt run completed successfully: select={select}")


@flow(name="PJM Load Forecast")
def pjm_load_forecast():
    """Seven-Day Load Forecast — scrape latest forecast from PJM API, run dbt, sync to blob."""
    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name="seven_day_load_forecast", source="power",
    )
    run.start()
    try:
        # ────── 1. Scrape latest forecast from PJM API and upsert to PostgreSQL ──────
        mod = importlib.import_module("backend.scrapes.power.pjm.seven_day_load_forecast_v1_2025_08_13")
        mod.main()

        # ────── 2. Run dbt transformations ──────
        run_dbt("+pjm_load_forecast_hourly+ +pjm_modelling_load_forecast_hourly_da_cutoff")

        # ────── 3. Sync cleaned data to Azure Blob Storage ──────
        blob_logger = logging_utils.init_logging(
            name="SYNC_TO_BLOB",
            log_dir=Path(__file__).parent / "logs",
            log_to_file=True,
            delete_if_no_errors=True,
        )
        blob_logger.header("Azure Blob Storage")

        blob_logger.section("Syncing pjm_cleaned.pjm_load_forecast_hourly...")
        blob_path = sync_to_blob(schema="pjm_cleaned", table="pjm_load_forecast_hourly")
        blob_logger.info(f"Synced to {blob_path}")

        blob_logger.section("Syncing pjm_modelling.pjm_modelling_load_forecast_hourly_da_cutoff...")
        blob_path = sync_to_blob(schema="pjm_modelling", table="pjm_modelling_load_forecast_hourly_da_cutoff")
        blob_logger.info(f"Synced to {blob_path}")

        run.success()
    except Exception as e:
        run.failure(error=e)
        raise


if __name__ == "__main__":
    pjm_load_forecast()
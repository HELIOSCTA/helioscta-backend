import importlib
from datetime import datetime
from pathlib import Path

from dateutil.relativedelta import relativedelta
from dbt.cli.main import dbtRunner
from prefect import flow

from backend.caching.sync_to_blob import sync_to_blob
from backend.utils import logging_utils, pipeline_run_logger
from backend.utils.notification_utils import (
    already_notified,
    send_slack_notification,
)

DBT_PROJECT_DIR = str(Path(__file__).resolve().parents[4] / "dbt" / "dbt_azure_postgresql")


def run_dbt(select: str) -> None:
    """Run dbt models by selection syntax (e.g. '+pjm_lmps_hourly+')."""
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


def notify_da_lmps(target_date: str) -> None:
    """Send PJM DA LMP availability notification with dedup."""
    pipeline_name = "da_hrl_lmps"
    if already_notified(pipeline_name, target_date):
        return

    send_slack_notification(
        message=f"PJM DA LMPs available for *{target_date}* — synced to blob",
        severity="success",
        pipeline="PJM DA HRL LMPs",
        fields={"Target Date": target_date, "Destination": "Azure Blob"},
    )

    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=pipeline_name, source="power",
    )
    run.log_notification(
        channel="slack", 
        recipient="#helioscta-alerts",
        metadata={"target_date": target_date},
    )


@flow(name="PJM DA HRL LMPs")
def pjm_da_hrl_lmps():
    """Day-Ahead Hourly LMPs — poll PJM API with tenacity retries, upsert to PostgreSQL, run dbt, sync to blob."""
    mod = importlib.import_module("backend.orchestration.power.pjm.da_hrl_lmps")
    mod.main()

    run_dbt("+pjm_lmps_hourly+")
    sync_to_blob(schema="pjm_cleaned", table="pjm_lmps_hourly")

    target_date = (datetime.now() + relativedelta(days=1)).strftime("%Y-%m-%d")
    notify_da_lmps(target_date)


@flow(name="PJM DA HRL LMPs Backfill")
def pjm_da_hrl_lmps_backfill():
    """Day-Ahead Hourly LMPs — 7-day lookback backfill, no polling, sync to blob."""
    mod = importlib.import_module("backend.scrapes.power.pjm.da_hrl_lmps")
    mod.main()

    run_dbt("+pjm_lmps_hourly+")
    sync_to_blob(schema="pjm_cleaned", table="pjm_lmps_hourly")


if __name__ == "__main__":
    # pjm_da_hrl_lmps()

    target_date = (datetime.now() + relativedelta(days=1)).strftime("%Y-%m-%d")
    notify_da_lmps(target_date)

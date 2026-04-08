"""Schedule definitions for the Clear Street → MUFG pipeline."""

from dagster import ScheduleDefinition

from .check_clear_street_sftp import _already_notified_today
from .check_mufg_sftp import _already_confirmed_today
from .jobs import check_clear_street_sftp_job, check_mufg_sftp_job, clear_street_to_mufg_pipeline


def _should_execute_check_clear_street_sftp(context) -> bool:
    try:
        if _already_notified_today():
            context.log.info(
                "Today's EoD file notification was already sent; skipping scheduled run."
            )
            return False
    except Exception as exc:
        context.log.warning(
            f"Unable to evaluate prior notification state; running scheduled check anyway: {exc}"
        )

    return True


clear_street_to_mufg_pipeline_schedule = ScheduleDefinition(
    name="clear_street_to_mufg_pipeline_schedule",
    job=clear_street_to_mufg_pipeline,
    cron_schedule="*/15 21-23 * * 1-5",
    execution_timezone="America/Denver",
    description=(
        "Runs the Clear Street → MUFG pipeline every 15 minutes from "
        "9:00 PM to 11:45 PM Mountain Time, Monday through Friday.\n\n"
        "Clear Street typically publishes EOD trade files between 9–10 PM MT. "
        "The schedule retries every 15 minutes to catch late files and ensure "
        "MUFG receives the data before midnight."
    ),
)

check_clear_street_sftp_job_schedule = ScheduleDefinition(
    name="check_clear_street_sftp_job_schedule",
    job=check_clear_street_sftp_job,
    cron_schedule="*/15 21-23 * * 1-5",
    execution_timezone="America/Denver",
    should_execute=_should_execute_check_clear_street_sftp,
    description=(
        "Polls Clear Street SFTP every 15 minutes from 9-11:45 PM MT, "
        "Monday-Friday. Stops launching runs once today's file has already "
        "been detected and notified."
    ),
)


def _should_execute_check_mufg_sftp(context) -> bool:
    try:
        if _already_confirmed_today():
            context.log.info(
                "Today's MUFG file confirmation was already sent; skipping scheduled run."
            )
            return False
    except Exception as exc:
        context.log.warning(
            f"Unable to evaluate prior confirmation state; running scheduled check anyway: {exc}"
        )

    return True


check_mufg_sftp_job_schedule = ScheduleDefinition(
    name="check_mufg_sftp_job_schedule",
    job=check_mufg_sftp_job,
    cron_schedule="*/15 21-23 * * 1-5",
    execution_timezone="America/Denver",
    should_execute=_should_execute_check_mufg_sftp,
    description=(
        "Polls MUFG SFTP every 15 minutes from 9-11:45 PM MT, "
        "Monday-Friday. Stops launching runs once today's file has already "
        "been confirmed."
    ),
)

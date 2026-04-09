"""Schedule definitions for the Clear Street to MUFG pipeline."""

from dagster import ScheduleDefinition

from .check_clear_street_sftp import _already_notified_today
from .check_mufg_sftp import _already_confirmed_today
from .jobs import check_clear_street_sftp_job, check_mufg_sftp_job, clear_street_to_mufg_pipeline

PRIMARY_CRON = "*/15 19-23 * * 1-5"
OVERNIGHT_CRON = "*/15 0-2 * * 2-6"
CATCHUP_CRON = "0 3-8 * * 2-6"
TIMEZONE = "America/Denver"


def _should_execute_check_clear_street_sftp(context) -> bool:
    try:
        if _already_notified_today():
            context.log.info(
                "Expected trade-date detection notification already sent; skipping scheduled run."
            )
            return False
    except Exception as exc:
        context.log.warning(
            f"Unable to evaluate prior notification state; running scheduled check anyway: {exc}"
        )

    return True


clear_street_to_mufg_pipeline_schedule_primary = ScheduleDefinition(
    name="clear_street_to_mufg_pipeline_schedule_primary",
    job=clear_street_to_mufg_pipeline,
    cron_schedule=PRIMARY_CRON,
    execution_timezone=TIMEZONE,
    description=(
        "Primary window: runs every 15 minutes from 7:00 PM to 11:45 PM MT, "
        "Monday through Friday."
    ),
)

clear_street_to_mufg_pipeline_schedule_overnight = ScheduleDefinition(
    name="clear_street_to_mufg_pipeline_schedule_overnight",
    job=clear_street_to_mufg_pipeline,
    cron_schedule=OVERNIGHT_CRON,
    execution_timezone=TIMEZONE,
    description=(
        "Overnight continuation: runs every 15 minutes from 12:00 AM to 2:45 AM MT, "
        "Tuesday through Saturday."
    ),
)

clear_street_to_mufg_pipeline_schedule_catchup = ScheduleDefinition(
    name="clear_street_to_mufg_pipeline_schedule_catchup",
    job=clear_street_to_mufg_pipeline,
    cron_schedule=CATCHUP_CRON,
    execution_timezone=TIMEZONE,
    description=(
        "Long-tail catch-up: runs hourly from 3:00 AM to 8:00 AM MT, "
        "Tuesday through Saturday."
    ),
)

check_clear_street_sftp_job_schedule_primary = ScheduleDefinition(
    name="check_clear_street_sftp_job_schedule_primary",
    job=check_clear_street_sftp_job,
    cron_schedule=PRIMARY_CRON,
    execution_timezone=TIMEZONE,
    should_execute=_should_execute_check_clear_street_sftp,
    description=(
        "Primary window: polls Clear Street SFTP every 15 minutes from "
        "7:00 PM to 11:45 PM MT, Monday through Friday."
    ),
)

check_clear_street_sftp_job_schedule_overnight = ScheduleDefinition(
    name="check_clear_street_sftp_job_schedule_overnight",
    job=check_clear_street_sftp_job,
    cron_schedule=OVERNIGHT_CRON,
    execution_timezone=TIMEZONE,
    should_execute=_should_execute_check_clear_street_sftp,
    description=(
        "Overnight continuation: polls every 15 minutes from 12:00 AM to 2:45 AM MT, "
        "Tuesday through Saturday."
    ),
)

check_clear_street_sftp_job_schedule_catchup = ScheduleDefinition(
    name="check_clear_street_sftp_job_schedule_catchup",
    job=check_clear_street_sftp_job,
    cron_schedule=CATCHUP_CRON,
    execution_timezone=TIMEZONE,
    should_execute=_should_execute_check_clear_street_sftp,
    description=(
        "Long-tail catch-up: polls hourly from 3:00 AM to 8:00 AM MT, "
        "Tuesday through Saturday."
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


check_mufg_sftp_job_schedule_primary = ScheduleDefinition(
    name="check_mufg_sftp_job_schedule_primary",
    job=check_mufg_sftp_job,
    cron_schedule=PRIMARY_CRON,
    execution_timezone=TIMEZONE,
    should_execute=_should_execute_check_mufg_sftp,
    description=(
        "Primary window: polls MUFG SFTP every 15 minutes from 7:00 PM to "
        "11:45 PM MT, Monday through Friday."
    ),
)

check_mufg_sftp_job_schedule_overnight = ScheduleDefinition(
    name="check_mufg_sftp_job_schedule_overnight",
    job=check_mufg_sftp_job,
    cron_schedule=OVERNIGHT_CRON,
    execution_timezone=TIMEZONE,
    should_execute=_should_execute_check_mufg_sftp,
    description=(
        "Overnight continuation: polls every 15 minutes from 12:00 AM to 2:45 AM MT, "
        "Tuesday through Saturday."
    ),
)

check_mufg_sftp_job_schedule_catchup = ScheduleDefinition(
    name="check_mufg_sftp_job_schedule_catchup",
    job=check_mufg_sftp_job,
    cron_schedule=CATCHUP_CRON,
    execution_timezone=TIMEZONE,
    should_execute=_should_execute_check_mufg_sftp,
    description=(
        "Long-tail catch-up: polls hourly from 3:00 AM to 8:00 AM MT, "
        "Tuesday through Saturday."
    ),
)

# Backward-compatible aliases
clear_street_to_mufg_pipeline_schedule = clear_street_to_mufg_pipeline_schedule_primary
check_clear_street_sftp_job_schedule = check_clear_street_sftp_job_schedule_primary
check_mufg_sftp_job_schedule = check_mufg_sftp_job_schedule_primary

all_schedules = [
    clear_street_to_mufg_pipeline_schedule_primary,
    clear_street_to_mufg_pipeline_schedule_overnight,
    clear_street_to_mufg_pipeline_schedule_catchup,
    check_clear_street_sftp_job_schedule_primary,
    check_clear_street_sftp_job_schedule_overnight,
    check_clear_street_sftp_job_schedule_catchup,
    check_mufg_sftp_job_schedule_primary,
    check_mufg_sftp_job_schedule_overnight,
    check_mufg_sftp_job_schedule_catchup,
]

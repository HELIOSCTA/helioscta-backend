"""Utilities for deduplicated Slack notifications backed by pipeline_run logs."""

from __future__ import annotations

import logging
from typing import Optional

from backend.orchestration.slack_utils import send_slack
from backend.utils import azure_postgresql_utils, pipeline_run_logger

logger = logging.getLogger(__name__)


def _sql_literal(value: str) -> str:
    """Escape a string for simple SQL literal interpolation."""
    return value.replace("'", "''")


def already_sent_today(notification_key: str) -> bool:
    """Return True when notification_key already logged RUN_SUCCESS today."""
    safe_key = _sql_literal(notification_key)
    result = azure_postgresql_utils.pull_from_db(query=f"""
        SELECT COUNT(*) AS cnt
        FROM logging.pipeline_runs
        WHERE pipeline_name = '{safe_key}'
          AND event_type = 'RUN_SUCCESS'
          AND event_timestamp::date = CURRENT_DATE
    """)
    return int(result["cnt"].iloc[0]) > 0


def already_sent_for_key(notification_key: str, lookback_days: int = 14) -> bool:
    """Return True when notification_key has a RUN_SUCCESS within lookback_days."""
    safe_key = _sql_literal(notification_key)
    result = azure_postgresql_utils.pull_from_db(query=f"""
        SELECT COUNT(*) AS cnt
        FROM logging.pipeline_runs
        WHERE pipeline_name = '{safe_key}'
          AND event_type = 'RUN_SUCCESS'
          AND event_timestamp::date >= CURRENT_DATE - {int(lookback_days)}
    """)
    return int(result["cnt"].iloc[0]) > 0


def send_slack_once_per_day(
    *,
    notification_key: str,
    message: str,
    source: str = "orchestration",
    priority: str = "medium",
    tags: str = "notification,slack",
    metadata: Optional[dict] = None,
) -> bool:
    """
    Send and log a Slack notification once per day.

    Returns True when sent now, False when skipped (already sent or send failed).
    """
    if already_sent_today(notification_key):
        logger.info("Slack notification already sent today for %s; skipping", notification_key)
        return False

    sent = send_slack(message)
    if not sent:
        logger.warning("Slack send failed for %s; not recording RUN_SUCCESS", notification_key)
        run = pipeline_run_logger.PipelineRunLogger(
            pipeline_name=notification_key,
            source=source,
            priority=priority,
            tags=tags,
        )
        run.start()
        run.failure(error=RuntimeError("Failed to send Slack notification"), metadata=metadata)
        return False

    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=notification_key,
        source=source,
        priority=priority,
        tags=tags,
    )
    run.start()
    run.success(metadata=metadata)
    run.log_notification(
        channel="slack",
        recipient="default_webhook",
        metadata={"notification_key": notification_key},
    )
    return True


def send_slack_once_for_key(
    *,
    notification_key: str,
    message: str,
    source: str = "orchestration",
    priority: str = "medium",
    tags: str = "notification,slack",
    metadata: Optional[dict] = None,
    lookback_days: int = 14,
) -> bool:
    """
    Send and log a Slack notification once per key over a lookback window.

    Useful when dedupe should be keyed to business date instead of wall-clock day.
    """
    if already_sent_for_key(notification_key, lookback_days=lookback_days):
        logger.info("Slack notification already sent for key %s; skipping", notification_key)
        return False

    sent = send_slack(message)
    if not sent:
        logger.warning("Slack send failed for %s; not recording RUN_SUCCESS", notification_key)
        run = pipeline_run_logger.PipelineRunLogger(
            pipeline_name=notification_key,
            source=source,
            priority=priority,
            tags=tags,
        )
        run.start()
        run.failure(error=RuntimeError("Failed to send Slack notification"), metadata=metadata)
        return False

    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=notification_key,
        source=source,
        priority=priority,
        tags=tags,
    )
    run.start()
    run.success(metadata=metadata)
    run.log_notification(
        channel="slack",
        recipient="default_webhook",
        metadata={"notification_key": notification_key},
    )
    return True

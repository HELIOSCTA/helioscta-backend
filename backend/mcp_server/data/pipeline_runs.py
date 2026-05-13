"""Data-access layer for the pipeline-runs MCP views.

Every helper here pulls from ``logging.pipeline_runs`` in the Azure
Postgres ``helioscta`` database. The table is written by
``backend.utils.pipeline_run_logger.PipelineRunLogger``; its
``event_timestamp`` column is naive-MST, so all time math here is
expressed in MST cutoffs computed in Python to avoid server-tz
ambiguity.

Each function returns a pandas DataFrame; shaping into a view-model is
the responsibility of ``backend.mcp_server.views.pipeline_runs``.
"""
from __future__ import annotations

import logging
from datetime import timedelta

import pandas as pd

from backend.utils.azure_postgresql_utils import pull_from_db
from backend.utils.file_utils import get_mst_timestamp

logger = logging.getLogger(__name__)

SCHEMA = "logging"
TABLE = "pipeline_runs"


def _mst_cutoff(hours: int) -> str:
    """Return a SQL-quoted MST timestamp literal `now - hours`.

    Matches the naive-MST timestamps stored by PipelineRunLogger.
    """
    cutoff = get_mst_timestamp().replace(tzinfo=None) - timedelta(hours=hours)
    return cutoff.strftime("%Y-%m-%d %H:%M:%S")


def pull_failures_recent(lookback_hours: int = 24) -> pd.DataFrame:
    """RUN_FAILURE events in the last ``lookback_hours``.

    Includes log_file_content so the agent can quote tracebacks. Sorted
    newest first.
    """
    cutoff = _mst_cutoff(lookback_hours)
    query = f"""
        SELECT
            run_id, pipeline_name, event_timestamp, duration_seconds,
            error_type, error_message, log_file_content,
            target_table, operation_type, source, priority, tags, hostname
        FROM {SCHEMA}.{TABLE}
        WHERE event_type = 'RUN_FAILURE'
          AND event_timestamp >= '{cutoff}'
        ORDER BY event_timestamp DESC
    """
    logger.info(f"pull_failures_recent cutoff={cutoff}")
    return pull_from_db(query=query)


def pull_runs_terminal(lookback_hours: int = 24) -> pd.DataFrame:
    """RUN_SUCCESS + RUN_FAILURE events in the window — the 'run timeline'.

    Used by runs_summary / runs_throughput / runs_duration. Returns one
    row per terminal event with timing + volume columns.
    """
    cutoff = _mst_cutoff(lookback_hours)
    query = f"""
        SELECT
            run_id, pipeline_name, event_type, event_timestamp,
            duration_seconds, status,
            rows_processed, files_processed,
            target_table, operation_type, source, priority, tags
        FROM {SCHEMA}.{TABLE}
        WHERE event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
          AND event_timestamp >= '{cutoff}'
        ORDER BY event_timestamp DESC
    """
    logger.info(f"pull_runs_terminal cutoff={cutoff}")
    return pull_from_db(query=query)


def pull_runs_for_cadence(lookback_days: int = 14) -> pd.DataFrame:
    """All RUN_SUCCESS events over a multi-day window.

    Used by schedule_cadence to estimate the natural inter-run gap per
    pipeline. Longer lookback than the other views because cadence
    estimation needs enough samples for a median to be meaningful.
    """
    cutoff = _mst_cutoff(lookback_days * 24)
    query = f"""
        SELECT pipeline_name, event_timestamp, duration_seconds, source
        FROM {SCHEMA}.{TABLE}
        WHERE event_type = 'RUN_SUCCESS'
          AND event_timestamp >= '{cutoff}'
        ORDER BY pipeline_name, event_timestamp
    """
    logger.info(f"pull_runs_for_cadence cutoff={cutoff}")
    return pull_from_db(query=query)


def pull_notifications_recent(lookback_hours: int = 24) -> pd.DataFrame:
    """SLACK_SENT + EMAIL_SENT events in the window.

    Lets the brief check whether failures actually paged anyone — a
    silent failure (no notification row) is a different problem from a
    loud one.
    """
    cutoff = _mst_cutoff(lookback_hours)
    query = f"""
        SELECT
            run_id, pipeline_name, event_type, event_timestamp,
            notification_channel, notification_recipient, metadata,
            source, priority, tags
        FROM {SCHEMA}.{TABLE}
        WHERE event_type IN ('SLACK_SENT', 'EMAIL_SENT')
          AND event_timestamp >= '{cutoff}'
        ORDER BY event_timestamp DESC
    """
    logger.info(f"pull_notifications_recent cutoff={cutoff}")
    return pull_from_db(query=query)

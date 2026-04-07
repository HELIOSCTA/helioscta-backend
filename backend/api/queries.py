"""SQL queries against logging.pipeline_runs for pipeline health monitoring."""

import pandas as pd

from backend import secrets  # noqa: F401
from backend.utils import azure_postgresql_utils as azure_postgresql


def summary_by_domain(hours: int = 24) -> pd.DataFrame:
    """Health rollup grouped by source domain."""
    return azure_postgresql.pull_from_db(f"""
        SELECT
            source,
            COUNT(DISTINCT pipeline_name) AS total_pipelines,
            COUNT(*) FILTER (WHERE status = 'success') AS total_successes,
            COUNT(*) FILTER (WHERE status = 'failure') AS total_failures,
            MAX(event_timestamp) FILTER (WHERE status = 'success') AS last_success,
            MAX(event_timestamp) FILTER (WHERE status = 'failure') AS last_failure
        FROM logging.pipeline_runs
        WHERE event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
          AND event_timestamp >= now() - interval '{hours} hours'
        GROUP BY source
        ORDER BY total_failures DESC, source
    """)


def domain_detail_all(hours: int = 24) -> pd.DataFrame:
    """Per-pipeline health across all domains (used by summary to count statuses)."""
    return azure_postgresql.pull_from_db(f"""
        SELECT
            pipeline_name,
            source,
            COUNT(*) FILTER (WHERE status = 'success') AS successes,
            COUNT(*) FILTER (WHERE status = 'failure') AS failures
        FROM logging.pipeline_runs
        WHERE event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
          AND event_timestamp >= now() - interval '{hours} hours'
        GROUP BY pipeline_name, source
    """)


def domain_detail(source: str, hours: int = 24) -> pd.DataFrame:
    """Per-pipeline health within a single domain."""
    return azure_postgresql.pull_from_db(f"""
        SELECT
            pipeline_name,
            COUNT(*) FILTER (WHERE status = 'success') AS successes,
            COUNT(*) FILTER (WHERE status = 'failure') AS failures,
            MAX(event_timestamp) FILTER (WHERE status = 'success') AS last_success,
            MAX(event_timestamp) FILTER (WHERE status = 'failure') AS last_failure,
            ROUND(AVG(duration_seconds) FILTER (WHERE status = 'success')::numeric, 1) AS avg_duration_s
        FROM logging.pipeline_runs
        WHERE source = '{source}'
          AND event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
          AND event_timestamp >= now() - interval '{hours} hours'
        GROUP BY pipeline_name
        ORDER BY failures DESC, pipeline_name
    """)


def recent_failures(hours: int = 24, source: str | None = None, limit: int = 50) -> pd.DataFrame:
    """Recent RUN_FAILURE events, most recent first."""
    source_filter = f"AND source = '{source}'" if source else ""
    return azure_postgresql.pull_from_db(f"""
        SELECT
            pipeline_name,
            source,
            error_type,
            error_message,
            event_timestamp,
            duration_seconds,
            target_table
        FROM logging.pipeline_runs
        WHERE event_type = 'RUN_FAILURE'
          AND event_timestamp >= now() - interval '{hours} hours'
          {source_filter}
        ORDER BY event_timestamp DESC
        LIMIT {limit}
    """)


def pipeline_history(pipeline_name: str, hours: int = 72, limit: int = 20) -> pd.DataFrame:
    """Run-by-run detail for a single pipeline."""
    return azure_postgresql.pull_from_db(f"""
        SELECT
            event_type,
            status,
            event_timestamp,
            duration_seconds,
            rows_processed,
            files_processed,
            error_type,
            error_message
        FROM logging.pipeline_runs
        WHERE pipeline_name = '{pipeline_name}'
          AND event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
          AND event_timestamp >= now() - interval '{hours} hours'
        ORDER BY event_timestamp DESC
        LIMIT {limit}
    """)


def scheduling_analysis(hours: int = 168, source: str | None = None) -> pd.DataFrame:
    """Run frequency, duration, and success rate per pipeline."""
    source_filter = f"AND source = '{source}'" if source else ""
    return azure_postgresql.pull_from_db(f"""
        WITH runs AS (
            SELECT
                pipeline_name,
                source,
                status,
                event_timestamp,
                duration_seconds,
                EXTRACT(HOUR FROM event_timestamp) AS run_hour
            FROM logging.pipeline_runs
            WHERE event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
              AND event_timestamp >= now() - interval '{hours} hours'
              {source_filter}
        ),
        per_pipeline AS (
            SELECT
                pipeline_name,
                source,
                COUNT(*) AS run_count,
                COUNT(*) FILTER (WHERE status = 'success') AS successes,
                COUNT(*) FILTER (WHERE status = 'failure') AS failures,
                ROUND(AVG(duration_seconds)::numeric, 1) AS avg_duration_s,
                ROUND(MIN(duration_seconds)::numeric, 1) AS min_duration_s,
                ROUND(MAX(duration_seconds)::numeric, 1) AS max_duration_s,
                ROUND((100.0 * COUNT(*) FILTER (WHERE status = 'success') / NULLIF(COUNT(*), 0))::numeric, 1) AS success_rate_pct,
                MODE() WITHIN GROUP (ORDER BY run_hour) AS typical_run_hour,
                MIN(event_timestamp) AS first_run,
                MAX(event_timestamp) AS last_run
            FROM runs
            GROUP BY pipeline_name, source
        )
        SELECT
            pipeline_name,
            source,
            run_count,
            successes,
            failures,
            success_rate_pct,
            avg_duration_s,
            min_duration_s,
            max_duration_s,
            typical_run_hour,
            ROUND(
                EXTRACT(EPOCH FROM (last_run - first_run)) / NULLIF(run_count - 1, 0) / 3600.0, 1
            ) AS avg_hours_between_runs,
            first_run,
            last_run
        FROM per_pipeline
        ORDER BY success_rate_pct ASC, run_count DESC
    """)


def stale_pipelines(stale_hours: int = 24) -> pd.DataFrame:
    """Pipelines whose last successful run is older than stale_hours."""
    return azure_postgresql.pull_from_db(f"""
        WITH latest_success AS (
            SELECT
                pipeline_name,
                source,
                MAX(event_timestamp) AS last_success,
                ROUND(EXTRACT(EPOCH FROM (now() - MAX(event_timestamp))) / 3600.0, 1) AS hours_since_success
            FROM logging.pipeline_runs
            WHERE event_type = 'RUN_SUCCESS'
            GROUP BY pipeline_name, source
        )
        SELECT
            pipeline_name,
            source,
            last_success,
            hours_since_success
        FROM latest_success
        WHERE hours_since_success >= {stale_hours}
        ORDER BY hours_since_success DESC
    """)

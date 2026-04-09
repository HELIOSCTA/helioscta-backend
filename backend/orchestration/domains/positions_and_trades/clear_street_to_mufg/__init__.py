"""
Clear Street to MUFG subdomain.

Three-phase nightly pipeline:
  1. Pull trade CSVs from Clear Street SFTP and upsert to raw PostgreSQL table
  2. dbt build: staging models + mart view (trades_cleaned.clear_street_trades)
  3. Filter for MUFG firms (ADU/905), generate CSV, upload to MUFG SFTP

Schedule: Primary + overnight + catch-up windows (America/Denver)
Notifications: Inline Slack messages on SFTP received, success, and failure
Asset checks: Validate SFTP dates match expected trade date
"""

from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.step_pull_from_clear_street import (
    step_pull_from_clear_street,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.step_dbt_transform import (
    step_dbt_transform,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.step_upload_to_mufg import (
    step_upload_to_mufg,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.check_clear_street_sftp import (
    check_clear_street_sftp,
    raw_sftp_date_is_today,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.check_mufg_sftp import (
    check_mufg_sftp,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.jobs import (
    clear_street_to_mufg_pipeline,
    check_clear_street_sftp_job,
    check_mufg_sftp_job,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.schedules import (
    all_schedules,
)

jobs = [clear_street_to_mufg_pipeline, check_clear_street_sftp_job, check_mufg_sftp_job]
schedules = all_schedules
sensors = []

asset_checks = [
    raw_sftp_date_is_today,
]

__all__ = [
    "check_clear_street_sftp",
    "check_mufg_sftp",
    "step_pull_from_clear_street",
    "step_dbt_transform",
    "step_upload_to_mufg",
    "jobs",
    "schedules",
    "sensors",
    "asset_checks",
]

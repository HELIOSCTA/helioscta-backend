"""
Clear Street → MUFG subdomain.

Three-phase nightly pipeline:
  1. Pull trade CSVs from Clear Street SFTP → upsert to raw PostgreSQL table
  2. dbt build: staging models + mart view (trades_cleaned.clear_street_trades)
  3. Filter for MUFG firms (ADU/905) → CSV → upload to MUFG SFTP

Schedule: Every 15 min, 9–11:45 PM MT, Mon–Fri
Notifications: Inline Slack messages on SFTP received, success, and failure
Asset checks: Validate SFTP dates match today
"""

from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.clear_street_ingest import (
    pull_from_clear_street_sftp,
    raw_sftp_date_is_today,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.dbt_transform import (
    positions_and_trades_dbt_assets,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.mufg_export import (
    upload_clear_street_trades_to_mufg,
    mufg_sftp_date_is_today,
)
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.schedules import jobs, schedules

sensors = []

asset_checks = [
    raw_sftp_date_is_today,
    mufg_sftp_date_is_today,
]

__all__ = [
    "pull_from_clear_street_sftp",
    "positions_and_trades_dbt_assets",
    "upload_clear_street_trades_to_mufg",
    "jobs",
    "schedules",
    "sensors",
    "asset_checks",
]

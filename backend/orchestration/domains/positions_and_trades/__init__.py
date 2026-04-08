"""Positions & Trades domain — aggregates all subdomains."""

from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg import (
    check_clear_street_sftp,
    check_mufg_sftp,
    step_pull_from_clear_street,
    step_dbt_transform,
    step_upload_to_mufg,
    asset_checks as _cs_checks,
    jobs as _cs_jobs,
    schedules as _cs_schedules,
    sensors as _cs_sensors,
)

asset_checks = [*_cs_checks]
jobs = [*_cs_jobs]
schedules = [*_cs_schedules]
sensors = [*_cs_sensors]

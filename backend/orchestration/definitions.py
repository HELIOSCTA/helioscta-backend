"""
Dagster top-level Definitions — auto-discovers domain assets, schedules, and sensors.

Local dev:  dagster dev -f backend/orchestration/definitions.py
Docker:     docker compose up
"""

import importlib
import pkgutil

from dagster import (
    Definitions,
    load_assets_from_modules,
)
from dagster_dbt import DbtCliResource

from backend.orchestration import domains
from backend.orchestration.domains.positions_and_trades.clear_street_to_mufg.assets.dbt_transform import dbt_project

# ---------------------------------------------------------------------------
# Auto-discover all domain modules under backend/orchestration/domains/
# ---------------------------------------------------------------------------

all_assets = []
all_jobs = []
all_schedules = []
all_sensors = []
all_asset_checks = []

for _importer, domain_name, _ispkg in pkgutil.iter_modules(domains.__path__):
    module = importlib.import_module(f"backend.orchestration.domains.{domain_name}")
    all_assets += load_assets_from_modules([module], group_name=domain_name)
    all_jobs += getattr(module, "jobs", [])
    all_schedules += getattr(module, "schedules", [])
    all_sensors += getattr(module, "sensors", [])
    all_asset_checks += getattr(module, "asset_checks", [])

# ---------------------------------------------------------------------------
# Definitions
# ---------------------------------------------------------------------------

defs = Definitions(
    assets=all_assets,
    asset_checks=all_asset_checks,
    jobs=all_jobs,
    schedules=all_schedules,
    sensors=all_sensors,
    resources={
        "dbt": DbtCliResource(project_dir=dbt_project),
    },
)

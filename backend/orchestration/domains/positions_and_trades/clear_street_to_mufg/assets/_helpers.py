"""Shared helpers for Clear Street → MUFG assets."""

import os
from zoneinfo import ZoneInfo

MT = ZoneInfo("America/Denver")


def _get_tags(context) -> dict:
    tags = {}
    if hasattr(context, "run_tags"):
        tags = context.run_tags
    elif hasattr(context, "dagster_run") and context.dagster_run:
        tags = context.dagster_run.tags
    elif hasattr(context, "run") and context.run:
        tags = context.run.tags
    return tags or {}


def _is_dry_run(context) -> bool:
    if os.getenv("DAGSTER_DRY_RUN", "").lower() in ("1", "true"):
        return True
    tags = _get_tags(context)
    return tags.get("dry_run", "").lower() in ("1", "true")


def _is_test_notification(context) -> bool:
    if os.getenv("DAGSTER_TEST_NOTIFICATION", "").lower() in ("1", "true"):
        return True
    tags = _get_tags(context)
    return tags.get("test_notification", "").lower() in ("1", "true")

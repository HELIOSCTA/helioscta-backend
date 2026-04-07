"""Shared Slack notification helpers for Dagster orchestration."""

import logging
from datetime import datetime

import requests

from backend import secrets

logger = logging.getLogger(__name__)


def send_slack(text: str) -> None:
    """Post a message to the configured Slack webhook. No-ops if unconfigured."""
    webhook_url = getattr(secrets, "SLACK_DEFAULT_WEBHOOK_URL", None)
    if not webhook_url:
        logger.warning("SLACK_DEFAULT_WEBHOOK_URL not set — skipping notification")
        return
    try:
        resp = requests.post(webhook_url, json={"text": text}, timeout=10)
        resp.raise_for_status()
    except Exception:
        logger.exception("Failed to send Slack notification")


def fmt_date(date_str: str) -> str:
    """Parse various date formats and return 'Ddd Mon-DD' (e.g. 'Mon Mar-23')."""
    for fmt in ("%Y%m%d", "%Y-%m-%d", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S%z"):
        try:
            return datetime.strptime(date_str.strip(), fmt).strftime("%a %b-%d")
        except ValueError:
            continue
    return date_str

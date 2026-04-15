"""Send notifications via Azure Monitor Action Group and Slack, with dedup."""

import logging

import msal
import requests

from backend import secrets
from backend.utils import azure_postgresql_utils as azure_postgresql
from backend.utils import pipeline_run_logger

logger = logging.getLogger("utils.azure_notification_utils")

SUBSCRIPTION_ID = secrets.AZURE_SUBSCRIPTION_ID
RESOURCE_GROUP = secrets.AZURE_RESOURCE_GROUP
ACTION_GROUP_NAME = secrets.AZURE_ACTION_GROUP_NAME


# ── Dedup ────────────────────────────────────────────────────────────────────


def already_notified(pipeline_name: str, target_date: str) -> bool:
    """Check if a notification was already sent for this pipeline + date."""
    df = azure_postgresql.pull_from_db(
        query=(
            f"SELECT 1 FROM logging.pipeline_runs "
            f"WHERE pipeline_name = '{pipeline_name}' "
            f"  AND event_type = 'SLACK_SENT' "
            f"  AND metadata::jsonb->>'target_date' = '{target_date}' "
            f"LIMIT 1"
        )
    )
    return df is not None and not df.empty


# ── Azure Push ───────────────────────────────────────────────────────────────


def _get_management_token() -> str:
    """Acquire a bearer token for the Azure Management API."""
    app = msal.ConfidentialClientApplication(
        authority=f"https://login.microsoftonline.com/{secrets.AZURE_OUTLOOK_TENANT_ID}",
        client_id=secrets.AZURE_OUTLOOK_CLIENT_ID,
        client_credential=secrets.AZURE_OUTLOOK_CLIENT_SECRET,
    )
    result = app.acquire_token_for_client(
        scopes=["https://management.azure.com/.default"]
    )
    if "access_token" in result:
        return result["access_token"]
    raise RuntimeError(f"Failed to acquire management token: {result.get('error_description')}")


def send_push_notification(title: str, description: str = "") -> None:
    """Fire a push notification via the Azure Monitor Action Group."""
    url = (
        f"https://management.azure.com/subscriptions/{SUBSCRIPTION_ID}"
        f"/resourceGroups/{RESOURCE_GROUP}"
        f"/providers/Microsoft.Insights/actionGroups/{ACTION_GROUP_NAME}"
        f"/createNotifications?api-version=2024-10-01-preview"
    )
    token = _get_management_token()
    resp = requests.post(
        url,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={
            "alertType": "metricstaticthreshold",
            "emailSubject": title,
            "customMessage": description,
            "azureAppPushReceivers": [
                {"name": "mobilepush", "emailAddress": secrets.AZURE_NOTIFICATION_EMAIL},
            ],
            "emailReceivers": [
                {"name": "emailnotify", "emailAddress": secrets.AZURE_NOTIFICATION_EMAIL},
            ],
            "smsReceivers": [],
            "webhookReceivers": [],
        },
        timeout=60,
    )
    resp.raise_for_status()
    logger.info(f"Push notification sent: {title}")


# ── Slack ────────────────────────────────────────────────────────────────────


def send_slack_notification(message: str) -> None:
    """Send a Slack webhook message."""
    webhook_url = secrets.SLACK_DEFAULT_WEBHOOK_URL
    if not webhook_url:
        raise ValueError("SLACK_DEFAULT_WEBHOOK_URL is not set")
    resp = requests.post(webhook_url, json={"text": message}, timeout=10)
    resp.raise_for_status()
    logger.info(f"Slack notification sent: {message[:80]}")


if __name__ == "__main__":
    send_push_notification(title="Test Notification", description="This is a test notification.")

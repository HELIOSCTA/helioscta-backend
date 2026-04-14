"""Thin client for the New Relic Event API.

Posts batches of custom events to ``insights-collector.newrelic.com`` (US
region — set in ``backend/secrets.py``). Uses gzip compression and tenacity
exponential backoff for transient HTTP failures.

Usage:

    from backend.monitoring.newrelic import newrelic_event_api_utils
    newrelic_event_api_utils.post_events([
        {"eventType": "ClearStreetTrade", "sftp_date": "2026-04-09", ...},
        ...
    ])

The license key (``NEW_RELIC_LICENSE_KEY``) is the only credential needed for
ingest. The user API key is consumed by Terraform, never here.

Limits enforced by the API (do not raise without checking NR docs):
  * 100,000 events per POST
  * 1 MB payload after compression
  * 255 attributes per event
  * 4,096 chars per string attribute
"""

from __future__ import annotations

import gzip
import json
import logging
from typing import Iterable, Sequence

import requests
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from backend import secrets

log = logging.getLogger(__name__)

# Region-keyed ingest hostnames. US is the only region we use today; EU is
# documented for completeness in case the migration is replicated.
_INGEST_HOSTS = {
    "US": "https://insights-collector.newrelic.com",
    "EU": "https://insights-collector.eu01.nr-data.net",
}

# Conservative chunk size — far below the 100k event limit and well under the
# 1 MB compressed payload cap for typical row shapes.
DEFAULT_CHUNK_SIZE = 1000


class NewRelicConfigError(RuntimeError):
    """Raised when required NR config is missing at call time."""


def _events_url() -> str:
    """Build the Event API URL for the configured region + account."""
    region = secrets.NEW_RELIC_REGION or "US"
    if region not in _INGEST_HOSTS:
        raise NewRelicConfigError(
            f"Unsupported NEW_RELIC_REGION={region!r}. Expected one of {sorted(_INGEST_HOSTS)}."
        )
    if not secrets.NEW_RELIC_ACCOUNT_ID:
        raise NewRelicConfigError("NEW_RELIC_ACCOUNT_ID is not set.")
    return f"{_INGEST_HOSTS[region]}/v1/accounts/{secrets.NEW_RELIC_ACCOUNT_ID}/events"


def chunked(events: Sequence[dict], size: int = DEFAULT_CHUNK_SIZE) -> Iterable[list[dict]]:
    """Yield consecutive chunks of ``events`` no larger than ``size``."""
    for i in range(0, len(events), size):
        yield list(events[i : i + size])


@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=1, max=30),
    retry=retry_if_exception_type((requests.ConnectionError, requests.Timeout, requests.HTTPError)),
    reraise=True,
)
def _post_chunk(chunk: list[dict], url: str, license_key: str) -> None:
    body = gzip.compress(json.dumps(chunk).encode("utf-8"))
    resp = requests.post(
        url,
        data=body,
        headers={
            "Api-Key": license_key,
            "Content-Type": "application/json",
            "Content-Encoding": "gzip",
        },
        timeout=30,
    )
    # 5xx is retryable, 4xx is not — distinguish before tenacity reraises.
    if 500 <= resp.status_code < 600:
        resp.raise_for_status()
    if not resp.ok:
        raise NewRelicConfigError(
            f"NR Event API rejected payload ({resp.status_code}): {resp.text[:500]}"
        )


def post_events(events: Sequence[dict], *, dry_run: bool = False) -> int:
    """Post a batch of events to the NR Event API.

    Args:
        events: list of dicts; each must include ``eventType``.
        dry_run: when True, log what would be sent and return without POSTing.
            Used by ``runs.py --dry-run`` to validate query/format wiring without
            touching NR.

    Returns:
        The number of events accepted (== ``len(events)`` on success).
    """
    if not events:
        log.info("post_events called with empty batch — skipping")
        return 0

    if dry_run:
        by_type: dict[str, int] = {}
        for ev in events:
            by_type[ev.get("eventType", "<missing>")] = by_type.get(ev.get("eventType", "<missing>"), 0) + 1
        log.info("DRY RUN — would POST %d events to NR: %s", len(events), by_type)
        return len(events)

    if not secrets.NEW_RELIC_LICENSE_KEY:
        raise NewRelicConfigError(
            "NEW_RELIC_LICENSE_KEY is not set — cannot POST events. "
            "Set it in backend/.env.shared or pass --dry-run."
        )

    url = _events_url()
    sent = 0
    for chunk in chunked(list(events)):
        _post_chunk(chunk, url=url, license_key=secrets.NEW_RELIC_LICENSE_KEY)
        sent += len(chunk)
        log.info("POSTed %d/%d events to NR Event API", sent, len(events))
    return sent

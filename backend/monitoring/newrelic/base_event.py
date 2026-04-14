"""Cross-cutting attributes attached to every event POSTed to New Relic.

Every event the monitoring jobs emit must carry these so that NRQL queries can
filter on environment, host, source pipeline name, and an explicit timestamp.

The two most important attributes:

* ``environment`` — ``"prod"`` when ``BACKEND_ENV`` is ``prod``, otherwise
  ``"dev"``. Every dashboard widget and alert condition must filter
  ``WHERE environment = 'prod'`` so dev runs do not pollute prod views. This is
  the dev/prod isolation strategy chosen for the migration (single NR account,
  attribute-based filtering rather than separate sub-accounts).

* ``timestamp`` — explicit Unix epoch milliseconds. NR will use this as the
  event time instead of the time of the POST, which matters when the ingest
  job runs minutes after the rows it is reading were written.
"""

from __future__ import annotations

import socket
from datetime import datetime, timezone
from typing import Any

from backend import secrets

_HOSTNAME = socket.gethostname()


def environment() -> str:
    """Return ``"prod"`` if BACKEND_ENV is prod, otherwise ``"dev"``."""
    return "prod" if secrets.BACKEND_ENV == "prod" else "dev"


def base_attributes(source: str = "monitoring") -> dict[str, Any]:
    """Return the dict of common attributes to merge into every event."""
    return {
        "environment": environment(),
        "hostname": _HOSTNAME,
        "source": source,
    }


def epoch_ms(dt: datetime | None = None) -> int:
    """Return Unix epoch milliseconds for ``dt`` (default: now, UTC)."""
    if dt is None:
        dt = datetime.now(tz=timezone.utc)
    elif dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp() * 1000)


def make_event(event_type: str, attributes: dict[str, Any], source: str = "monitoring") -> dict[str, Any]:
    """Build a NR custom event with base attributes + caller attributes.

    The ``eventType`` discriminator and ``timestamp`` are always set; caller
    attributes can override either if needed (e.g. backfill jobs that want to
    set a historical timestamp).
    """
    event: dict[str, Any] = {
        "eventType": event_type,
        "timestamp": epoch_ms(),
        **base_attributes(source=source),
        **attributes,
    }
    return event

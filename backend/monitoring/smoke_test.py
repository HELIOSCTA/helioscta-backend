"""Phase 0 smoke test — POST one synthetic event to New Relic.

The smallest possible end-to-end check that:
  - your NEW_RELIC_LICENSE_KEY works,
  - your NEW_RELIC_ACCOUNT_ID + NEW_RELIC_REGION are right,
  - your machine can reach the NR Event API,
  - custom events are landing in NRDB.

Run:
    python -m backend.monitoring.smoke_test
    python -m backend.monitoring.smoke_test --dry-run

Then in one.newrelic.com → Query Builder, run:
    FROM HelioscaSmokeTest SELECT * SINCE 10 minutes ago

You should see one row, with attributes ``run_id``, ``message``,
``environment``, ``hostname``, and ``timestamp``.

Once you see the row you can click "Add to dashboard" in the UI to render
it as a widget — no Terraform needed for this phase.
"""

from __future__ import annotations

import argparse
import sys
import uuid

from backend import secrets
from backend.monitoring.newrelic import base_event, newrelic_event_api_utils


def build_event() -> dict:
    return base_event.make_event(
        event_type="HelioscaSmokeTest",
        attributes={
            "run_id": str(uuid.uuid4()),
            "message": "hello from backend.monitoring.smoke_test",
        },
        source="smoke_test",
    )


def main(*, dry_run: bool) -> int:
    event = build_event()
    print(f"Built event: {event}")
    print(f"Region:      {secrets.NEW_RELIC_REGION}")
    print(f"Account:     {secrets.NEW_RELIC_ACCOUNT_ID or '<not set>'}")
    print(f"License key: {'set' if secrets.NEW_RELIC_LICENSE_KEY else '<not set>'}")
    print()

    sent = newrelic_event_api_utils.post_events([event], dry_run=dry_run)
    print()
    if dry_run:
        print(f"DRY RUN — would have POSTed {sent} event. No HTTPS call made.")
    else:
        print(f"OK — POSTed {sent} event to New Relic.")
        print()
        print("Verify in one.newrelic.com → Query Builder:")
        print(f"  FROM HelioscaSmokeTest SELECT * WHERE run_id = '{event['run_id']}' SINCE 10 minutes ago")
    return 0


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Build the event and print it, but skip the POST. Use without a license key to validate wiring.",
    )
    return parser.parse_args(argv)


if __name__ == "__main__":
    args = _parse_args(sys.argv[1:])
    sys.exit(main(dry_run=args.dry_run))

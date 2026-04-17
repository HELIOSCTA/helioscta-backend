"""Wraps Clear Street end-of-day trade pull with poll-until-available retries.

Task Scheduler entrypoint:
    python -m backend.orchestration.postions_and_trades.clear_street_to_mufg.clear_street_eod_trades

The wrapper splits the original scrape into two phases so that retry policies
can be applied with the right semantics:

  1. _wait_for_fresh_file()
       Connects to Clear Street SFTP, lists files matching the trade pattern,
       finds the latest file by st_mtime, and raises FileNotYetAvailable if
       the file is older than 12 hours. This avoids date-comparison bugs
       when polling crosses midnight. The check is cheap (one listdir) so
       polling it is safe.

  2. _run_scrape()
       Once the file is confirmed present, runs the existing scrape.main()
       once under a short transient-retry policy. SSH/network blips during
       the actual download or upsert are absorbed without re-entering the
       poll loop.

Files are named Helios_Transactions_YYYYMMDD.csv. The poll checks that the
latest file's st_mtime is less than 12 hours old.
"""
import logging
import re
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from backend import secrets
from backend.orchestration.postions_and_trades.clear_street_to_mufg._policies import (
    FileNotYetAvailable,
    sftp_poll_policy,
    sftp_transient_retry_policy,
)
from backend.scrapes.postions_and_trades.tasks.pull_from_sftp.trades.clear_street import (
    helios_transactions_v2_2026_feb_23 as scrape,
)

logger = logging.getLogger("orchestration.postions_and_trades")

MST = ZoneInfo("America/Denver")

TRADE_FILE_PATTERN = "Helios_Transactions_*.csv"
FRESHNESS_THRESHOLD = timedelta(hours=12)

# Regex to match Helios_Transactions_YYYYMMDD.csv filenames
_FILENAME_RE = re.compile(r"Helios_Transactions_\d{8}\.csv", re.IGNORECASE)


@sftp_poll_policy()
def _wait_for_fresh_file() -> None:
    """Block until a fresh Clear Street trade file is on the SFTP server.

    Lists all Helios_Transactions_*.csv files, finds the latest by st_mtime,
    and raises FileNotYetAvailable if it is older than 12 hours.
    """
    sftp, transport = scrape._connect_to_clear_street_sftp(
        host=secrets.CLEAR_STREET_SFTP_HOST,
        port=secrets.CLEAR_STREET_SFTP_PORT,
        username=secrets.CLEAR_STREET_SFTP_USER,
        private_key_path=secrets.CLEAR_STREET_SSH_KEY_CONTENT,
    )
    try:
        files = sftp.listdir_attr(secrets.CLEAR_STREET_SFTP_REMOTE_DIR)
        matching = [attr for attr in files if _FILENAME_RE.match(attr.filename)]

        if not matching:
            raise FileNotYetAvailable(
                f"No {TRADE_FILE_PATTERN} files found on Clear Street SFTP"
            )

        # Sort by mtime descending to get the most recent files
        matching.sort(key=lambda x: x.st_mtime, reverse=True)

        # Log the last 3 files as a table
        recent = matching[:3]
        header = f"{'Filename':<40} | {'Released':<30} | {'Age'}"
        separator = "-" * len(header)
        now = datetime.now(timezone.utc)
        rows = []
        for attr in recent:
            modified = datetime.fromtimestamp(attr.st_mtime, tz=timezone.utc)
            age = now - modified
            age_str = f"{age.total_seconds() / 3600:.1f}h"
            rows.append(
                f"{attr.filename:<40} | "
                f"{modified.astimezone(MST):%Y-%m-%d %I:%M:%S %p} MST  | "
                f"{age_str}"
            )
        logger.info(
            f"Recent Clear Street files:\n{header}\n{separator}\n" + "\n".join(rows)
        )

        latest = matching[0]
        latest_modified = datetime.fromtimestamp(latest.st_mtime, tz=timezone.utc)
        age = now - latest_modified

        if age > FRESHNESS_THRESHOLD:
            raise FileNotYetAvailable(
                f"Latest file {latest.filename} is {age.total_seconds() / 3600:.1f}h old, "
                f"waiting for fresh file (threshold: {FRESHNESS_THRESHOLD.total_seconds() / 3600:.0f}h)"
            )
    finally:
        sftp.close()
        transport.close()


@sftp_transient_retry_policy(attempts=3)
def _run_scrape(lookback_days: int) -> None:
    """Run the existing scrape once. Retried only on transient SFTP errors."""
    scrape.main(lookback_days=lookback_days)


def main(lookback_days: int = 5) -> None:
    _wait_for_fresh_file()
    _run_scrape(lookback_days=lookback_days)


if __name__ == "__main__":
    # main()

    _wait_for_fresh_file()

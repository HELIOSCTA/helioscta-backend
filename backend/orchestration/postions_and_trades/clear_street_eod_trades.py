"""Wraps Clear Street end-of-day trade pull with poll-until-available retries.

Task Scheduler entrypoint:
    python -m backend.orchestration.postions_and_trades.clear_street_eod_trades

The wrapper splits the original scrape into two phases so that retry policies
can be applied with the right semantics:

  1. _wait_for_fresh_file()
       Connects to Clear Street SFTP, lists files matching the trade pattern,
       and raises FileNotYetAvailable if nothing recent is present. Decorated
       with the poll policy (long ceiling, exponential jitter). This is the
       phase that "spams SFTP until the file is available". The check is cheap
       (one listdir) so polling it is safe.

  2. _run_scrape()
       Once the file is confirmed present, runs the existing scrape.main()
       once under a short transient-retry policy. SSH/network blips during
       the actual download or upsert are absorbed without re-entering the
       long poll loop.

"Freshness" is defined as: at least one file matching the trade pattern with
an SFTP mtime within the last FRESHNESS_HOURS hours. We deliberately do NOT
parse a date out of the filename, because Clear Street's filename date
convention (UTC vs MST vs trade date vs settlement date) is not known here.
mtime is convention-agnostic and handles weekends/holidays naturally.
"""
import fnmatch
from datetime import datetime, timedelta, timezone

from backend import secrets
from backend.orchestration.postions_and_trades._policies import (
    FileNotYetAvailable,
    sftp_poll_policy,
    sftp_transient_retry_policy,
)
from backend.src.postions_and_trades.tasks.pull_from_sftp.trades.clear_street import (
    helios_transactions_v2_2026_feb_23 as scrape,
)

TRADE_FILE_PATTERN = "Helios_Transactions_*.csv"
FRESHNESS_HOURS = 12
POLL_CEILING_SECONDS = 60 * 60  # 1 hour total wait before giving up


@sftp_poll_policy(max_seconds=POLL_CEILING_SECONDS)
def _wait_for_fresh_file() -> None:
    """Block until a recent Clear Street trade file is on the SFTP server.

    Raises FileNotYetAvailable on each empty poll; the decorator catches that
    and waits with exponential jitter before retrying.
    """
    sftp, transport = scrape._connect_to_clear_street_sftp(
        host=secrets.CLEAR_STREET_SFTP_HOST,
        port=secrets.CLEAR_STREET_SFTP_PORT,
        username=secrets.CLEAR_STREET_SFTP_USER,
        private_key_path=secrets.CLEAR_STREET_SSH_KEY_CONTENT,
    )
    try:
        cutoff = datetime.now(timezone.utc) - timedelta(hours=FRESHNESS_HOURS)
        fresh = [
            attr
            for attr in sftp.listdir_attr(secrets.CLEAR_STREET_SFTP_REMOTE_DIR)
            if fnmatch.fnmatchcase(attr.filename.upper(), TRADE_FILE_PATTERN.upper())
            and datetime.fromtimestamp(attr.st_mtime, tz=timezone.utc) >= cutoff
        ]
        if not fresh:
            raise FileNotYetAvailable(
                f"No {TRADE_FILE_PATTERN} files newer than "
                f"{FRESHNESS_HOURS}h on Clear Street SFTP yet"
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

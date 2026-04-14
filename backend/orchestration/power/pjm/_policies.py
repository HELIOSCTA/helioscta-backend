"""Reusable tenacity policies for PJM orchestration wrappers."""
import logging

import requests
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_delay,
    stop_after_attempt,
    wait_exponential_jitter,
)

logger = logging.getLogger("orchestration.power.pjm")


class DataNotYetAvailable(Exception):
    """Raised when the PJM API returns a successful but empty response."""


API_TRANSIENT = (
    DataNotYetAvailable,
    requests.ConnectionError,
    requests.Timeout,
    ConnectionResetError,
)


def api_poll_policy(max_seconds: int = 18_000):
    """Poll-until-available with exponential jitter. Default 5h ceiling.

    PJM DA LMPs are posted daily between 12:00–01:30 PM EPT.
    The long ceiling accommodates late postings without a wall-clock check.
    """
    return retry(
        stop=stop_after_delay(max_seconds),
        wait=wait_exponential_jitter(initial=30, max=300),
        retry=retry_if_exception_type(API_TRANSIENT),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )


def api_transient_retry_policy(attempts: int = 3):
    """Short retry on transient HTTP / network errors. No polling.

    Use this around the download+upsert phase, AFTER the poll phase has
    confirmed data is available.
    """
    return retry(
        stop=stop_after_attempt(attempts),
        wait=wait_exponential_jitter(initial=10, max=120),
        retry=retry_if_exception_type(
            (requests.ConnectionError, requests.Timeout, ConnectionResetError)
        ),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )

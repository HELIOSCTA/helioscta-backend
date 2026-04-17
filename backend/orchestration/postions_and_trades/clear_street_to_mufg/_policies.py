"""Reusable tenacity policies for postions_and_trades orchestration wrappers."""
import logging
import socket

import paramiko
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential_jitter,
    wait_fixed,
)

logger = logging.getLogger("orchestration.postions_and_trades")


class FileNotYetAvailable(Exception):
    """Raised by a wrapper when an expected upstream file has not landed yet."""


SFTP_TRANSIENT = (
    FileNotYetAvailable,
    paramiko.SSHException,
    socket.timeout,
    EOFError,
    ConnectionResetError,
)


def sftp_poll_policy():
    """Poll-until-available every 60s. No ceiling — Prefect schedule controls lifetime."""
    return retry(
        wait=wait_fixed(60),
        retry=retry_if_exception_type(SFTP_TRANSIENT),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )


def sftp_transient_retry_policy(attempts: int = 3):
    """Short retry on transient SFTP / network errors. No polling.

    Use this around the actual scrape run, AFTER the poll phase has confirmed
    a file is available. It absorbs SSH/network blips during download or
    upsert without retrying the long poll loop.
    """
    return retry(
        stop=stop_after_attempt(attempts),
        wait=wait_exponential_jitter(initial=10, max=120),
        retry=retry_if_exception_type(
            (paramiko.SSHException, socket.timeout, EOFError, ConnectionResetError)
        ),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )

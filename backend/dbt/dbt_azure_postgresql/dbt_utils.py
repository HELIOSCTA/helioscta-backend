"""
Utilities for running dbt with advisory lock protection and subprocess management.

Provides:
- PostgreSQL advisory lock acquire/release (crash-safe, auto-released on disconnect)
- dbt subprocess execution with timeout and Windows process-tree kill
"""

import logging
import os
import platform
import subprocess

import psycopg2

from backend import secrets


logger = logging.getLogger(__name__)

# Advisory lock key — consistent hash so any caller uses the same lock
ADVISORY_LOCK_KEY = "dbt_run"

# Default dbt project path (relative to repo root)
DBT_PROJECT_DIR = os.path.join(
    os.path.dirname(__file__), "..", "..", "dbt", "dbt_azure_postgresql"
)


# ---------------------------------------------------------------------------
# Advisory lock
# ---------------------------------------------------------------------------

def get_pg_connection() -> psycopg2.extensions.connection:
    """Open a connection to Azure PostgreSQL for advisory lock management."""
    conn = psycopg2.connect(
        host=secrets.AZURE_POSTGRESQL_DB_HOST,
        user=secrets.AZURE_POSTGRESQL_DB_USER,
        password=secrets.AZURE_POSTGRESQL_DB_PASSWORD,
        port=secrets.AZURE_POSTGRESQL_DB_PORT,
        dbname="helioscta",
        connect_timeout=10,
    )
    conn.autocommit = True
    return conn


def acquire_advisory_lock(conn: psycopg2.extensions.connection) -> bool:
    """Try to acquire a PostgreSQL session-level advisory lock.

    Returns True if acquired, False if another session holds it.
    The lock is automatically released when the connection closes (crash-safe).
    """
    with conn.cursor() as cur:
        cur.execute(
            "SELECT pg_try_advisory_lock(hashtext(%s))", (ADVISORY_LOCK_KEY,)
        )
        result = cur.fetchone()
        return result[0] if result else False


def release_advisory_lock(conn: psycopg2.extensions.connection) -> None:
    """Explicitly release the advisory lock (also released on disconnect)."""
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT pg_advisory_unlock(hashtext(%s))", (ADVISORY_LOCK_KEY,)
            )
    except Exception as e:
        logger.warning(f"Failed to release advisory lock: {e}")


# ---------------------------------------------------------------------------
# dbt subprocess
# ---------------------------------------------------------------------------

def _kill_process_tree(pid: int) -> None:
    """Kill a process and all its children. Windows-safe via taskkill /T."""
    if platform.system() == "Windows":
        subprocess.run(
            ["taskkill", "/T", "/F", "/PID", str(pid)],
            capture_output=True,
        )
    else:
        import signal
        os.killpg(os.getpgid(pid), signal.SIGKILL)


def run_dbt(
    project_dir: str | None = None,
    select: str | None = None,
    timeout_seconds: int = 1800,
    dry_run: bool = False,
) -> tuple[int, str, str]:
    """Run ``dbt run`` as a subprocess.

    Args:
        project_dir: Path to the dbt project. Defaults to the repo's dbt project.
        select: Optional dbt --select argument (e.g. "tag:pjm").
        timeout_seconds: Hard kill after this many seconds (default 30 min).
        dry_run: If True, log the command but don't execute.

    Returns:
        (exit_code, stdout, stderr) — exit_code is -1 on timeout.
    """
    project_dir = project_dir or os.path.abspath(DBT_PROJECT_DIR)

    cmd = ["dbt", "run"]
    if select:
        cmd.extend(["--select", select])

    logger.info(f"dbt command: {' '.join(cmd)} (cwd={project_dir})")

    if dry_run:
        logger.info("[DRY RUN] Skipping dbt execution")
        return 0, "[dry run] no output", ""

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=project_dir,
            # On non-Windows, create a process group so we can kill the tree
            **({} if platform.system() == "Windows" else {"start_new_session": True}),
        )

        # Stream stdout in real time while capturing it
        stdout_lines: list[str] = []
        for line in proc.stdout:
            line = line.rstrip("\n")
            logger.info(f"[dbt] {line}")
            stdout_lines.append(line)

        # Wait for process to finish and collect stderr
        proc.wait(timeout=timeout_seconds)
        stderr = proc.stderr.read()

        return proc.returncode, "\n".join(stdout_lines), stderr

    except subprocess.TimeoutExpired:
        logger.error(f"dbt run timed out after {timeout_seconds}s — killing process tree")
        _kill_process_tree(proc.pid)
        proc.wait(timeout=10)
        return -1, "\n".join(stdout_lines), proc.stderr.read() or ""

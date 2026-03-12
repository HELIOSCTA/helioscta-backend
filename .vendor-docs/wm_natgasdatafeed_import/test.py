"""
Run gasdatafeed_import.ps1 every 5 minutes
"""

import os
import subprocess
import time
from pathlib import Path

from helioscta_api_scrapes.helioscta_api_scrapes.utils import (
    logging_utils,
)

# SCRAPE
API_SCRAPE_NAME = "wm_natgasdatafeed_import"

# logging
logger = logging_utils.init_logging(
    name=API_SCRAPE_NAME,
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)


def run_gasdatafeed_import():
    """Execute the gasdatafeed_import.ps1 script."""

    user_profile = os.environ["USERPROFILE"]
    script_dir = os.path.join(
        user_profile,
        "Documents",
        "github",
        "airflow_admin",
        "task_scheduler",
        "genscape",
        "wm_natgasdatafeed_import",
    )
    script_path = os.path.join(script_dir, "gasdatafeed_import.ps1")
    pwsh_path = os.path.join(os.environ["WINDIR"], "System32", "WindowsPowerShell", "v1.0", "powershell.exe")

    logger.info("Running gasdatafeed_import.ps1...")

    result = subprocess.run(
        [
            pwsh_path,
            "-ExecutionPolicy", "Bypass",
            "-File", script_path,
            "-sourceType", "delta",
            "-writeLog", "true",
            "-Verbose",
        ],
        cwd=script_dir,
        capture_output=True,
        text=True,
    )

    # Log stdout line by line
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            if line.strip():
                logger.info(line)

    # Log stderr line by line
    if result.stderr:
        for line in result.stderr.strip().split("\n"):
            if line.strip():
                logger.error(line)

    if result.returncode == 0:
        logger.info("Completed successfully")
    else:
        logger.error(f"Failed with return code: {result.returncode}")

    return result.returncode


if __name__ == "__main__":
    logger.info("Starting scheduler - running every 5 minutes")
    run_gasdatafeed_import()

    # while True:
        # logger.info("Sleeping for 5 minutes...")
        # time.sleep(300)  # 5 minutes

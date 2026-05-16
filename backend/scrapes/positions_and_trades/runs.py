"""
Runner for manually executing SFTP pull scripts (positions, trades, trade_breaks).

Usage:
    python -m backend.scrapes.positions_and_trades.runs                    # interactive menu
    python -m backend.scrapes.positions_and_trades.runs --list             # list all available scripts
    python -m backend.scrapes.positions_and_trades.runs <number>           # run script by menu number
    python -m backend.scrapes.positions_and_trades.runs <number> <number>  # run multiple scripts sequentially
    python -m backend.scrapes.positions_and_trades.runs all                # run all scripts
"""

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
# SCRIPT_DIR = backend/scrapes/positions_and_trades
# .parent = backend/scrapes
# .parent.parent = backend
# .parent.parent.parent = repo root
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from backend.utils.runner_utils import RunnerConfig, runner_main, run_script_main_only

EXCLUDE = {"__init__.py", "utils.py", "runs.py", "flows.py", "settings.py"}


def discover_scripts() -> list[Path]:
    """Find all runnable SFTP pull scripts across subfolders."""
    scripts: list[Path] = []
    for path in sorted(SCRIPT_DIR.rglob("*.py")):
        if path.name in EXCLUDE:
            continue
        if path.parent == SCRIPT_DIR:
            continue
        scripts.append(path)
    return scripts


def _relative_group(script: Path) -> str:
    """Return the subfolder path relative to SCRIPT_DIR (e.g. 'positions/marex')."""
    return str(script.parent.relative_to(SCRIPT_DIR))


def display_menu(scripts: list[Path]) -> None:
    """Print a numbered menu of available scripts, grouped by subfolder."""
    print("\n=== Available SFTP Pull Scripts ===\n")
    current_group = None
    for index, script in enumerate(scripts, 1):
        group = _relative_group(script)
        if group != current_group:
            current_group = group
            print(f"  --- {group} ---")
        print(f"  [{index:>2}] {script.stem}")
    print()


def main() -> None:
    config = RunnerConfig(
        name="SFTP Pull",
        project_root=PROJECT_ROOT,
        discover=discover_scripts,
        display=display_menu,
        display_name=lambda path: f"{_relative_group(path)}/{path.stem}",
        adapter=run_script_main_only,
    )
    runner_main(config)


if __name__ == "__main__":
    main()


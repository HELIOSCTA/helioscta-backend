---
name: python-script-args
description: Python scrape scripts and orchestration entry points in this repo take parameters as function arguments with defaults, NOT via argparse. Use when authoring or editing any `python -m`-runnable script under `backend/scrapes/`, `backend/orchestration/`, or sibling test/probe scripts. Skip when working on `backend/utils/runner_utils.py` (the shared CLI dispatcher is intentionally argv-driven) or on genuine operator-facing CLI tools where shell-completion matters and the user has explicitly asked for argparse.
---

# python-script-args

Default to function arguments with sensible defaults in any new Python entry-point script. Do not reach for `argparse.ArgumentParser` or hand-rolled `sys.argv` parsing.

## Why

- Scrape and orchestration scripts in this repo run almost entirely via `python -m <module>` (Task Scheduler, hand invocation, programmatic calls from `backend/orchestration/`). The Task Scheduler `.ps1` registrations never pass flags.
- The shared dispatcher in `backend/utils/runner_utils.py` already owns argv parsing for the runner pattern. A second argparse layer inside a script competes with it and confuses which call site wins.
- Function-arg scripts compose: `from backend.scrapes.X.Y import main; main(symbol="…")` works from a notebook, a test, or another module. `argparse` doesn't compose without exec-style hacks.
- Defaults at the top of the file are obvious in code review. Flag definitions buried inside `parser.add_argument` calls are not.

## The pattern

```python
"""One-line summary of the script."""
from __future__ import annotations

# ── Defaults ────────────────────────────────────────────────────────────
DEFAULT_SYMBOL = "HNG H26-IUS"
DEFAULT_LOOKBACK_DAYS = 10
DEFAULT_FIELDS: list[str] = ["Settlement", "Volume"]


def main(
    symbol: str = DEFAULT_SYMBOL,
    lookback_days: int = DEFAULT_LOOKBACK_DAYS,
    fields: list[str] | None = None,
) -> int:
    fields = fields or DEFAULT_FIELDS
    ...
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Run it: `python -m backend.scrapes.<...>.<module>`. To override a value, edit the call to `main(...)` at the bottom or change a `DEFAULT_*` constant.

## Anti-pattern

```python
# DO NOT do this in scrape / orchestration / probe scripts.
import argparse

def main() -> int:
    parser = argparse.ArgumentParser(...)
    parser.add_argument("--symbol", default="HNG H26-IUS")
    parser.add_argument("--lookback-days", type=int, default=10)
    args = parser.parse_args()
    ...
```

## When argparse IS allowed

- `backend/utils/runner_utils.py` and any future shared CLI dispatcher — argv parsing is the dispatcher's job.
- Standalone operator tools that ship with shell completion or are documented as flag-driven (must be called out in the module docstring and approved by the user — don't guess).

## How to apply

1. **Authoring a new script:** start from the pattern above. Defaults at the top, single `main(...)` with typed kwargs, `if __name__ == "__main__": raise SystemExit(main())` at the bottom.
2. **Editing an existing script:** if you see `argparse` and the script lives under `backend/scrapes/` or `backend/orchestration/`, refactor it: hoist each `add_argument` default to a top-level `DEFAULT_*` constant, add a matching kwarg to `main()`, drop the parser block. Keep behavior identical.
3. **Reviewing a PR:** flag any new `import argparse` line in `backend/scrapes/` or `backend/orchestration/` paths. Ask whether the script meets one of the "allowed" exceptions; default answer is no.

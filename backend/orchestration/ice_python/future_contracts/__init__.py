"""Future-contracts orchestration package.

Re-exports `run` and `run_gas_region` from the inner module so existing
imports like `from backend.orchestration.ice_python.future_contracts import
run_gas_region` keep resolving after the file-to-package reorganization.
"""
from backend.orchestration.ice_python.future_contracts.future_contracts import (
    run,
    run_gas_region,
)

__all__ = ["run", "run_gas_region"]

import importlib

from prefect import flow


@flow(name="PJM DA HRL LMPs")
def pjm_da_hrl_lmps():
    """Day-Ahead Hourly LMPs — pull from PJM API and upsert to PostgreSQL."""
    mod = importlib.import_module("backend.scrapes.power.pjm.da_hrl_lmps")
    mod.main()


if __name__ == "__main__":
    pjm_da_hrl_lmps()
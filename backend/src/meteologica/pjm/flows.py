"""
Prefect flow definitions for Meteologica PJM scripts.

Each flow wraps the corresponding script's main() function.
Entrypoints in prefect.yaml point here instead of the scripts directly.
"""

import sys
import importlib.util
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from prefect import flow


def _load_main(script_name: str):
    """Load main() from a Meteologica PJM script by filename."""
    spec = importlib.util.spec_from_file_location(
        script_name, SCRIPT_DIR / f"{script_name}.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.main


# ── Demand (PJM Aggregate) ─────────────────────────────────────────────────


@flow(name="usa_pjm_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_power_demand_long_term_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_power_demand_long_term_hourly(**kwargs):
    return _load_main("usa_pjm_power_demand_long_term_hourly")(**kwargs)


@flow(name="usa_pjm_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_power_demand_observation")(**kwargs)


# ── Demand (Mid-Atlantic) ──────────────────────────────────────────────────


@flow(name="usa_pjm_midatlantic_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_ae_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ae_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_ae_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_bc_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_bc_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_bc_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_dplco_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_dplco_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_dplco_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_easton_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_easton_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_easton_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_jc_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_jc_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_jc_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_me_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_me_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_me_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pe_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pe_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pe_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_pepco_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_pepco_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_pepco_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_smeco_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_smeco_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_smeco_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_plco_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_plco_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_plco_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_ugi_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_ugi_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_ugi_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pn_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pn_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pn_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_ps_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ps_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_ps_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_reco_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_reco_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_reco_power_demand_forecast_hourly")(**kwargs)


# ── Demand (South) ─────────────────────────────────────────────────────────


@flow(name="usa_pjm_south_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_south_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_south_dom_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_dom_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_south_dom_power_demand_forecast_hourly")(**kwargs)


# ── Demand (West) ──────────────────────────────────────────────────────────


@flow(name="usa_pjm_west_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepapt_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepapt_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepapt_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepimp_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepimp_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepimp_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepkpt_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepkpt_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepkpt_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepopt_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepopt_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepopt_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_ap_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ap_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_ap_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_oe_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_oe_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_oe_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_papwr_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_papwr_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_papwr_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_ce_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ce_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_ce_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_day_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_day_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_day_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_deok_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_deok_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_deok_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_duq_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_duq_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_duq_power_demand_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_ekpc_power_demand_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ekpc_power_demand_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_ekpc_power_demand_forecast_hourly")(**kwargs)


# ── Wind (PJM Aggregate) ──────────────────────────────────────────────────


@flow(name="usa_pjm_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_wind_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_wind_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_wind_power_generation_normal_hourly")(**kwargs)


@flow(name="usa_pjm_wind_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_wind_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_wind_power_generation_observation")(**kwargs)


# ── Wind (Mid-Atlantic) ───────────────────────────────────────────────────


@flow(name="usa_pjm_midatlantic_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_ae_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ae_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_ae_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pn_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pn_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pn_wind_power_generation_forecast_hourly")(**kwargs)


# ── Wind (South) ──────────────────────────────────────────────────────────


@flow(name="usa_pjm_south_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_south_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_south_dom_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_dom_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_south_dom_wind_power_generation_forecast_hourly")(**kwargs)


# ── Wind (West) ───────────────────────────────────────────────────────────


@flow(name="usa_pjm_west_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_ap_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ap_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_ap_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_wind_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_ce_wind_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ce_wind_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_ce_wind_power_generation_forecast_hourly")(**kwargs)


# ── PV/Solar (PJM Aggregate) ──────────────────────────────────────────────


@flow(name="usa_pjm_pv_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_pv_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_pv_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_pv_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_pv_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_pv_power_generation_normal_hourly")(**kwargs)


@flow(name="usa_pjm_pv_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_pv_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_pv_power_generation_observation")(**kwargs)


# ── PV/Solar (Regional) ───────────────────────────────────────────────────


@flow(name="usa_pjm_midatlantic_pv_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pv_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pv_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_south_pv_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_pv_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_south_pv_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_pv_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_pv_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_pv_power_generation_forecast_hourly")(**kwargs)


# ── Hydro ──────────────────────────────────────────────────────────────────


@flow(name="usa_pjm_hydro_power_generation_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_hydro_power_generation_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_hydro_power_generation_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_hydro_power_generation_forecast_daily", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_hydro_power_generation_forecast_daily(**kwargs):
    return _load_main("usa_pjm_hydro_power_generation_forecast_daily")(**kwargs)


@flow(name="usa_pjm_hydro_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_hydro_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_hydro_power_generation_normal_hourly")(**kwargs)


# ── Day-Ahead Price ────────────────────────────────────────────────────────


@flow(name="usa_pjm_da_power_price_system_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_da_power_price_system_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_da_power_price_system_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_aep_dayton_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_aep_dayton_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_aep_dayton_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_aep_gen_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_aep_gen_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_aep_gen_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_atsi_gen_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_atsi_gen_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_atsi_gen_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_chicago_gen_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_chicago_gen_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_chicago_gen_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_chicago_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_chicago_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_chicago_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_dominion_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_dominion_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_dominion_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_eastern_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_eastern_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_eastern_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_n_illinois_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_n_illinois_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_n_illinois_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_new_jersey_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_new_jersey_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_new_jersey_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_ohio_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_ohio_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_ohio_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_western_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_western_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_western_hub_da_power_price_forecast_hourly")(**kwargs)


@flow(name="usa_pjm_west_int_hub_da_power_price_forecast_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_int_hub_da_power_price_forecast_hourly(**kwargs):
    return _load_main("usa_pjm_west_int_hub_da_power_price_forecast_hourly")(**kwargs)


# ── Wind ECMWF ENS (PJM Aggregate) ──────────────────────────────────────────


@flow(name="usa_pjm_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


# ── Wind ECMWF ENS (Mid-Atlantic) ───────────────────────────────────────────


@flow(name="usa_pjm_midatlantic_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_ae_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ae_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_ae_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pn_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pn_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pn_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


# ── Wind ECMWF ENS (South) ──────────────────────────────────────────────────


@flow(name="usa_pjm_south_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_south_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_south_dom_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_dom_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_south_dom_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


# ── Wind ECMWF ENS (West) ───────────────────────────────────────────────────


@flow(name="usa_pjm_west_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_west_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_west_ap_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ap_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_west_ap_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_west_ce_wind_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ce_wind_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_west_ce_wind_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


# ── PV/Solar ECMWF ENS ──────────────────────────────────────────────────────


@flow(name="usa_pjm_pv_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_pv_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_pv_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pv_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pv_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pv_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_south_pv_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_pv_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_south_pv_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_west_pv_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_pv_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_west_pv_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


# ── Hydro ECMWF ENS ─────────────────────────────────────────────────────────


@flow(name="usa_pjm_hydro_power_generation_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_hydro_power_generation_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_hydro_power_generation_forecast_ecmwf_ens_hourly")(**kwargs)


# ── Day-Ahead Price ECMWF ENS ────────────────────────────────────────────────


@flow(name="usa_pjm_da_power_price_system_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_da_power_price_system_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_da_power_price_system_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_aep_dayton_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_aep_dayton_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_aep_dayton_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_aep_gen_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_aep_gen_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_aep_gen_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_atsi_gen_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_atsi_gen_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_atsi_gen_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_chicago_gen_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_chicago_gen_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_chicago_gen_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_chicago_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_chicago_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_chicago_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_dominion_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_dominion_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_dominion_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_eastern_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_eastern_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_eastern_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_n_illinois_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_n_illinois_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_n_illinois_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_new_jersey_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_new_jersey_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_new_jersey_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_ohio_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_ohio_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_ohio_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_west_int_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_int_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_west_int_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


@flow(name="usa_pjm_western_hub_da_power_price_forecast_ecmwf_ens_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_western_hub_da_power_price_forecast_ecmwf_ens_hourly(**kwargs):
    return _load_main("usa_pjm_western_hub_da_power_price_forecast_ecmwf_ens_hourly")(**kwargs)


# ── Demand Observations (Mid-Atlantic) ─────────────────────────────────────────


@flow(name="usa_pjm_midatlantic_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_me_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_me_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_me_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pn_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pn_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pn_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_ps_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ps_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_ps_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pe_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pe_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pe_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_ugi_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_ugi_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_ugi_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_plco_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_plco_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_plco_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_bc_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_bc_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_bc_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_jc_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_jc_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_jc_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_smeco_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_smeco_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_smeco_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_pepco_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_pepco_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_pepco_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_ae_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ae_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_ae_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_easton_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_easton_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_easton_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_dplco_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_dplco_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_dplco_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_reco_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_reco_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_reco_power_demand_observation")(**kwargs)


# ── Demand Observations (West) ────────────────────────────────────────────────


@flow(name="usa_pjm_west_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_ce_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ce_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_ce_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_ap_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ap_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_ap_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_aep_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_aep_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_aep_aepkpt_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepkpt_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_aep_aepkpt_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_aep_aepapt_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepapt_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_aep_aepapt_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_aep_aepopt_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepopt_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_aep_aepopt_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_aep_aepimp_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepimp_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_aep_aepimp_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_duq_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_duq_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_duq_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_day_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_day_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_day_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_atsi_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_atsi_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_atsi_oe_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_oe_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_atsi_oe_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_atsi_papwr_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_papwr_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_atsi_papwr_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_deok_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_deok_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_deok_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_west_ekpc_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ekpc_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_west_ekpc_power_demand_observation")(**kwargs)


# ── Demand Observations (South) ───────────────────────────────────────────────


@flow(name="usa_pjm_south_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_south_power_demand_observation")(**kwargs)


@flow(name="usa_pjm_south_dom_power_demand_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_dom_power_demand_observation(**kwargs):
    return _load_main("usa_pjm_south_dom_power_demand_observation")(**kwargs)


# ── Wind Observations (Regional) ──────────────────────────────────────────────


@flow(name="usa_pjm_west_wind_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_wind_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_west_wind_power_generation_observation")(**kwargs)


@flow(name="usa_pjm_midatlantic_wind_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_wind_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_wind_power_generation_observation")(**kwargs)


@flow(name="usa_pjm_south_wind_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_wind_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_south_wind_power_generation_observation")(**kwargs)


# ── PV/Solar Observations (Regional) ─────────────────────────────────────────


@flow(name="usa_pjm_midatlantic_pv_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pv_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_midatlantic_pv_power_generation_observation")(**kwargs)


@flow(name="usa_pjm_west_pv_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_pv_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_west_pv_power_generation_observation")(**kwargs)


@flow(name="usa_pjm_south_pv_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_pv_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_south_pv_power_generation_observation")(**kwargs)


# ── Hydro Observation ───────────────────────────────────────────────────────


@flow(name="usa_pjm_hydro_power_generation_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_hydro_power_generation_observation(**kwargs):
    return _load_main("usa_pjm_hydro_power_generation_observation")(**kwargs)


# ── Day-Ahead Price Observations ──────────────────────────────────────────────


@flow(name="usa_pjm_da_power_price_system_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_da_power_price_system_observation(**kwargs):
    return _load_main("usa_pjm_da_power_price_system_observation")(**kwargs)


@flow(name="usa_pjm_aep_dayton_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_aep_dayton_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_aep_dayton_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_aep_gen_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_aep_gen_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_aep_gen_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_atsi_gen_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_atsi_gen_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_atsi_gen_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_chicago_gen_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_chicago_gen_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_chicago_gen_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_chicago_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_chicago_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_chicago_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_dominion_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_dominion_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_dominion_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_eastern_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_eastern_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_eastern_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_n_illinois_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_n_illinois_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_n_illinois_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_new_jersey_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_new_jersey_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_new_jersey_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_ohio_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_ohio_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_ohio_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_west_int_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_int_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_west_int_hub_da_power_price_observation")(**kwargs)


@flow(name="usa_pjm_western_hub_da_power_price_observation", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_western_hub_da_power_price_observation(**kwargs):
    return _load_main("usa_pjm_western_hub_da_power_price_observation")(**kwargs)


# ── Wind Normals (Regional) ───────────────────────────────────────────────────


@flow(name="usa_pjm_west_wind_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_wind_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_west_wind_power_generation_normal_hourly")(**kwargs)


@flow(name="usa_pjm_south_wind_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_wind_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_south_wind_power_generation_normal_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_wind_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_wind_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_wind_power_generation_normal_hourly")(**kwargs)


# ── PV/Solar Normals (Regional) ───────────────────────────────────────────────


@flow(name="usa_pjm_west_pv_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_pv_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_west_pv_power_generation_normal_hourly")(**kwargs)


@flow(name="usa_pjm_south_pv_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_pv_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_south_pv_power_generation_normal_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pv_power_generation_normal_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pv_power_generation_normal_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pv_power_generation_normal_hourly")(**kwargs)


# ── Demand Projections (West) ─────────────────────────────────────────────────


@flow(name="usa_pjm_west_aep_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepapt_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepapt_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepapt_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepkpt_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepkpt_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepkpt_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepimp_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepimp_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepimp_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_aep_aepopt_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_aep_aepopt_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_aep_aepopt_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_oe_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_oe_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_oe_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_atsi_papwr_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_atsi_papwr_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_atsi_papwr_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_ap_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ap_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_ap_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_ce_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ce_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_ce_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_day_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_day_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_day_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_deok_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_deok_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_deok_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_duq_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_duq_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_duq_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_west_ekpc_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_west_ekpc_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_west_ekpc_power_demand_projection_hourly")(**kwargs)


# ── Demand Projections (Mid-Atlantic) ─────────────────────────────────────────


@flow(name="usa_pjm_midatlantic_pl_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_plco_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_plco_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_plco_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pl_ugi_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pl_ugi_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pl_ugi_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_pepco_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_pepco_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_pepco_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pep_smeco_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pep_smeco_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pep_smeco_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_dplco_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_dplco_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_dplco_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_dpl_easton_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_dpl_easton_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_dpl_easton_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_ae_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ae_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_ae_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_bc_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_bc_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_bc_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_jc_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_jc_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_jc_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_me_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_me_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_me_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pe_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pe_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pe_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_pn_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_pn_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_pn_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_ps_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_ps_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_ps_power_demand_projection_hourly")(**kwargs)


@flow(name="usa_pjm_midatlantic_reco_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_midatlantic_reco_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_midatlantic_reco_power_demand_projection_hourly")(**kwargs)


# ── Demand Projections (South) ────────────────────────────────────────────────


@flow(name="usa_pjm_south_dom_power_demand_projection_hourly", retries=2, retry_delay_seconds=60, log_prints=True)
def usa_pjm_south_dom_power_demand_projection_hourly(**kwargs):
    return _load_main("usa_pjm_south_dom_power_demand_projection_hourly")(**kwargs)

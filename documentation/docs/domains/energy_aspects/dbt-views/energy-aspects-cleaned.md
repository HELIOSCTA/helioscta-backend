# Energy Aspects Cleaned dbt Views

All views are materialized in the `energy_aspects_cleaned` schema. Initial scope: PJM only.

---

## Mart Views

### ea_pjm_power_model_monthly

| Field | Value |
|-------|-------|
| **Business Definition** | EA monthly generation by fuel type, demand, gas demand, and net imports for PJM |
| **Grain** | One row per month |
| **Primary Key** | `date` |
| **Upstream** | `staging_v1_ea_pjm_power_model_monthly` |
| **Use Cases** | PJM generation mix forecasting, gas-for-power demand analysis, supply/demand balance |
| **Refresh** | View -- refreshes on query |

#### Columns

| Column | Description |
|--------|-------------|
| `date` | Monthly observation/forecast date |
| `coal_generation_ea_price_mw` | Coal generation under EA price assumptions (MW) |
| `coal_generation_fwd_price_mw` | Coal generation under forward price assumptions (MW) |
| `ng_generation_ea_price_mw` | Natural gas generation under EA price assumptions (MW) |
| `ng_generation_fwd_price_mw` | Natural gas generation under forward price assumptions (MW) |
| `nuclear_generation_mw` | Nuclear generation (MW) |
| `solar_generation_mw` | Solar generation (MW) |
| `wind_generation_mw` | Wind generation (MW) |
| `hydro_generation_mw` | Hydro generation (MW) |
| `other_generation_mw` | Other generation (MW) |
| `thermal_generation_norm_weather_mw` | Thermal generation under normal weather (MW) |
| `net_imports_mw` | Net imports into PJM (MW) |
| `demand_mw` | Actual load / forecast load under normal weather (MW) |
| `ng_demand_ea_price_bcf_per_d` | Gas demand for power under EA price (bcf/d) |
| `ng_demand_fwd_price_bcf_per_d` | Gas demand for power under forward price (bcf/d) |
| `ng_equiv_demand_norm_weather_bcf_per_d` | Weather-normalized gas equivalent demand (bcf/d) |

---

### ea_pjm_price_hr_spark_monthly

| Field | Value |
|-------|-------|
| **Business Definition** | EA monthly on-peak power price, heat rate, and dirty spark spread for PJM West |
| **Grain** | One row per month |
| **Primary Key** | `date` |
| **Upstream** | `staging_v1_ea_pjm_price_hr_spark_monthly` |
| **Use Cases** | Power price forecasting, implied heat rate trends, spark spread analysis |
| **Refresh** | View -- refreshes on query |

#### Columns

| Column | Description |
|--------|-------------|
| `date` | Monthly observation/forecast date |
| `on_peak_power_price_usd_per_mwh` | PJM West on-peak power price ($/MWh) |
| `on_peak_heat_rate_mmbtu_per_mwh` | PJM West on-peak implied heat rate (MMBtu/MWh) |
| `on_peak_dirty_spark_spread_usd_per_mwh` | PJM West on-peak dirty spark spread ($/MWh) |

---

### ea_pjm_load_model_monthly

| Field | Value |
|-------|-------|
| **Business Definition** | EA monthly weather-normalized load model for PJM |
| **Grain** | One row per month |
| **Primary Key** | `date` |
| **Upstream** | `staging_v1_ea_pjm_load_model_monthly` |
| **Use Cases** | Weather-adjusted load trend analysis, load forecasting |
| **Refresh** | View -- refreshes on query |

#### Columns

| Column | Description |
|--------|-------------|
| `date` | Monthly observation/forecast date |
| `load_norm_weather_mw` | EA modeled historical + forecast load under normal weather (MW) |
| `actual_load_norm_weather_mw` | Actual load combined with forecast load under normal weather (MW) |

---

### ea_pjm_installed_capacity_monthly

| Field | Value |
|-------|-------|
| **Business Definition** | EA monthly installed generation capacity by fuel type for PJM |
| **Grain** | One row per month |
| **Primary Key** | `date` |
| **Upstream** | `staging_v1_ea_pjm_installed_capacity_monthly` |
| **Use Cases** | Capacity mix evolution, renewable penetration tracking, retirement/addition analysis |
| **Refresh** | View -- refreshes on query |

#### Columns

| Column | Description |
|--------|-------------|
| `date` | Monthly observation/forecast date |
| `ng_capacity_mw` | Natural gas installed capacity (MW) |
| `coal_capacity_mw` | Coal installed capacity (MW) |
| `nuclear_capacity_mw` | Nuclear installed capacity (MW) |
| `oil_capacity_mw` | Oil products installed capacity (MW) |
| `solar_capacity_mw` | Solar installed capacity (MW) |
| `onshore_wind_capacity_mw` | Onshore wind installed capacity (MW) |
| `offshore_wind_capacity_mw` | Offshore wind installed capacity (MW) |
| `hydro_capacity_mw` | Hydro installed capacity (MW) |
| `battery_capacity_mw` | Battery installed capacity (MW) |

---

### ea_pjm_dispatch_costs_monthly

| Field | Value |
|-------|-------|
| **Business Definition** | EA monthly dispatch costs and fuel costs by fuel type, plant type, and hub for PJM |
| **Grain** | One row per month |
| **Primary Key** | `date` |
| **Upstream** | `staging_v1_ea_pjm_dispatch_costs_monthly` |
| **Use Cases** | Merit order analysis, fuel cost benchmarking, regional cost differentials |
| **Refresh** | View -- refreshes on query |

#### Column Groups (36 total, all $/MWh)

**NG Dispatch Costs (RGGI included):**
- PJM W: high/low HR CCGT, CT, ST
- PJM Dominion: high/low HR CCGT, CT, ST

**NG Fuel Costs:**
- PJM Nihub: high/low HR CCGT, CT, ST
- PJM Adhub: high/low HR CCGT, CT, ST
- PJM W: high/low HR CCGT, CT, ST
- PJM Dominion: high/low HR CCGT, CT, ST

**Diesel/Fuel Oil Dispatch Costs (RGGI included):**
- PJM W: diesel CCGT, diesel CT, fuel oil ST

**Coal Dispatch Costs (RGGI included):**
- PJM W: bituminous coal (high/low/mid transport)

**Coal Fuel Costs:**
- PJM W: bituminous coal (high/low/mid transport)
- PJM Nihub: sub-bituminous coal (high/low/mid transport)

# EIA Scrape Cards

## Hourly Generation by Fuel Type

| Field | Value |
|-------|-------|
| **Script** | `backend/src/eia/fuel_type_hrl_gen_v3_2026_mar_09.py` |
| **Source** | EIA Open Data API v2 (`/electricity/rto/fuel-type-data`) |
| **Target Table** | `eia.fuel_type_hrl_gen_v3_2026_mar_09` |
| **Schema** | `eia` |
| **dbt Views** | `eia_cleaned.eia_930_hourly`, `eia_cleaned.eia_930_daily` |
| **Trigger** | Scheduled (Prefect) |
| **Default Pull Window** | Last 3 days |
| **Freshness** | ~1 hour lag |
| **Owner** | TBD |

### Business Purpose

Provides a comprehensive view of U.S. electricity generation broken down by fuel source (natural gas, coal, nuclear, wind, solar, etc.) across all major balancing authorities. Answers the question: "Where is the power coming from right now?"

### Data Captured

| Field | Description |
|-------|-------------|
| `datetime_utc` | Hour timestamp in UTC |
| `date` | Date portion |
| `hour` | Hour of day (0-23) |
| `respondent` | Balancing authority code (e.g., PJM, ERCO, US48) |
| `natural_gas` | MW generated from natural gas |
| `coal` | MW generated from coal |
| `nuclear` | MW generated from nuclear |
| `wind` | MW generated from wind |
| `solar` | MW generated from solar |
| `hydro` | MW generated from hydro |
| `battery_storage` | MW from battery storage |
| `petroleum` | MW from petroleum |
| `geothermal` | MW from geothermal |
| `pumped_storage` | MW from pumped storage |
| `other` | MW from other sources |
| + 6 more columns | Additional storage and integrated types |

### Respondents Covered

~50+ balancing authorities organized by region:
- **National:** US48
- **Northeast:** ISNE (ISO-NE), NYIS (NYISO)
- **Mid-Atlantic:** PJM
- **Midwest:** MISO, AECI, LGEE
- **Southeast:** TVA, SOCO, SE, SEPA, DUK, CPLE, CPLW, SC, SCEG
- **Florida:** FPL, FPC, FMPP, JEA, GVL, HST
- **Texas:** ERCO (ERCOT)
- **Central:** SWPP (SPP)
- **Northwest:** BPAT, AVA, IPCO, NWMT, PACE, PACW, PGE, PSEI, SCL, etc.
- **Southwest:** AZPS, DEAA, EPE
- **California:** CISO (CAISO), BANC, LDWP, IID, TIDC

### Known Caveats

- EIA API paginated at 5,000 rows; script handles pagination automatically
- Some respondents may have duplicate fuel type columns (e.g., two "pumped_storage" columns); the script sums duplicates
- Backfill available from 2019 onward via `backfill()` function

---

## Weekly Natural Gas Underground Storage

| Field | Value |
|-------|-------|
| **Script** | `backend/src/eia/weekly_underground_storage_test.py` |
| **Source** | EIA Open Data API v2 (`/natural-gas/stor/wkly`) |
| **Target Table** | `eia.weekly_underground_storage_test` |
| **Schema** | `eia` |
| **Trigger** | Scheduled (Prefect) |
| **Default Pull Window** | Last 61 days |
| **Freshness** | Same-day (Thursday release) |
| **Owner** | TBD |

### Business Purpose

Tracks weekly natural gas in underground storage by region. This is one of the most closely watched energy reports -- released every Thursday at 10:30 AM ET by the EIA. Storage levels relative to the 5-year average are a key driver of natural gas prices.

### Data Captured

| Field | Description |
|-------|-------------|
| `eia_week_ending` | The Friday that ends the reporting week |
| `region` | Storage region (East, Midwest, Mountain, Pacific, South Central, etc.) |
| `value` | Volume in BCF (Billion Cubic Feet) |
| `series_description` | Full EIA series description |

### Known Caveats

- Script name ends in `_test` but this is the production script
- Region is extracted from `series_description` via regex
- Weekly frequency -- not suitable for intraday analysis

---

## Form 860 (Generator Attributes)

| Field | Value |
|-------|-------|
| **Script** | `backend/src/eia/eia_860_test.py` |
| **Source** | EIA Open Data API v2 (`/electricity/rto/fuel-type-data`) |
| **Target Table** | `eia.eia_860_test` |
| **Schema** | `eia` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | TBD |
| **Owner** | TBD |

### Business Purpose

Captures generator-level attributes including capacity and fuel type. Used as reference data for understanding the generation fleet.

### Known Caveats

- Script name ends in `_test` but this is the production script
- Uses the same EIA fuel-type-data endpoint as the hourly generation script but with different formatting
- May overlap with hourly generation data -- check with team for intended distinction

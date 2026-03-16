# Backend Gas EBB Scraper TODOs — 2026-03-16 Gap Analysis

Source: `bot/gas_ebbs/outputs/gap_coverage_2026-03-16.json` cross-referenced against
`helioscta-backend/backend/src/gas_ebbs/config/` and `outages_2026_03_16.json`.

14 of 20 email-extracted outages had no matching scrape notice. Breakdown below.

---

## Priority 1 — New Adapters / Configs Needed

### SoCalGas (Sempra)
- **No config or adapter exists**
- EBB URL: `https://scgenvoy.sempra.com`
- 2 critical force majeure outages with **zero scrape coverage**:
  - Wheeler Ridge Zone FM: 12/27/25 - 08/01/26, **-650 MMcf/d**
  - Topock Sub Zone FM: 01/27/26 - 04/30/26, **-350 MMcf/d**
- Combined impact: **-1,000 MMcf/d** — highest-priority gap

### Viking (ONEOK)
- **No dedicated config** — `standalone.yaml` has `oneok_oktex` but not Viking specifically
- Active system-wide force majeure: 02/26/26 - 03/31/26, capacity impact not quantified
- Determine if Viking posts to the same ONEOK EBB or needs a separate listing URL

---

## Priority 2 — Existing Configs Not Producing Matched Data

These pipelines have backend configs and adapters but their scrape data did not match
any of the email-extracted outages. Investigate whether the adapter is running, returning
data, and whether pipeline name normalization is aligned with the email extraction.

### Transco (williams adapter)
- Config: `williams.yaml` -> `transco`
- 3 unmatched email outages:
  - Station 160 maintenance (03/17 - 03/20), OpCap 1,879 MMcf/d
  - Station 60 maintenance (03/10 - 03/27), OpCap 1,700 Mdt/d (-433)
  - Market & production constraints (03/16)

### Transwestern / TW (energytransfer adapter)
- Config: `energytransfer.yaml` -> `transwestern` (pipe_code: `tw`)
- 1 unmatched email outage:
  - La Palata CS maintenance (03/02 - 04/01), **-250 MMcf/d**

### NEXUS (enbridge adapter)
- Config: `enbridge.yaml` -> `nexus` (pipe_code: `NXUS`)
- 1 unmatched email outage:
  - Colerain/Salineville/Waterville maintenance (03/26 - 05/04), Waterville cut to 892 MMcf/d (-359)

### Northern Border Pipeline (tce adapter)
- Config: `tce.yaml` -> `northern_border` (pipe_code: `NBPL`)
- 1 unmatched email outage:
  - Low inventory watch / cold weather demand (03/16)

### Great Lakes Gas Transmission / GLGT (tcplus adapter)
- Config: `tcplus.yaml` -> `great_lakes` (path: `great%20lakes`)
- 1 unmatched email outage:
  - Emerson Eastbound force majeure (02/10 - 05/01), **-162 MMcf/d**

### Rockies Express / REX (tallgrass adapter)
- Config: `tallgrass.yaml` -> `rockies_express`
- **Note in config: "Tallgrass likely requires Selenium for JS rendering"** — adapter may not be functional
- 1 unmatched email outage:
  - Turney Compressor Station maintenance on Seg 280 (03/17 - 03/20)

### Creole Trail (cheniere adapter)
- Config: `cheniere.yaml` -> `creole_trail` (pipe_code: `ctpl`)
- **Note in config: "React SPA — needs API discovery. May require Selenium or API endpoint"** — adapter may not be functional
- 1 unmatched email outage:
  - Creole Trail compressor maintenance / pigging (03/18 - 03/19), up to **830 MDth/d** impact on Sabine Pass LNG feed gas

### Colorado Interstate Gas / CIG (kindermorgan adapter)
- Config: `kindermorgan.yaml` -> `colorado_interstate_gas` (pipe_code: `CIG`)
- 2 unmatched email outages:
  - Cheyenne South Line 5A pigging on Seg 218 (03/18 - 03/19), **-240 MDth/d**
  - Kit Carson station maintenance on Seg 262 (03/19), **-77 MDth/d**

---

## Out of Scope

### Gassco (Norwegian operator)
- Not a US EBB — European/REMIT jurisdiction
- Only appears via Bloomberg alerts, not scrapeable from US pipeline EBB sites
- 2 email outages:
  - Sleipner gas unavailability (03/13 - ?), -205 MMcf/d
  - Asgard gas unavailability (08/15 - ?), -247 MMcf/d

---

## Debugging Checklist for Priority 2 Items

For each pipeline listed under Priority 2:

1. **Is the adapter actually running?** Check scheduler / flow logs for the source family
2. **Is the scraper returning notices?** Check raw scrape output or DB for recent records
3. **Pipeline name normalization:** Verify that the scrape `pipeline_name` matches what the
   gap coverage matcher expects (e.g., `transco` vs `Transco` vs `transcontinental`)
4. **Notice type alignment:** Confirm `notice_category` from scrape maps to `outage_type`
   from email extraction (e.g., `maintenance` vs `capacity_reduction`)
5. **JS-rendered sites (REX, Cheniere):** Confirm Selenium/headless browser is available
   in the runtime environment, or identify API endpoints to bypass the SPA

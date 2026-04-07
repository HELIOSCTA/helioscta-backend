# Gas EBBs — Status & Next Steps (Updated Mar 17, 2026)

> Context: Refactor is DONE (15 adapters, 165+ pipelines, YAML configs, Prefect flows).
> Current focus: **Phases 1–3 DONE. Next: validate dashboard, tune remaining extraction gaps, integrate impact analysis into scheduler.**

---

## Completed

- [x] Abstract base class `EBBScraper` + factory + adapter registry (`base_scraper.py`)
- [x] 15 concrete adapters in `adapters/` (PipeRiv, Enbridge, KM, Williams, ET, TCE, TCPlus, Quorum, BHEGTS, NNG, DT Midstream, GasNom, Tallgrass, Cheniere, Standalone)
- [x] 15 YAML configs in `config/` (~165 pipelines)
- [x] Notice classifier — 6 categories + other (`notice_classifier.py`)
- [x] Shared utils (`ebb_utils.py`)
- [x] CLI runner (`runs.py` — `--list`, numbered, `all`, parallel by family)
- [x] Prefect flows (`flows.py` — ~168 flows + master `gas_ebb_all`)
- [x] DB tables: `gas_ebbs.notices`, `gas_ebbs.notice_snapshots`, `gas_ebbs.notice_details`, `gas_ebbs.planned_outages`, `gas_ebbs.outage_impacts`, `gas_reference.pipeline_regions`
- [x] Windows Task Scheduler (`schedulers/.../gas_ebbs.ps1` — hourly)
- [x] Frontend dashboard (`GasEbbDashboard.tsx` + API route `gas-ebbs/route.ts`)

---

## Phase 1: Verify & Harden Scrapers ✓

### Completed (Mar 16)

- [x] **Live-test all adapters** — initial run: 97/135 passed, 38 failed
- [x] **GasNom fix** — config had double `/ip/ip/` in URL; adapter now uses `notices.cfm?type=1|2` for crit/non-crit
- [x] **TCE fix** — `_pull()` fallback was re-requesting the same 404 API URL; now falls back to `/MobileInfoPost.aspx`
- [x] **Williams fix** — adapter now uses JSF endpoint directly (`notice_list.jsf?buid={BUID}`) instead of iframe pages
- [x] **Standalone triage** — disabled 10 dead pipelines (DNS fail, 403, 404)
- [x] **Added `disabled` flag support** to `discover_all_pipelines()` — skips `disabled: true` in YAML
- [x] **Run full batch scrape** — upserts verified to `gas_ebbs.notices` and `gas_ebbs.notice_snapshots`
- [x] **TCE adapter rewritten** — jqGrid JSON endpoints, 11/11 passing, 476 notices
- [x] **Tallgrass** — blocked by Incapsula WAF, all 4 disabled
- [x] **Disabled dead pipelines** — ET trunkline_lng, DCP (2), Florida Southeast, MountainWest (2), Enable Midstream (2)
- [x] **Threading fix** — `main()` now uses `PipelineLogger(...)` directly instead of global `init_logging()` singleton (was causing Windows file lock errors in parallel mode)

---

## Phase 1.5: Stabilize & Validate ✓

### 1. Data Quality Audit ✓
- [x] 7,286 notices audited. 100% date parse rate. 658 reclassified. No duplicates.

### 2. Classifier Tuning ✓
- [x] 6 categories + other. "other" dropped 60.7% → 51.7%.

### 3. Failure Monitoring ✓
- [x] `monitor.py` — HEALTHY/FLAKY/DEGRADED/DEAD classification + Slack alerts
- [x] **Scraper health dashboard** — added to frontend as "Scraper Health" tab with pass/fail rates, success %, last run times (queries `logging.pipeline_runs` last 7 days)

### 4. Dashboard Validation ✓
- [x] **Fixed API date parsing** — 100% parse rate across all formats
- [x] **Visual smoke test** — all 10 API queries verified against DB, data flows correctly
  - 7,824 notices, 566,909 snapshots, 1,395 details, 1,395 outages
  - All KPIs, charts, timeline queries return valid data
- [x] **Snapshot chart fix** — changed from raw row count (~100K/day) to `COUNT(DISTINCT ...)` distinct notices per day
- [x] **Fixed `scraped_at` type mismatch** — added `::timestamptz` cast in snapshot query (VARCHAR vs timestamptz comparison)

### 5. Parallel Scraping ✓
- [x] `ThreadPoolExecutor(max_workers=10)` — families concurrent, pipelines sequential within family

### 6. TCE / Tallgrass ✓
- [x] TCE: 11/11, 476 notices. Tallgrass: disabled (Incapsula WAF).

---

## Phase 2: Outage Extraction & Detail Enrichment ✓

### Completed (Mar 16–17)

- [x] **Implemented `_fetch_details()` enrichment** in `base_scraper.py`
  - Filters actionable notices (FM, capacity_reduction, ofo, critical_alert, maintenance)
  - Per-run cap (default 50, configurable via `detail_fetch_limit` in YAML)
  - 0.5s delay between fetches, null byte stripping, detail_text sanitization
- [x] **All 13 adapters have `_parse_detail()` overrides** (was 3, now all active adapters)
  - PipeRiv, Enbridge, KM — div/table text extraction
  - Williams — JSF table parsing
  - Energy Transfer — Quorum div layouts
  - TCE — JSON-first, ASP.NET fallback
  - TCPlus — CSS-class-based divs
  - Quorum — Kendo UI detail pages
  - BHEGTS — PDF detection + Next.js SSR + HTML
  - Northern Natural — Telerik RadGrid ASP.NET
  - DT Midstream — Trellis portal JSON attributes
  - GasNom — ColdFusion table layouts
  - Cheniere — React SPA JSON + `__INITIAL_STATE__`
- [x] **Extract structured outage data** via `outage_extractor.py` (regex module)
  - Major tuning pass based on 1,345 real `detail_text` records from DB
  - Added junk detection (`_is_junk()`) — skips ~65% boilerplate records
  - 12 new date patterns, 4-strategy capacity cascade, named location extraction
  - Refactored into 4 focused helpers: `_extract_capacity()`, `_extract_dates()`, `_extract_locations()`, `_extract_receipt_delivery()`
- [x] **Built `gas_ebbs.notice_details` table** (13 cols)
- [x] **Built `gas_ebbs.planned_outages` table** (14 cols)
  - 1,395 rows across 50+ pipelines (700 upcoming, 131 active, 564 completed)
- [x] **Raw HTML archival** to Azure Blob via `azure_blob_storage_utils.py`
- [x] **YAML config extensions** — all 15 configs updated
- [x] **Non-fatal enrichment** — Phase 4 in `main()` wrapped in try/except

### Extraction Rates (after tuning)

| Field | Before | After | Improvement |
|-------|--------|-------|-------------|
| Dates | 25/1,327 (1.9%) | **714/1,395 (51.2%)** | **+2,756%** |
| Capacity | 2/1,327 (0.15%) | 25/1,395 (1.8%) | +1,150% |
| Locations | 56/1,327 (4.2%) | **216/1,395 (15.5%)** | +286% |

Best families: Enbridge (100% dates), GasNom (100%), Northern Natural (100%).
Gaps: BHEGTS (0% dates), Williams (0% dates/capacity/locations).

### Still needs work

- [ ] **BHEGTS & Williams detail extraction** — 0% date extraction, likely need adapter-specific parsing improvements
- [ ] **Capacity extraction still low** (1.8%) — many notices genuinely don't include capacity figures; consider extracting from reference data instead

---

## Phase 3: Impact Analysis Layer ✓

### Completed (Mar 17)

- [x] **Built `gas_reference.pipeline_regions` table** — 135 pipeline-to-region mappings
  - Covers all 68 active (source_family, pipeline_name) pairs + configured-but-not-scraped
  - Fields: primary_basin, secondary_basins, primary_region, direction, design_capacity_bcfd
  - Basins: Marcellus, Haynesville, Permian, Eagle Ford, Anadarko, Fayetteville, Utica, etc.
  - Directions: production_area, demand_area, bidirectional
- [x] **Built `gas_ebbs.outage_impacts` table** — capacity_loss, capacity_loss_pct, price_impact, impact_summary
- [x] **Created `impact_analyzer.py`** — standalone module (not integrated into scraper flow)
  - `compute_impacts()` — joins planned_outages with pipeline_regions
  - Price impact classification: production_area → bearish, demand_area → bullish, bidirectional → neutral
  - `run_impact_analysis()` — full pipeline with PipelineRunLogger tracking
  - CLI: `python impact_analyzer.py`, `--seed-only`, `--dry-run`
- [x] **New ET pipelines added** to `energytransfer.yaml`: Lake Charles LNG, Rover, SPC (enabled), Gulfstar (disabled/404)

### Still needs work

- [ ] **Run `impact_analyzer.py`** to seed reference data and compute initial impacts
- [ ] **Integrate into scheduler** — add `impact_analyzer.py` to hourly `gas_ebbs.ps1` (after `runs.py all`)
- [ ] **Validate reference data** — spot-check pipeline-to-basin mappings, design capacities
- [ ] **Production impact calculation** — currently only classifies direction; doesn't calculate Bcf/d impact based on pipeline capacity share

---

## Phase 4: Dashboard Enhancements ✓ (partial)

### Completed (Mar 17)

- [x] **3 new KPI cards**: Active Outages, Upcoming Outages, Capacity at Risk (Bcf/d)
- [x] **Tab navigation**: Overview | Planned Outages | Scraper Health
- [x] **Planned Outages tab** — table with status badges (ACTIVE/UPCOMING), expandable rows showing detail_text
  - Columns: Pipeline, Status, Type, Location, Dates, Capacity Loss, Subject
- [x] **Scraper Health tab** — pass/fail rates with green/yellow/red indicators per pipeline (last 7 days)
  - Columns: Status dot, Pipeline, Success Rate %, Successes, Failures, Last Success, Last Run
- [x] **Snapshot chart fixed** — counts distinct notices per day (was raw rows)

### Still needs work

- [ ] **Add pricing impact cards** — show bullish/bearish/neutral breakdown from `outage_impacts` table
- [ ] **Add production impact table** — show capacity at risk by basin/region
- [ ] **Daily automated refresh** via Prefect scheduled flows (currently hourly via Task Scheduler)

---

## Gaps & Risks

| # | Item | Severity | Phase | Notes |
|---|------|----------|-------|-------|
| 1 | ~~No failure monitoring / alerting~~ | ~~High~~ | ~~1.5~~ | DONE: `monitor.py --alert` + scraper health dashboard tab |
| 2 | ~~Data quality unvalidated~~ | ~~High~~ | ~~1.5~~ | DONE: 7,824 notices audited. 100% date parse rate |
| 3 | ~~Dashboard untested with real data~~ | ~~Medium~~ | ~~1.5~~ | DONE: smoke test passed, all 10 API queries verified |
| 4 | ~~Sequential scraping is slow~~ | ~~Medium~~ | ~~1.5~~ | DONE: parallel by family via ThreadPoolExecutor |
| 5 | ~~TCE/Tallgrass return 0 notices~~ | ~~Medium~~ | ~~1.5~~ | DONE: TCE fixed (476 notices). Tallgrass disabled (Incapsula WAF) |
| 6 | Classifier is regex-only | Low | — | Works for common patterns; may misclassify edge cases. Tunable with existing data |
| 7 | ~~Detail enrichment stubbed~~ | ~~Medium~~ | ~~2~~ | DONE: 1,395 detail+outage rows, all 13 adapters have `_parse_detail()` |
| 8 | ~~No impact analysis layer~~ | ~~High~~ | ~~3~~ | DONE: `impact_analyzer.py` + 135 pipeline-region mappings + outage_impacts table |
| 9 | Standalone adapter is best-effort | Medium | — | 11 active pipelines (was 18). 7 more disabled (503/WAF/timeout) |
| 10 | Impact analyzer not yet in scheduler | Medium | 3 | Need to add to hourly `gas_ebbs.ps1` after `runs.py all` |
| 11 | BHEGTS/Williams 0% date extraction | Medium | 2 | Detail pages may use non-standard formats or return minimal text |
| 12 | Reference data unvalidated | Medium | 3 | 135 pipeline-region mappings need analyst spot-check |

---

## Notes

- New Transco Maint (from Cone)
- Sabine Pass flows jumped to 5,182 MMcf/d; however, upcoming pigging maintenance on the Creole Trail Pipeline (scheduled for March 17–18) is expected to temporarily restrict volumes.
- NAESB pipeline directory: https://www.naesb.org/members/urls_of_pipelines.htm (135 pipelines)
- ~~**New ET pipelines found**~~ → DONE: Lake Charles LNG, Rover, SPC added to `energytransfer.yaml`. Gulfstar disabled (404).
- Snapshot history is only ~7 days (since Mar 11). The 120-day chart will fill naturally over time.

---

## References

- Design doc: `TODO/gas-ebbs/GAS_EBB_REFACTOR.md`
- Source inventory: `.SKILLS/gas_ebbs.md`
- Implementation: `backend/src/gas_ebbs/`
- Impact analyzer: `backend/src/gas_ebbs/impact_analyzer.py`
- Scheduler: `schedulers/task_scheduler_azurepostgresql/gas_ebbs/gas_ebbs.ps1`
- Frontend: `frontend/components/data-explorer/GasEbbDashboard.tsx`
- API route: `frontend/app/api/data-explorer/gas-ebbs/route.ts`
- Dashboard mockups: `TODO/gas-ebbs/*.png`

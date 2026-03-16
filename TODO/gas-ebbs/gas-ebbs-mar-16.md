# Gas EBBs — Status & Next Steps (Mar 16, 2026)

> Context: Refactor is DONE (15 adapters, 165+ pipelines, YAML configs, Prefect flows).
> Current focus: **Stabilize & validate (Phase 1.5) → Outage extraction → Impact analysis → Dashboard.**

---

## Completed

- [x] Abstract base class `EBBScraper` + factory + adapter registry (`base_scraper.py`)
- [x] 15 concrete adapters in `adapters/` (PipeRiv, Enbridge, KM, Williams, ET, TCE, TCPlus, Quorum, BHEGTS, NNG, DT Midstream, GasNom, Tallgrass, Cheniere, Standalone)
- [x] 15 YAML configs in `config/` (~165 pipelines)
- [x] Notice classifier — 5 categories: force_majeure, ofo, maintenance, capacity_reduction, critical_alert, other (`notice_classifier.py`)
- [x] Shared utils (`ebb_utils.py`)
- [x] CLI runner (`runs.py` — `--list`, numbered, `all`)
- [x] Prefect flows (`flows.py` — ~168 flows + master `gas_ebb_all`)
- [x] DB tables: `gas_ebbs.notices`, `gas_ebbs.notice_snapshots`
- [x] Windows Task Scheduler (`schedulers/.../gas_ebbs.ps1` — hourly)
- [x] Frontend dashboard (`GasEbbDashboard.tsx` + API route `gas-ebbs/route.ts`)

---

## Phase 1: Verify & Harden Scrapers

### Completed (Mar 16)

- [x] **Live-test all adapters** — initial run: 97/135 passed, 38 failed
- [x] **GasNom fix** — config had double `/ip/ip/` in URL; adapter now uses `notices.cfm?type=1|2` for crit/non-crit
  - All 6 GasNom pipelines now returning data (46 notices total)
- [x] **TCE fix** — `_pull()` fallback was re-requesting the same 404 API URL; now falls back to `/MobileInfoPost.aspx`
  - All 11 TCE pipelines PASS (0 notices — see "Still needs work" below)
- [x] **Williams fix** — adapter now uses JSF endpoint directly (`notice_list.jsf?buid={BUID}`) instead of iframe pages
  - Transco: 2,134 notices, Gulfstream: 146 notices
  - Northwest/Discovery: disabled (not on JSF system, may be decommissioned)
- [x] **Standalone triage** — disabled 10 dead pipelines (DNS fail, 403, 404)
  - Kept 503/timeout pipelines enabled (may be intermittent)
- [x] **Added `disabled` flag support** to `discover_all_pipelines()` — skips `disabled: true` in YAML
- [x] **Run full batch scrape** — upserts verified to `gas_ebbs.notices` and `gas_ebbs.notice_snapshots`

### Still needs work

- [ ] **TCE adapter** — all 11 pipelines return 0 notices. The `tceconnects.com/infopost` site is a jqGrid SPA; the `ebb.tceconnects.com/app/` is Angular behind auth. Need Selenium or authenticated API discovery.
- [ ] **Tallgrass adapter** — all 4 PASS with 0 notices. May need Selenium/Playwright for JS rendering.
- [ ] **Energy Transfer trunkline_lng** — timeout on `tlngmessenger.energytransfer.com` (other 8 ET pipelines all pass)
- [ ] **Standalone 503s** — DCP Midstream (2), Florida Southeast (1), MountainWest (2) returning 503. May recover or may need URL updates.
- [ ] **Standalone timeouts** — Enable Midstream (2) timing out on HTTP. May need HTTPS or URL update.
- [ ] **Scheduler frequency** — design doc says 15-min; scheduler runs hourly. Decide which is correct and align

---

## Phase 1.5: Stabilize & Validate

> Bridge between "scrapers work" and "extract structured data". High value, moderate effort.

### 1. Data Quality Audit ✓
- [x] **Query classification breakdown** — 7,276 notices. Before tuning: 60.7% "other", 20.5% capacity_reduction, 12.6% maintenance, 5.4% ofo, 0.7% FM, 0.1% critical_alert
- [x] **Identified reclassifiable patterns** — "Market and Production Constraints" (341), weather alerts (38), standalone outage (90), operations advisories (82), unauthorized receipts/hourly takes (25)
- [x] **Remaining "other" breakdown** — timely cycle volumes (~1,462), billing (121), confirmations (136), regulatory (76), IT/admin (96) — genuinely informational
- [x] **No duplicates found** — PK constraint (`source_family, pipeline_name, notice_identifier`) is enforced
- [x] **Freshness check** — all 7 active source families scraped within last hour; northern_natural data is stale (newest posted Sep 2024) but scraper is running
- [x] **Missing fields** — `end_datetime` empty for: bhegts (100%), williams (75%), piperiv (33%), gasnom (78%). Open-ended notices use 14-day fallback heuristic
- [x] **Fixed API date parsing** — was only parsing 4 formats (62% coverage). Added ISO 8601 (bhegts), `Mon DD, YYYY` (gasnom), `Mon DD YYYY` (northern_natural), `MM/DD/YYYY HH:MM:SS TZ` (williams). Now **100% parse rate** across all 7,286 notices
- [x] **Validated active/upcoming heuristics** — 575 active, 39 upcoming, 0 unknown timing (was 2,746 unknown before date fix), 248 deactivated

### 2. Classifier Tuning ✓
- [x] **Improved `notice_classifier.py`** — 6 categories + other (was 5 + other)
  - Expanded `ofo`: +unauthorized receipts, hourly takes advisory
  - Expanded `critical_alert`: +weather alert, high wind, winter weather, cold weather, ice storm
  - Expanded `capacity_reduction`: +market/production constraints, limited flexibility
  - NEW `operations_advisory` (sev 3): operations advisory, system operating conditions, line pack, location performance
  - Expanded `maintenance`: +standalone "outage", "pigging"
  - 658 notices reclassified, "other" dropped 60.7% → 51.7%
- [x] **Updated DB** — 658 rows in `gas_ebbs.notices`, 20,089 rows in `gas_ebbs.notice_snapshots`
- [x] **Final breakdown**: other 51.7%, capacity_reduction 25.3%, maintenance 13.8%, ofo 5.7%, operations_advisory 2.1%, FM 0.7%, critical_alert 0.6%

### 3. Failure Monitoring ✓
- [x] **Built `monitor.py`** — queries `logging.pipeline_runs`, classifies pipelines as HEALTHY/FLAKY/DEGRADED/DEAD
  - Usage: `python monitor.py`, `--failures` (failures only), `--hours 6` (custom window)
  - Current state (24h): 70 healthy, 21 flaky, 16 degraded, 18 dead
  - 10 of 18 "dead" are disabled pipelines (pre-fix runs still in window); 8 are infra issues (503/timeout)
- [ ] **Add scheduled alert delivery** — Slack webhook or email when a previously-healthy pipeline goes DEAD/DEGRADED
- [ ] **Add scraper health dashboard** — simple view of pass/fail rates by source family over last 7 days

### 4. Dashboard Validation ✓
- [x] **Fixed API date parsing** — `parseTimestampSql()` only handled 4 date formats (62% of notices). Added 4 new formats:
  - ISO 8601 with fractional seconds (bhegts): `2025-12-04T15:15:22.632`
  - Month name with comma (gasnom): `Dec 1, 2025 08:59:45 AM`
  - Month name without comma (northern_natural): `Aug 13 2024 2:00 PM`
  - 24h with timezone abbreviation (williams): `01/01/2024 08:20:43 CST`
  - **100% parse rate** (was 62.2%) → 575 active, 39 upcoming, 0 unknown (was 2,746 unknown)
- [ ] **Visual smoke test** — open dashboard in browser and verify KPIs/charts render correctly with full data
- [ ] **Check `notice_snapshots` timeline chart** — does the 120-day line chart show meaningful scrape-over-scrape history?

### 5. Parallel Scraping ✓
- [x] **`runs.py` now runs families concurrently** via `ThreadPoolExecutor(max_workers=10)`
  - Pipelines within same source family run sequentially (rate-limit courtesy)
  - Different families run in parallel (e.g. PipeRiv, Enbridge, KM all at once)
  - `--sequential` flag to force old behavior
  - Thread-safe output with `_print_lock`, atomic counter with `_counter_lock`

### 6. TCE / Tallgrass ✓
- [x] **TCE adapter rewritten** — discovered jqGrid JSON endpoints behind the SPA
  - Critical: `webmethods/SSRS_ListCriticalNotices.aspx?assetid={id}&page=1&rows=500`
  - Non-critical: `webmethods/SSRS_ListNonCriticalNotices.aspx?assetid={id}&page=1&rows=500`
  - Added `assetid` to all 11 pipelines in `tce.yaml`
  - **11/11 passing, 476 notices upserted** (was 0 across all 11)
  - Note: the endpoint without `page`/`rows` params returns 500 (server overflow bug)
- [x] **Tallgrass: blocked by Incapsula WAF** — entire site behind Imperva bot challenge
  - All 4 pipelines disabled with `disabled_reason`
  - Requires Playwright with browser automation to solve challenge (not installed)
  - Revisit if Playwright is added or if Tallgrass changes EBB platform

---

## Phase 2: Outage Extraction & Detail Enrichment

- [ ] **Implement `_fetch_detail()` enrichment** — base class has the stub, adapters need detail-page parsing
  - Extract: full notice text, gas_day_start/end, capacity values, affected receipt/delivery points
  - Cap detail fetches per run (e.g., 100) to avoid rate-limiting
- [ ] **Extract structured outage data** from notice subjects/detail pages
  - Location, capacity reduction (Bcf/d), start/end dates
- [ ] **Build `gas_ebbs.planned_outages` table**
  - Columns: pipeline, location, sub_region, start_date, end_date, capacity_loss_bcfd, status (ACTIVE/UPCOMING/COMPLETED)
- [ ] **Raw HTML retention** — store listing + detail HTML in Azure Blob for retroactive debugging
  - Path: `gas-ebbs/{source_family}/{pipeline}/{date}/{timestamp}_listing.html`

---

## Phase 3: Impact Analysis Layer

- [ ] **Map pipelines to production sub-regions** (Haynesville, Eagle Ford, Marcellus, Permian, etc.)
  - Needs: `gas_reference.pipeline_segments` table (pipeline → segments → capacity → basin)
  - Data source TBD: FERC Form 567, commercial data, or analyst-maintained reference table
- [ ] **Calculate production impact** (Bcf/d) based on pipeline share of takeaway capacity + alternate route availability
- [ ] **Classify price direction**: Bearish (production-area takeaway constraint) vs Bullish (demand-area delivery constraint)
- [ ] **Build `gas_ebbs.outage_impacts` table** — capacity_loss, prod_impact, price_impact columns

---

## Phase 4: Dashboard Enhancements

- [ ] **Add pricing impact cards** to frontend dashboard (currently has KPIs, charts, timeline but no pricing)
- [ ] **Add production impact table** to dashboard
- [ ] **Daily automated refresh** via Prefect scheduled flows (currently hourly via Task Scheduler)

---

## Gaps & Risks

| # | Item | Severity | Phase | Notes |
|---|------|----------|-------|-------|
| 1 | No failure monitoring / alerting | **High** | 1.5 | `PipelineRunLogger` writes to DB but nothing watches it — silent overnight failures |
| 2 | Data quality unvalidated | **High** | 1.5 | ~7K notices in DB but classification breakdown, dedup, and active heuristics untested |
| 3 | Dashboard untested with real data | Medium | 1.5 | 7 SQL queries, KPIs, timeline exist but not validated against actual notice corpus |
| 4 | Sequential scraping is slow | Medium | 1.5 | 100+ pipelines × 30s timeout = 50+ min worst case in hourly window |
| 5 | ~~TCE/Tallgrass return 0 notices~~ | ~~Medium~~ | ~~1.5~~ | TCE fixed (476 notices). Tallgrass blocked by Incapsula WAF (4 pipelines disabled) |
| 6 | Classifier is regex-only | Medium | 1.5 | Works for common patterns; may misclassify edge cases. Tunable with existing data |
| 7 | Detail enrichment (`_fetch_detail`) stubbed | Medium | 2 | Most adapters only scrape listing pages — detail content not captured |
| 8 | No impact analysis layer | High (for dashboard) | 3 | No pipeline-to-region mapping, capacity data, or pricing impact |
| 9 | Standalone adapter is best-effort | Medium | — | 18 active pipelines on heuristic parsing — fragile |

---

## Notes

- New Transco Maint (from Cone)
- Sabine Pass flows jumped to 5,182 MMcf/d; however, upcoming pigging maintenance on the Creole Trail Pipeline (scheduled for March 17–18) is expected to temporarily restrict volumes.
- NAESB pipeline directory: https://www.naesb.org/members/urls_of_pipelines.htm (135 pipelines)

---

## References

- Design doc: `TODO/gas-ebbs/GAS_EBB_REFACTOR.md`
- Source inventory: `.SKILLS/gas_ebbs.md`
- Implementation: `backend/src/gas_ebbs/`
- Scheduler: `schedulers/task_scheduler_azurepostgresql/gas_ebbs/gas_ebbs.ps1`
- Frontend: `frontend/components/data-explorer/GasEbbDashboard.tsx`
- API route: `frontend/app/api/data-explorer/gas-ebbs/route.ts`
- Dashboard mockups: `TODO/gas-ebbs/*.png`

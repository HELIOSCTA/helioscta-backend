# Gas EBBs — Status & Next Steps (Mar 16, 2026)

> Context: Refactor is DONE (15 adapters, 165+ pipelines, YAML configs, Prefect flows).
> Current focus: **Harden scrapers → Outage extraction → Impact analysis → Dashboard.**

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

## Phase 2: Notice Classification & Outage Extraction

- [ ] **Improve `notice_classifier.py`** — better separation of planned outages vs OFOs vs force majeures vs routine
  - Current: regex-only, no feedback loop or override mechanism
  - Consider: YAML-driven rules, detail-page override (if detail says "Force Majeure", upgrade classification)
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

| # | Item | Severity | Notes |
|---|------|----------|-------|
| 1 | Adapters not yet live-tested end-to-end | **High** | Everything downstream depends on stable scrapes |
| 2 | Detail enrichment (`_fetch_detail`) is stubbed | Medium | Most adapters only scrape listing pages — detail content not captured |
| 3 | No impact analysis layer | High (for dashboard goal) | No pipeline-to-region mapping, capacity data, or pricing impact |
| 4 | Tallgrass may need Selenium | Medium | Comment in code; plain HTML may return empty |
| 5 | Standalone adapter is best-effort | Medium | 30+ pipelines on heuristic parsing — fragile |
| 6 | `scrape_runs` table from design doc | Low | `PipelineRunLogger` may serve this role; explicit table not created |
| 7 | Classifier is regex-only | Low | Works for common patterns; may misclassify edge cases |

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

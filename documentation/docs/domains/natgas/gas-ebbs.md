# Gas EBBs (Pipeline Critical Notices)

Scrapes critical and non-critical notices from 123 NAESB pipeline Electronic Bulletin Boards (EBBs) across 15 source families. Data is upserted into Azure PostgreSQL and powers the Gas EBB dashboard.

## Architecture

- **Pattern:** Abstract base class (`EBBScraper`) + source-family adapters + YAML configs
- **Code:** `backend/src/gas_ebbs/`
- **DB Schema:** `gas_ebbs` (tables: `notices`, `notice_snapshots`)
- **Scheduler:** Hourly via Windows Task Scheduler (`schedulers/.../gas_ebbs/gas_ebbs.ps1`)
- **Dashboard:** `frontend/components/data-explorer/GasEbbDashboard.tsx`

## Source Families (15)

| Family | Pipelines | Adapter |
|--------|-----------|---------|
| PipeRiv | 14 | HTML table |
| Enbridge | 18 | InfoPost HTML |
| Kinder Morgan | 19 | Infragistics WebDataGrid |
| Williams | 3 active | JSF endpoint (BUID-based) |
| Energy Transfer | 9 | Quorum platform |
| TC Energy | 11 | jqGrid SPA (needs work) |
| TC Plus | 4 | CSS class-based HTML |
| Quorum | 7 | Kendo Grid + JSON API |
| BHEGTS | 3 | Next.js SSR |
| Northern Natural | 1 | Telerik RadGrid |
| DT Midstream | 3 | Trellis Energy data attributes |
| GasNom | 6 | HTML table (notices.cfm) |
| Tallgrass | 4 | HTML table (may need Selenium) |
| Cheniere | 3 | React SPA + JSON API |
| Standalone | 18 active | Generic heuristic |

## Notice Classification

5 categories (regex-based, in `notice_classifier.py`):
1. **force_majeure** (severity 5)
2. **ofo** (severity 4)
3. **maintenance** (severity 3)
4. **capacity_reduction** (severity 4)
5. **critical_alert** (severity 4)
6. **other** (severity 1)

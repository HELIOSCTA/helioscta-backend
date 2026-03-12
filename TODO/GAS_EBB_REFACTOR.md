# Gas EBB Scraping Framework — Implementation-Ready Design

---

## Recommendation

**Use a normal base class + source-family adapter pattern.** A Python metaclass is the wrong tool here — the problem is runtime polymorphism (different HTML structures, session strategies, and field mappings across 6 source families), not class-creation-time behavior. A standard abstract base class (`EBBScraper`) with one concrete adapter per source family, configured via YAML, is simpler, testable, and maintainable.

**Orchestration: Scheduled** (score: 31) over Event-driven (21) or Hybrid (26). EBB notice pages are pull-only HTTP endpoints with no push/webhook capability. Publish times are unpredictable but notices persist for days/weeks, so a 15-minute polling interval meets any reasonable SLA without event triggers.

---

## Decision Matrix

### Orchestration Scoring (Section 8 Rubric)

| Criterion | Scheduled | Event-driven | Hybrid |
|---|---|---|---|
| Freshness/latency fit | 4 — 15 min poll ≤ SLA | 2 — no push mechanism exists | 3 |
| Publish-time predictability | 5 — poll works regardless | 2 — can't trigger on publish | 3 |
| Reliability and retry | 5 — cron + retry is simple | 2 — no event source to retry | 4 |
| Backfill/recovery | 5 — re-scrape window trivially | 3 | 4 |
| Operational complexity | 5 — one cron entry per family | 3 | 3 |
| Cost/API-rate-limit safety | 4 — 20 scrapes per 15 min | 5 — no wasted calls | 4 |
| Observability/on-call burden | 3 — poll failures are obvious | 4 | 5 |
| **Total** | **31** | **21** | **26** |

**Hard rule match:** Upstream is pull-only with no event mechanism → **Scheduled**.

### Architecture Pattern Scoring

| Criterion | Metaclass | Base class + Adapters | Per-pipeline scripts (status quo) |
|---|---|---|---|
| Code reuse | 3 | 5 | 1 |
| Readability | 1 | 5 | 4 |
| Testability | 2 | 5 | 3 |
| Extensibility | 3 | 5 | 2 |
| Debugging ease | 1 | 5 | 5 |

**Winner: Base class + Adapters.**

---

## Existing Patterns

### What the 20 legacy scrapers share (from `.refactor/helioscta_api_scrapes_gas_ebbs/`)

1. **3-function pipeline:** `fetch_page()` → `parse_critical_notices()` → `_upsert()`
2. **DataFrame-based upsert** via `azure_postgresql.upsert_to_azure_postgresql()`
3. **Primary key:** `notice_identifier` only
4. **All datetimes stored as VARCHAR** — no parsing, no timezone handling
5. **Full-refresh pattern:** every run upserts all visible notices
6. **No detail-page fetching** — listing page only
7. **No classification or enrichment**
8. **Per-pipeline table:** `gas_ebbs.<pipeline>_critical_notices`
9. **Slack-on-error notification** (to be replaced with `PipelineRunLogger`)

### Source-family-specific differences

| Family | Pipelines | HTTP | Parser | Special |
|---|---|---|---|---|
| PipeRiv | 13 | GET | Simple `<table>` | None |
| Kinder Morgan | 3 (TGP, NGPL, + 1) | GET | Nested Infragistics `DGNotices` grid | Find innermost table by row count |
| Williams 1Line | 1 (Transco) | Session GET×2 | JSF `ui-datatable-scrollable-body` | Session bootstrap + delvid extraction |
| Enbridge InfoPost | 1 (Texas Eastern) | GET | HTML table | Enbridge-specific field names |
| Tallgrass | 1 (REX) | Selenium | ASP.NET `GridView` | Incapsula bot protection, 35s wait |
| GasNom | 1 (Southern Pines) | GET | Simple `<table>` | `hdr`/`datahdr` class detection |

### What the Synmax reference adds (`.refactor/synmax/pipeline_notices_with_analysis.py`)

1. **Classification rules:** 5 ordered regex categories (Force Majeure → OFO → Maintenance → Capacity Reduction → Critical Alert → Other)
2. **Detail-page enrichment:** Extract `posted_time`, `gas_day_start/end`, `notice_status`, `detail_notice_type`, `source_link`
3. **New vs existing comparison:** Set-based `notice_id` diff against previous DataFrame
4. **Two format handlers:** TC Energy format vs Kinder Morgan format for detail pages

### Limitations of current per-pipeline table design

1. **No cross-pipeline queries** without UNION ALL across 20+ tables
2. **No revision tracking** — upsert overwrites, losing prior state
3. **No "notice disappeared" detection** — only current notices are upserted
4. **Datetimes as strings** — can't do range queries or timezone math
5. **No classification** — consumers must regex-parse `subject` themselves
6. **No detail-page data** — only listing-level fields
7. **No raw HTML retention** — can't debug parsing failures retroactively

---

## Proposed Folder Structure

```
backend/src/gas_ebbs/
├── __init__.py
├── runs.py                          # Manual runner (--list, all, numbered)
├── flows.py                         # Prefect flow wrappers
├── base_scraper.py                  # EBBScraper abstract base class
├── notice_classifier.py             # Classification rules engine
├── notice_enricher.py               # Detail-page enrichment logic
├── ebb_utils.py                     # Shared helpers (datetime parsing, HTML cleaning)
├── config/
│   ├── piperiv.yaml                 # 13 pipeline configs
│   ├── kindermorgan.yaml            # 3 pipeline configs
│   ├── williams.yaml                # transco config
│   ├── enbridge.yaml                # texas_eastern config
│   ├── tallgrass.yaml               # rex config
│   └── gasnom.yaml                  # southern_pines config
├── adapters/
│   ├── __init__.py
│   ├── piperiv_adapter.py           # PipeRiv HTML table adapter
│   ├── kindermorgan_adapter.py      # Kinder Morgan Infragistics adapter
│   ├── williams_adapter.py          # Williams 1Line JSF adapter (session + delvid)
│   ├── enbridge_adapter.py          # Enbridge InfoPost adapter
│   ├── tallgrass_adapter.py         # Tallgrass Selenium adapter (Incapsula bypass)
│   └── gasnom_adapter.py            # GasNom simple table adapter
├── sql/
│   ├── create_tables.sql            # DDL for all tables
│   ├── migrate_legacy.sql           # Migration from per-pipeline tables
│   └── views.sql                    # Dashboard-ready views
└── logs/                            # Auto-created log directory
```

---

## Proposed Architecture

### Class Hierarchy

```python
# base_scraper.py
from abc import ABC, abstractmethod

class EBBScraper(ABC):
    """Base class for all EBB source-family scrapers."""

    def __init__(self, config: dict):
        self.pipeline_name: str = config["pipeline_name"]
        self.source_family: str = config["source_family"]
        self.listing_url: str = config["listing_url"]
        self.detail_url_template: str | None = config.get("detail_url_template")
        self.field_map: dict = config["field_map"]
        self.datetime_formats: list[str] = config.get("datetime_formats", [])

    # --- Standard pipeline functions per repo convention ---

    def _pull(self) -> str:
        """Fetch listing page HTML. Override for session/Selenium families."""
        response = requests.get(self.listing_url, headers=self._headers(), timeout=30)
        response.raise_for_status()
        return response.text

    @abstractmethod
    def _parse_listing(self, html: str) -> list[dict]:
        """Parse listing HTML into list of raw notice dicts. Family-specific."""
        ...

    def _fetch_detail(self, notice: dict) -> dict:
        """Fetch and parse detail page for a single notice. Optional override."""
        if not self.detail_url_template or not notice.get("notice_identifier"):
            return {}
        url = self.detail_url_template.format(**notice)
        resp = requests.get(url, headers=self._headers(), timeout=30)
        return self._parse_detail(resp.text)

    def _parse_detail(self, html: str) -> dict:
        """Extract structured fields from detail page. Override per family."""
        return {}

    def _format(self, raw_notices: list[dict]) -> pd.DataFrame:
        """Normalize field names, parse datetimes, add metadata."""
        df = pd.DataFrame(raw_notices)
        df = self._normalize_datetimes(df)
        df["pipeline_name"] = self.pipeline_name
        df["source_family"] = self.source_family
        df["scraped_at"] = datetime.now(timezone.utc)
        return df

    def _classify(self, df: pd.DataFrame) -> pd.DataFrame:
        """Apply classification rules to each notice."""
        classifier = NoticeClassifier()
        df["notice_category"] = df["subject"].apply(classifier.classify)
        df["severity"] = df["notice_category"].map(classifier.severity_map)
        return df

    def _upsert(self, df: pd.DataFrame) -> None:
        """Upsert to canonical notices table + insert raw snapshot."""
        # 1. Upsert to gas_ebbs.notices (canonical)
        azure_postgresql.upsert_to_azure_postgresql(
            schema="gas_ebbs", table_name="notices",
            df=df, primary_key=["source_family", "pipeline_name", "notice_identifier"],
        )
        # 2. Append to gas_ebbs.notice_snapshots (revision history)
        azure_postgresql.upsert_to_azure_postgresql(
            schema="gas_ebbs", table_name="notice_snapshots",
            df=df, primary_key=["source_family", "pipeline_name", "notice_identifier", "scraped_at"],
        )

    def main(self) -> None:
        """Standard orchestration: pull → parse → enrich → format → classify → upsert."""
        run = PipelineRunLogger(
            pipeline_name=f"gas_ebb_{self.pipeline_name}",
            source="gas_ebbs",
            target_table="gas_ebbs.notices",
            operation_type="upsert",
            log_file_path=logger.log_file_path,
        )
        run.start()
        try:
            html = self._pull()
            raw_notices = self._parse_listing(html)
            # Optional detail enrichment
            if self.detail_url_template:
                for notice in raw_notices:
                    detail = self._fetch_detail(notice)
                    notice.update(detail)
            df = self._format(raw_notices)
            df = self._classify(df)
            self._upsert(df)
            self._detect_disappeared(df)
            run.success(rows_processed=len(df))
        except Exception as e:
            run.failure(error=e)
            raise
```

### Adapter Examples

```python
# adapters/piperiv_adapter.py
class PipeRivAdapter(EBBScraper):
    """Handles all 13 PipeRiv pipelines. No overrides needed for _pull()."""

    def _parse_listing(self, html: str) -> list[dict]:
        soup = BeautifulSoup(html, "html.parser")
        table = soup.find("table")
        rows = table.find("tbody").find_all("tr")
        notices = []
        for row in rows:
            cells = row.find_all("td")
            notices.append({
                self.field_map["notice_type"]: clean_text(cells[0]),
                "posted_datetime": clean_text(cells[1]),
                ...  # mapped from YAML field_map
            })
        return notices


# adapters/williams_adapter.py
class WilliamsAdapter(EBBScraper):
    """Handles Transco. Overrides _pull() for session bootstrap."""

    def _pull(self) -> str:
        session = requests.Session()
        session.get(self.config["bootstrap_url"], headers=self._headers(), timeout=30)
        resp = session.get(self.listing_url, headers=self._headers(), timeout=30)
        return resp.text

    def _parse_listing(self, html: str) -> list[dict]:
        soup = BeautifulSoup(html, "html.parser")
        body_div = soup.find("div", class_="ui-datatable-scrollable-body")
        # ... JSF-specific parsing, delvid extraction ...


# adapters/tallgrass_adapter.py
class TallgrassAdapter(EBBScraper):
    """Handles REX. Overrides _pull() for Selenium + Incapsula bypass."""

    def _pull(self) -> str:
        options = Options()
        options.add_argument("--disable-gpu")
        options.add_argument("--no-sandbox")
        # ... Incapsula stealth settings ...
        driver = webdriver.Chrome(options=options)
        driver.get(self.listing_url)
        time.sleep(self.config.get("wait_seconds", 35))
        html = driver.page_source
        driver.quit()
        return html
```

### Factory / Registry

```python
# base_scraper.py (bottom of file)
ADAPTER_REGISTRY: dict[str, type[EBBScraper]] = {
    "piperiv": PipeRivAdapter,
    "kindermorgan": KinderMorganAdapter,
    "williams": WilliamsAdapter,
    "enbridge": EnbridgeAdapter,
    "tallgrass": TallgrassAdapter,
    "gasnom": GasNomAdapter,
}

def create_scraper(config_path: str, pipeline_name: str) -> EBBScraper:
    """Load YAML config and return the correct adapter instance."""
    with open(config_path) as f:
        family_config = yaml.safe_load(f)
    pipeline_config = family_config["pipelines"][pipeline_name]
    pipeline_config["source_family"] = family_config["source_family"]
    pipeline_config["pipeline_name"] = pipeline_name
    adapter_cls = ADAPTER_REGISTRY[family_config["source_family"]]
    return adapter_cls(pipeline_config)
```

---

## YAML Schema

### Sample: `config/piperiv.yaml`

```yaml
source_family: piperiv
base_url: "https://www.piperiv.com"
adapter: piperiv

# Shared defaults for all pipelines in this family
defaults:
  listing_url_template: "{base_url}/ip/{operator_code}/critical-notices"
  detail_url_template: "{base_url}/ip/{operator_code}/notice/{notice_identifier}"
  http_method: GET
  requires_session: false
  requires_selenium: false
  datetime_formats:
    - "%m/%d/%Y %I:%M:%S%p"
    - "%m/%d/%Y %I:%M %p"
    - "%m/%d/%Y"
  field_map:
    0: notice_type
    1: posted_datetime
    2: effective_datetime
    3: end_datetime
    4: notice_identifier
    5: notice_status
    6: subject           # may contain <a> with detail link
    7: response_datetime

pipelines:
  algonquin:
    operator_code: "algonquin"
    schedule_cron: "*/15 * * * *"

  anr:
    operator_code: "anr"

  columbia_gas:
    operator_code: "columbiagas"

  el_paso:
    operator_code: "elpaso"

  florida_gas:
    operator_code: "floridagas"

  gulf_south:
    operator_code: "gulfsouth"

  iroquois:
    operator_code: "iroquois"

  millennium:
    operator_code: "millennium"

  mountain_valley:
    operator_code: "mountainvalley"

  northern_natural:
    operator_code: "northernnatural"

  northwest:
    operator_code: "northwest"

  panhandle_eastern:
    operator_code: "panhandleeastern"

  rover:
    operator_code: "rover"

  southeast_supply:
    operator_code: "southeastsupply"
```

### Sample: `config/williams.yaml`

```yaml
source_family: williams
adapter: williams

defaults:
  requires_session: true
  datetime_formats:
    - "%m/%d/%Y %I:%M:%S %p"

pipelines:
  transco:
    bootstrap_url: "https://www.1line.williams.com/Transco/info-postings/notices/critical-notices.html"
    listing_url: "https://www.1line.williams.com/xhtml/notice_list.jsf?buid=80&type=-1&type2=-1&archive=N&critical_ind=Y&hfSortField=posted_date&hfSortDir=DESC"
    detail_url_template: "https://www.1line.williams.com/1Line/wgp/download?delvid={delvid}&hfNoticeFlag=Y&hfDownloadFlag=false&hfFileName=download.html"
    field_map:
      0: notice_type
      1: posted_datetime
      2: effective_datetime
      3: end_datetime
      4: notice_identifier
      5: subject           # contains delvid in onclick
      6: response_datetime
      7: _download_link    # secondary delvid source
    extra_fields:
      - delvid             # extracted from onclick/href
```

### Sample: `config/tallgrass.yaml`

```yaml
source_family: tallgrass
adapter: tallgrass

defaults:
  requires_selenium: true
  wait_seconds: 35
  datetime_formats:
    - "%m/%d/%Y %I:%M:%S %p"

pipelines:
  rex:
    listing_url: "https://pipeline.tallgrassenergylp.com/Pages/Notices.aspx?pipeline=501&type=CRIT"
    table_selector: "table#mainContent_GridView1"
    field_map:
      0: notice_type
      1: notice_subtype
      2: posted_datetime
      3: effective_datetime
      4: end_datetime
      5: notice_identifier
      6: subject
```

---

## Data Acquisition Strategy

### Phase 1: Listing Page

Every adapter implements `_parse_listing()` to extract rows from the source's notice list page. The base class handles HTTP acquisition; adapters override only when the transport differs (session for Williams, Selenium for Tallgrass).

### Phase 2: Detail Page (new capability)

After listing rows are collected, the base class iterates and calls `_fetch_detail()` for each notice. This is where the Synmax enrichment pattern applies:

1. Fetch detail URL (constructed from YAML template + notice fields)
2. Parse structured fields: `gas_day_start`, `gas_day_end`, `notice_status`, `detail_notice_type`
3. Handle two format variants (TC Energy vs Kinder Morgan) via `_parse_detail()` override
4. Cap detail fetches per run (default 100) to avoid runaway requests
5. Store raw detail HTML in blob storage for retroactive debugging

### Phase 3: Raw HTML Retention

- Listing page HTML → Azure Blob: `gas-ebbs/{source_family}/{pipeline}/{date}/{timestamp}_listing.html`
- Detail page HTML → Azure Blob: `gas-ebbs/{source_family}/{pipeline}/{date}/{notice_id}_detail.html`
- Blob references stored in `gas_ebbs.notice_snapshots.raw_listing_blob_path` and `raw_detail_blob_path`

### Fetch Strategy by Family

| Family | Listing | Detail | Notes |
|---|---|---|---|
| PipeRiv | GET → parse table | GET detail URL | Straightforward |
| Kinder Morgan | GET → find DGNotices grid | GET NoticeDetail.aspx | Nested table navigation |
| Williams | Session GET×2 → parse JSF | GET via delvid URL | Must extract delvid first |
| Enbridge | GET → parse table | GET detail URL | Enbridge-specific fields |
| Tallgrass | Selenium → wait 35s → parse GridView | POST (postback) or skip | Incapsula-protected; detail via JS postback may require Selenium too |
| GasNom | GET → parse table | GET detail URL | Simple |

---

## Notice Normalization and Enrichment

### Classification Engine (`notice_classifier.py`)

Adapted from Synmax `CLASSIFICATION_RULES` with ordered regex matching:

```python
CLASSIFICATION_RULES = [
    ("force_majeure",      r"force\s*majeure|fmj|fm\s*(event|declaration|notice)", 5),
    ("ofo",                r"ofo|operational\s*flow\s*order|critical\s*day|overage\s*alert|imbalance\s*order", 4),
    ("maintenance",        r"maintenance|planned.*outage|unplanned.*outage|repair|compressor.*work|pig\s*run|hydro\s*test|inspection", 3),
    ("capacity_reduction", r"capacity\s*(reduction|constraint)|restriction|curtailment|reduced\s*capacity|pack\s*declaration", 4),
    ("critical_alert",     r"critical|operational\s*alert|emergency|leak|rupture|incident|interruption|shut.in|blow.down", 4),
    ("other",              r".*", 1),
]
# Tuple: (category, regex_pattern, default_severity 1-5)
```

**Override rule:** If detail page explicitly says "Force Majeure" in `detail_notice_type`, upgrade classification regardless of subject-line match (per Synmax pattern).

### Datetime Normalization

All datetime strings parsed to `TIMESTAMP WITH TIME ZONE` using the family's configured `datetime_formats` list, with fallback to `dateutil.parser.parse()`. Timezone defaults to pipeline's prevailing timezone (from YAML) or UTC.

### Field Normalization

| Raw field | Canonical column | Type |
|---|---|---|
| `notice_type` | `notice_type` | VARCHAR |
| `notice_subtype` | `notice_subtype` | VARCHAR (nullable) |
| `posted_datetime` | `posted_at` | TIMESTAMPTZ |
| `effective_datetime` | `effective_at` | TIMESTAMPTZ |
| `end_datetime` | `end_at` | TIMESTAMPTZ |
| `notice_identifier` | `notice_identifier` | VARCHAR |
| `notice_status` | `notice_status` | VARCHAR (nullable) |
| `subject` | `subject` | TEXT |
| `response_datetime` | `response_at` | TIMESTAMPTZ (nullable) |
| `detail_url` | `detail_url` | TEXT |
| — | `notice_category` | VARCHAR (classified) |
| — | `severity` | SMALLINT (1-5) |
| — | `pipeline_name` | VARCHAR |
| — | `source_family` | VARCHAR |
| — | `gas_day_start` | DATE (nullable, from detail) |
| — | `gas_day_end` | DATE (nullable, from detail) |
| — | `scraped_at` | TIMESTAMPTZ |

---

## PostgreSQL Storage Model

### Schema: `gas_ebbs`

#### Table 1: `gas_ebbs.notices` — Canonical current state

```sql
CREATE TABLE gas_ebbs.notices (
    source_family       VARCHAR(50)   NOT NULL,
    pipeline_name       VARCHAR(100)  NOT NULL,
    notice_identifier   VARCHAR(100)  NOT NULL,

    -- Listing fields
    notice_type         VARCHAR(200),
    notice_subtype      VARCHAR(200),
    subject             TEXT,
    notice_status       VARCHAR(100),
    posted_at           TIMESTAMPTZ,
    effective_at        TIMESTAMPTZ,
    end_at              TIMESTAMPTZ,
    response_at         TIMESTAMPTZ,
    detail_url          TEXT,

    -- Enrichment fields (from detail page + classifier)
    notice_category     VARCHAR(50),     -- force_majeure, ofo, maintenance, capacity_reduction, critical_alert, other
    severity            SMALLINT,        -- 1-5
    gas_day_start       DATE,
    gas_day_end         DATE,
    detail_notice_type  VARCHAR(200),
    source_link         TEXT,            -- original pipeline operator URL

    -- Lifecycle
    is_active           BOOLEAN DEFAULT TRUE,
    first_seen_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    disappeared_at      TIMESTAMPTZ,     -- set when notice drops off listing
    scraped_at          TIMESTAMPTZ NOT NULL,

    -- Blob references
    raw_listing_blob    TEXT,
    raw_detail_blob     TEXT,

    PRIMARY KEY (source_family, pipeline_name, notice_identifier)
);

CREATE INDEX idx_notices_active ON gas_ebbs.notices (is_active) WHERE is_active = TRUE;
CREATE INDEX idx_notices_category ON gas_ebbs.notices (notice_category);
CREATE INDEX idx_notices_pipeline ON gas_ebbs.notices (pipeline_name);
CREATE INDEX idx_notices_posted ON gas_ebbs.notices (posted_at DESC);
CREATE INDEX idx_notices_effective ON gas_ebbs.notices (effective_at, end_at);
```

#### Table 2: `gas_ebbs.notice_snapshots` — Revision history

```sql
CREATE TABLE gas_ebbs.notice_snapshots (
    source_family       VARCHAR(50)   NOT NULL,
    pipeline_name       VARCHAR(100)  NOT NULL,
    notice_identifier   VARCHAR(100)  NOT NULL,
    scraped_at          TIMESTAMPTZ   NOT NULL,

    -- Full snapshot of all fields at scrape time
    notice_type         VARCHAR(200),
    notice_subtype      VARCHAR(200),
    subject             TEXT,
    notice_status       VARCHAR(100),
    posted_at           TIMESTAMPTZ,
    effective_at        TIMESTAMPTZ,
    end_at              TIMESTAMPTZ,
    response_at         TIMESTAMPTZ,
    detail_url          TEXT,
    notice_category     VARCHAR(50),
    severity            SMALLINT,
    gas_day_start       DATE,
    gas_day_end         DATE,

    raw_listing_blob    TEXT,
    raw_detail_blob     TEXT,

    PRIMARY KEY (source_family, pipeline_name, notice_identifier, scraped_at)
);
```

#### Table 3: `gas_ebbs.scrape_runs` — Operational metadata

```sql
CREATE TABLE gas_ebbs.scrape_runs (
    run_id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    source_family       VARCHAR(50)  NOT NULL,
    pipeline_name       VARCHAR(100) NOT NULL,
    started_at          TIMESTAMPTZ  NOT NULL,
    completed_at        TIMESTAMPTZ,
    status              VARCHAR(20),      -- success, failure, partial
    notices_found       INTEGER,
    notices_new         INTEGER,
    notices_updated     INTEGER,
    notices_disappeared INTEGER,
    error_message       TEXT
);
```

### Dedupe / Primary Key Strategy

**Composite PK:** `(source_family, pipeline_name, notice_identifier)`

Why not just `notice_identifier`?
- Different source families may use overlapping identifier ranges (e.g., KM notice #100123 vs PipeRiv notice #100123)
- Including `source_family` + `pipeline_name` makes the key globally unique without surrogate IDs

**Idempotency:** The `upsert_to_azure_postgresql` function performs INSERT ... ON CONFLICT UPDATE, so re-scraping the same notice updates it in place.

### Notice Lifecycle Strategy

```
FIRST SCRAPE:  notice appears → INSERT into notices (is_active=TRUE, first_seen_at=NOW)
RE-SCRAPE:     notice still visible → UPDATE last_seen_at, update any changed fields
DISAPPEARED:   notice not in current listing but was active → SET is_active=FALSE, disappeared_at=NOW
RE-APPEARED:   notice shows up again → SET is_active=TRUE, disappeared_at=NULL
```

**Disappearance detection (`_detect_disappeared`):**
```python
def _detect_disappeared(self, current_df: pd.DataFrame):
    """Mark notices that were active but not in current scrape as disappeared."""
    current_ids = set(current_df["notice_identifier"].tolist())
    query = """
        UPDATE gas_ebbs.notices
        SET is_active = FALSE, disappeared_at = NOW()
        WHERE pipeline_name = %s
          AND source_family = %s
          AND is_active = TRUE
          AND notice_identifier NOT IN %s
    """
    # Execute with (self.pipeline_name, self.source_family, tuple(current_ids))
```

---

## Dashboard Data Model

Based on the Hyperion dashboard references (Gas-ebb-dashboard-1.png, image.png, image copy.png, image copy 2.png):

### View 1: `gas_ebbs.v_active_notice_summary` — KPI cards

```sql
CREATE VIEW gas_ebbs.v_active_notice_summary AS
SELECT
    COUNT(*)                                               AS total_active_notices,
    COUNT(*) FILTER (WHERE notice_category = 'force_majeure')   AS force_majeure_count,
    COUNT(*) FILTER (WHERE notice_category = 'ofo')             AS ofo_count,
    COUNT(*) FILTER (WHERE notice_category = 'maintenance')     AS maintenance_count,
    COUNT(*) FILTER (WHERE notice_category = 'capacity_reduction') AS capacity_reduction_count,
    COUNT(DISTINCT pipeline_name)                          AS pipelines_affected,
    COUNT(DISTINCT source_family)                          AS sources_scraped
FROM gas_ebbs.notices
WHERE is_active = TRUE;
```

### View 2: `gas_ebbs.v_outage_timeline` — Gantt chart data

```sql
CREATE VIEW gas_ebbs.v_outage_timeline AS
SELECT
    pipeline_name,
    notice_identifier,
    subject,
    notice_category,
    severity,
    effective_at                       AS outage_start,
    COALESCE(end_at, '9999-12-31'::timestamptz) AS outage_end,
    gas_day_start,
    gas_day_end,
    EXTRACT(EPOCH FROM (COALESCE(end_at, NOW()) - effective_at)) / 3600 AS duration_hours,
    is_active
FROM gas_ebbs.notices
WHERE notice_category IN ('force_majeure', 'maintenance', 'capacity_reduction', 'ofo')
  AND effective_at IS NOT NULL
ORDER BY effective_at;
```

### View 3: `gas_ebbs.v_notices_by_pipeline` — Pipeline detail table

```sql
CREATE VIEW gas_ebbs.v_notices_by_pipeline AS
SELECT
    pipeline_name,
    source_family,
    notice_identifier,
    notice_type,
    notice_category,
    severity,
    subject,
    posted_at,
    effective_at,
    end_at,
    is_active,
    first_seen_at,
    last_seen_at
FROM gas_ebbs.notices
ORDER BY pipeline_name, posted_at DESC;
```

### Dashboard metrics that require external data

The dashboard references show **production impact** (Bcf/d reductions), **demand center alerts** (bullish/bearish), and **SOD region mapping**. These cannot come from EBB notices alone:

| Metric | Required External Dataset | Join Key |
|---|---|---|
| Capacity at risk (Bcf/d) | Pipeline segment capacity data (FERC Form 567/annual filings or commercial capacity data) | `pipeline_name` + segment identifier |
| Production impact by SOD region | EIA-757 / Genscape production estimates + pipeline-to-basin mapping | `pipeline_name` → basin/region |
| Affected receipt/delivery points | Pipeline operator tariff data or flow nomination data | `pipeline_name` + location code |
| Flow direction impact | Day-ahead nomination/scheduled flow data (e.g., from OASIS) | `pipeline_name` + location |
| Bullish/bearish demand center alerts | Manual analyst rules OR ML model mapping (outage location → demand center impact) | `pipeline_name` + segment + notice_category |
| Regional price impact | ICE/CME day-ahead gas prices at affected hubs | Trading hub → pipeline geography |

**Recommendation:** Build the EBB framework first. Capacity-at-risk and production impact should be a separate enrichment pipeline that joins `gas_ebbs.notices` with a `gas_reference.pipeline_segments` table (pipeline name → segments → capacity → basin). The reference images suggest this is analyst-driven classification today — automate incrementally.

---

## Migration Plan

### Phase 1: Framework + Canonical Tables (Week 1-2)

1. Create `gas_ebbs.notices`, `gas_ebbs.notice_snapshots`, `gas_ebbs.scrape_runs` tables
2. Implement `base_scraper.py`, `ebb_utils.py`, `notice_classifier.py`
3. Implement `piperiv_adapter.py` (covers 13 pipelines — biggest bang)
4. Write YAML config for PipeRiv family
5. Write `runs.py` and `flows.py`
6. Run PipeRiv adapter against all 13 pipelines, validate output

### Phase 2: Remaining Adapters (Week 2-3)

7. Implement `kindermorgan_adapter.py` → validate TGP + NGPL
8. Implement `gasnom_adapter.py` → validate Southern Pines
9. Implement `enbridge_adapter.py` → validate Texas Eastern
10. Implement `williams_adapter.py` → validate Transco (session + delvid)
11. Implement `tallgrass_adapter.py` → validate REX (Selenium)

### Phase 3: Detail Page Enrichment (Week 3-4)

12. Implement `notice_enricher.py` with detail-page parsing (TC Energy + KM formats)
13. Add detail-page fetching to base class `main()` loop
14. Add Azure Blob raw HTML retention
15. Backfill detail data for existing active notices

### Phase 4: Legacy Migration (Week 4)

16. Write `sql/migrate_legacy.sql`:
    ```sql
    -- For each legacy table:
    INSERT INTO gas_ebbs.notices (source_family, pipeline_name, notice_identifier, ...)
    SELECT
        'piperiv' AS source_family,
        'algonquin' AS pipeline_name,
        notice_identifier,
        notice_type,
        subject,
        -- Parse datetime strings to TIMESTAMPTZ
        CASE WHEN posted_datetime ~ '^\d' THEN posted_datetime::timestamptz ELSE NULL END,
        ...
        TRUE AS is_active,
        scraped_at::timestamptz AS first_seen_at,
        scraped_at::timestamptz AS last_seen_at,
        NOW() AS scraped_at
    FROM gas_ebbs.algonquin_critical_notices
    ON CONFLICT (source_family, pipeline_name, notice_identifier) DO NOTHING;
    ```
17. Run migration for all 20 legacy tables
18. Validate row counts: `SELECT pipeline_name, COUNT(*) FROM gas_ebbs.notices GROUP BY 1`
19. Rename legacy tables to `gas_ebbs._legacy_<pipeline>_critical_notices` (keep as backup)

### Phase 5: Dashboard Views + Scheduling (Week 4-5)

20. Create dashboard views (`v_active_notice_summary`, `v_outage_timeline`, `v_notices_by_pipeline`)
21. Set up scheduled task (`.ps1` registration per repo convention)
22. Monitor for 1 week in parallel with legacy scrapers
23. Decommission legacy scrapers after validation

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| PipeRiv HTML structure changes | Medium | High — breaks 13 pipelines | Raw HTML retention in blob → can re-parse; alert on zero-row scrapes |
| Incapsula blocks Selenium for REX | High | Medium — 1 pipeline | Rotate user agents; consider Playwright; accept degraded REX coverage |
| Datetime parsing failures across formats | Medium | Medium | `dateutil.parser` fallback + store raw string alongside parsed TIMESTAMPTZ |
| Williams JSF session breaks | Medium | Medium — 1 pipeline | Session retry logic; monitor `transco` scrape success rate separately |
| Detail page format changes | Medium | Low — enrichment degrades gracefully | Detail fields are nullable; listing-only mode still works |
| Legacy migration datetime parsing | Medium | Low | Parse with multiple format attempts; NULL on failure; log failures |
| Notice identifier collisions across families | Low | High | Composite PK `(source_family, pipeline_name, notice_identifier)` prevents this |

---

## Open Questions

1. **REX Selenium in production:** Is Selenium acceptable for production scheduled tasks, or should we investigate a headless API alternative for Tallgrass? (Confidence: 60% that Selenium is sustainable long-term)
   - **Validation needed:** Run REX scraper 50 times over 1 week, measure success rate and latency

2. **Detail page fetch rate limiting:** Should we throttle detail-page fetches (e.g., 1 req/sec) to avoid triggering rate limits on pipeline operator sites?
   - **Validation needed:** Test 50 rapid detail-page fetches against PipeRiv; check for 429s or blocks

3. **Capacity-at-risk data source:** Where will pipeline segment capacity data come from? Options:
   - FERC Form 567 filings (public, annual, stale)
   - Commercial data (Genscape/S&P/RBN)
   - Manual analyst-maintained reference table
   - **Decision needed from business team**

4. **Historical backfill depth:** How far back should we migrate legacy data? Legacy tables may have years of notices, but many are stale.
   - **Recommendation:** Migrate all, but only mark notices from the last 90 days as `is_active=TRUE`

5. **Enbridge InfoPost specifics:** The legacy scraper for `texas_eastern` exists but its exact HTML structure should be confirmed against the live site before implementing the adapter.
   - **Validation needed:** Manual inspection of `infopost.enbridge.com` notice page structure

6. **Notice count per pipeline:** PipeRiv shows only "critical notices" — are there other notice types (non-critical, informational) we should also capture?
   - **Decision needed from business team**

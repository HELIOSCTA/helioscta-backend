# NatGas (WM DataFeed)

Natural gas nominations, LNG terminal flows, and salt cavern storage analytics from the Wood Mackenzie (Genscape) NatGas DataFeed. Data is ingested into Azure SQL Server and transformed via dbt into business-ready views.

**Use this page** to find NatGas data sources, ingestion details, and dbt views.

## Data Source

- **Vendor:** Wood Mackenzie (formerly Genscape)
- **Feed:** NatGas DataFeed REST API
- **Target Database:** Azure SQL Server (`GenscapeDataFeed`)
- **Target Schema:** `natgas` (raw), `natgas_cleaned` (dbt views)
- **Ingestion:** PowerShell scripts (`gasdatafeed_import.ps1`) via Windows Task Scheduler
- **Authentication:** Azure SQL credentials (`AZURE_SQL_USER`, `AZURE_SQL_PASSWORD`)

## Raw Data Inventory

| Raw Table | Description | Ingestion Type | Refresh |
|-----------|-------------|----------------|---------|
| `natgas.nominations` | Daily gas capacity nominations by location, pipeline, and cycle | Delta (hourly) | Every 20/30/40 min |
| `natgas.nomination_cycles` | Scheduling cycle definitions | Metadata | Hourly at :05/:10 |
| `natgas.no_notice` | Intra-day no-notice capacity transactions | Delta (hourly) | Every 20/30/40 min |
| `natgas.location_role` | Location-to-role mappings (shippers, receivers, meters) | Metadata | Hourly at :05/:10 |
| `natgas.location_extended` | Location details (name, coordinates, county, state, timezone) | Metadata | Hourly at :05/:10 |
| `natgas.pipelines` | Pipeline reference data (IDs, names, FERC 720 flag) | Metadata | Hourly at :05/:10 |

## Ingestion Schedule

Data is ingested via Windows Task Scheduler under `\helioscta-backend\NatGas\`:

| Task | Schedule | Source Type |
|------|----------|-------------|
| `wm_natgasdatafeed_import delta 20` | Every hour at :20 | Delta |
| `wm_natgasdatafeed_import delta 30` | Every hour at :30 | Delta |
| `wm_natgasdatafeed_import delta 40` | Every hour at :40 | Delta |
| `wm_natgasdatafeed_import hourly` | Every hour at :50 | Hourly |
| `wm_natgasdatafeed_import metadata` | Every hour at :05 and :10 | Metadata |

## Analytical Sub-Domains

The natgas_cleaned schema covers three analytical areas:

1. **Nominations** -- enriched gas nominations with pipeline, location, and cycle details
2. **LNG** -- LNG terminal nomination flows for 9 US export facilities (Calcasieu, Cameron, Corpus Christi, Cove Point, Elba, Freeport, Golden Pass, Plaquemines, Sabine)
3. **SALTS** -- salt cavern storage facility flows and inventory metrics across TX, LA, MS, AL (16 facilities)

## dbt Cleaned Views

All dbt views are materialized in the `natgas_cleaned` schema on Azure SQL Server:

| View | Description |
|------|-------------|
| `genscape_noms` | Denormalized nominations with pipeline, location, cycle, and no-notice data |
| `lng_facilities` | LNG terminal flows with multi-pipeline facility aggregation |
| `salt_facilities_bcf` | Daily storage flows in BCF pivoted by facility with regional subtotals |
| `salt_inventories` | Daily inventory levels, deltas, and capacity metrics by facility |

Pipeline:
- **Nominations:** `source (genscape_noms) → mart (genscape_noms)`
- **LNG:** `source (genscape_noms → lng_noms) → mart (lng_facilities)`
- **SALTS:** `source (genscape_noms + reference tables) → staging (salts_noms/inventories) → marts (salt_facilities_bcf, salt_inventories)`

## Verification

Check import health via these Azure SQL tables:

- **`natgas.load_status`** -- last successful import per source type
- **`administration.error_log`** -- import errors and failures

See [verification notes](https://github.com/helioscta/helioscta-backend/blob/main/schedulers/task_scheduler_azuresql/wm_natgasdatafeed_import/.verify/notes.md) for detailed health check queries.

## Known Caveats

- This dbt project uses **dbt-sqlserver** (T-SQL), not dbt-postgres like the rest of the backend
- All intermediate models (source, staging, utils) are ephemeral -- only the 4 mart views exist in the database
- Nomination data starts from `2020-01-01` (WHERE filter in source model)

## Owner

TBD

# PJM Transmission Outages

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/src/power/pjm/transmission_outages.py` |
| **Source** | PJM eDART (`https://edart.pjm.com/reports/linesout.txt`) |
| **Target Tables** | `pjm.transmission_outages`, `pjm.transmission_outages_dod_changes` |
| **Trigger** | Scheduled (daily at 07:00 ET) |
| **Freshness** | Updated ~daily by PJM |
| **Owner** | TBD |

## Business Purpose

Tracks scheduled and planned transmission facility outages across the PJM footprint. Unlike generation outages (which track MW offline), transmission outages affect transfer capability between zones and can create congestion, influencing LMPs and FTR values.

Day-over-day (DoD) change tracking surfaces new outages, resolved outages, and field-level modifications (date extensions, status changes) for daily reporting.

## Data Captured

### `pjm.transmission_outages` (latest snapshot)

| Column | Type | Description |
|--------|------|-------------|
| `ticket_id` | INTEGER | PJM outage ticket number (**PK**) |
| `item_number` | INTEGER | Sequential position in the report |
| `zone` | VARCHAR | Transmission zone / company code |
| `facility_name` | VARCHAR | Full facility description |
| `equipment_type` | VARCHAR | BRKR, XFMR, LINE, CAP, LD, GEN, SD, PS |
| `station` | VARCHAR | Substation name |
| `voltage_kv` | FLOAT | Voltage level (kV) |
| `start_datetime` | TIMESTAMP | Outage start |
| `end_datetime` | TIMESTAMP | Outage end |
| `status` | VARCHAR | O (Open) or C (Closed) |
| `outage_state` | VARCHAR | Active, etc. |
| `last_revised` | TIMESTAMP | Last time PJM revised the ticket |
| `cause` | VARCHAR | Maintenance type / cause (up to 3) |
| `approval_status` | VARCHAR | Submitted, Approved, Received |
| `equipment_count` | INTEGER | Number of equipment items on the ticket |
| `section` | VARCHAR | scheduled or planned |
| `scrape_date` | DATE | Date of the scrape |
| `scrape_timestamp` | TIMESTAMP | Exact timestamp from the file |

### `pjm.transmission_outages_dod_changes` (change log)

| Column | Type | Description |
|--------|------|-------------|
| `change_date` | DATE | Date the change was detected (**PK**) |
| `ticket_id` | INTEGER | PJM ticket number (**PK**) |
| `change_type` | VARCHAR | NEW, RESOLVED, or MODIFIED (**PK**) |
| `field_changed` | VARCHAR | Which field changed (for MODIFIED) (**PK**) |
| `old_value` | VARCHAR | Previous value |
| `new_value` | VARCHAR | New value |
| `zone` | VARCHAR | Transmission zone |
| `facility_name` | VARCHAR | Facility description |

## DoD Change Logic

1. **NEW**: `ticket_id` present today but absent from previous snapshot.
2. **RESOLVED**: `ticket_id` present in previous snapshot but absent today.
3. **MODIFIED**: Same `ticket_id` in both snapshots but one or more tracked fields differ: `end_datetime`, `status`, `outage_state`, `last_revised`, `cause`, `approval_status`, `equipment_count`.

## How to Run

```bash
# Single run (from repo root)
python backend/src/power/pjm/transmission_outages.py

# Via PJM runner
python backend/src/power/pjm/runs.py  # then select transmission_outages
```

## Task Scheduler

| Field | Value |
|-------|-------|
| **PowerShell** | `schedulers/task_scheduler_azurepostgresql/power/pjm_transmission_outages.ps1` |
| **Task Name** | `PJM Transmission Outages (eDART)` |
| **Task Path** | `\helioscta-backend\Power\` |
| **Cadence** | Daily at 07:00 ET |

Register:
```powershell
.\schedulers\task_scheduler_azurepostgresql\power\pjm_transmission_outages.ps1
```

Remove:
```powershell
Unregister-ScheduledTask -TaskName "PJM Transmission Outages (eDART)" -Confirm:$false
```

## Downstream

- Daily summary logged to `logging.pipeline_runs` via `PipelineRunLogger`.
- DoD change table can drive alerts, dashboards, or Slack summaries.

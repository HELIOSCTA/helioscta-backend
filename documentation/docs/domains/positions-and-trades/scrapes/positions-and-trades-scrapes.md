# Positions & Trades Scrape Cards

## Position Pulls

All position scripts pull CSV/Excel files from SFTP servers and load them into Azure PostgreSQL.

### Marex Positions

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/postions_and_trades/tasks/pull_from_sftp/positions/marex/marex_sftp_positions_v2_2026_feb_23.py` |
| **Source** | Marex SFTP |
| **Target Table** | `marex.marex_sftp_positions_v2_2026_feb_23` |
| **Trigger** | Scheduled |
| **Freshness** | T+1 (files arrive overnight) |

**Business Purpose:** Daily end-of-day futures and options positions held at Marex. Shows what contracts are open, quantities, and mark-to-market values.

### NAV Fund Positions (4 scripts)

| Fund | Script | Table |
|------|--------|-------|
| AGR | `nav_sftp_positions_agr_v2_2026_feb_23.py` | `nav.nav_sftp_positions_agr_v2_2026_feb_23` |
| Moross | `nav_sftp_positions_moross_v2_2026_feb_23.py` | `nav.nav_sftp_positions_moross_v2_2026_feb_23` |
| PNT | `nav_sftp_positions_pnt_v2_2026_feb_23.py` | `nav.nav_sftp_positions_pnt_v2_2026_feb_23` |
| Titan | `nav_sftp_positions_titan_v2_2026_feb_23.py` | `nav.nav_sftp_positions_titan_v2_2026_feb_23` |

**Business Purpose:** Daily position reports from NAV (fund administrator) for each fund. Used for position reconciliation against internal records and broker reports.

---

## Trade Pulls

### Clear Street End-of-Day Trades

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/postions_and_trades/tasks/pull_from_sftp/trades/clear_street/helios_transactions_v2_2026_feb_23.py` |
| **Source** | Clear Street SFTP |
| **Target Table** | `clear_street.helios_transactions_v2_2026_feb_23` |
| **Trigger** | Scheduled |
| **Freshness** | T+1 |

**Business Purpose:** Official end-of-day trade confirmations from the prime broker. Used for trade reconciliation and settlement.

### Clear Street Intraday Trades

| Field | Value |
|-------|-------|
| **Script** | `helios_intraday_transactions_v2_2026_feb_23.py` |
| **Table** | `clear_street.helios_intraday_transactions_v2_2026_feb_23` |
| **Freshness** | Intraday (multiple pulls per day) |

**Business Purpose:** Real-time trade confirmations throughout the trading day. Used for intraday position tracking before end-of-day files arrive.

### Marex Allocated Trades

| Field | Value |
|-------|-------|
| **Script** | `helios_allocated_trades_v2_2026_feb_23.py` |
| **Table** | `marex.helios_allocated_trades_v2_2026_feb_23` |
| **Freshness** | T+1 |

**Business Purpose:** Confirmed allocated (cleared) trades from Marex broker. Shows which trades have been officially cleared and assigned to accounts.

### Marex Preliminary Trades

| Field | Value |
|-------|-------|
| **Script** | `marex_prelim_trades_v2_2026_feb_23.py` |
| **Table** | TBD |
| **Freshness** | Same-day |

**Business Purpose:** Preliminary (uncleared) trades from Marex, available before official allocation.

---

## Trade Break Detection

### NAV Trade Breaks

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/postions_and_trades/tasks/pull_from_sftp/trade_breaks/nav_trade_breaks_v2_2026_feb_24.py` |
| **Source** | NAV SFTP |
| **Freshness** | T+1 |

**Business Purpose:** Identifies discrepancies between internal trade records and NAV's records. Trade breaks must be investigated and resolved promptly -- they indicate a trade that one side recognizes but the other does not.

---

## Trade Distribution (Email Scripts)

These scripts send cleaned trade data to counterparties:

| Script | Recipient | Data |
|--------|-----------|------|
| `send_clear_street_trades_to_mufg_v1_2026_feb_02.py` | MUFG | Clear Street trades |
| `send_clear_street_trades_to_nav_v1_2026_feb_02.py` | NAV | Clear Street trades |
| `send_marex_allocated_trades_to_nav_v1_2026_feb_02.py` | NAV | Marex allocated trades |

**Business Purpose:** Distributes cleaned trade confirmations to fund administrators and banks for reconciliation and reporting.

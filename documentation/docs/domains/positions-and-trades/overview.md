# Positions & Trades

Trading operations data -- position reports (Marex, NAV) and trade confirmations (Clear Street, Marex) arriving via SFTP. Cleaned via dbt into 14 analysis-ready views across `positions_cleaned` and `trades_cleaned` schemas.

**Use this page** to find position/trade scrape scripts, raw tables, and dbt views.

## Data Flow

```
SFTP File Drops (Marex, NAV, Clear Street)
        |
   Pull Scripts  (backend/scrapes/postions_and_trades/tasks/pull_from_sftp/)
        |
   Raw Tables    (marex.*, nav.*, clear_street.* schemas)
        |
   dbt Models    (positions_cleaned, trades_cleaned schemas)
        |
   Email Scripts (send cleaned files to counterparties like MUFG, NAV)
```

## Scrape Inventory

### Position Pulls (5 scripts)

| Script | Table | Source | Description |
|--------|-------|--------|-------------|
| `marex_sftp_positions_v2_2026_feb_23.py` | `marex.marex_sftp_positions_v2_2026_feb_23` | Marex SFTP | Daily futures/options positions from Marex |
| `nav_sftp_positions_agr_v2_2026_feb_23.py` | `nav.nav_sftp_positions_agr_v2_2026_feb_23` | NAV SFTP | AGR fund position report |
| `nav_sftp_positions_moross_v2_2026_feb_23.py` | `nav.nav_sftp_positions_moross_v2_2026_feb_23` | NAV SFTP | Moross fund position report |
| `nav_sftp_positions_pnt_v2_2026_feb_23.py` | `nav.nav_sftp_positions_pnt_v2_2026_feb_23` | NAV SFTP | PNT fund position report |
| `nav_sftp_positions_titan_v2_2026_feb_23.py` | `nav.nav_sftp_positions_titan_v2_2026_feb_23` | NAV SFTP | Titan fund position report |

### Trade Pulls (4 scripts)

| Script | Table | Source | Description |
|--------|-------|--------|-------------|
| `helios_transactions_v2_2026_feb_23.py` | `clear_street.helios_transactions_v2_2026_feb_23` | Clear Street SFTP | End-of-day trade confirmations |
| `helios_intraday_transactions_v2_2026_feb_23.py` | `clear_street.helios_intraday_transactions_v2_2026_feb_23` | Clear Street SFTP | Intraday trade confirmations |
| `helios_allocated_trades_v2_2026_feb_23.py` | `marex.helios_allocated_trades_v2_2026_feb_23` | Marex SFTP | Allocated (cleared) trade records |
| `marex_prelim_trades_v2_2026_feb_23.py` | TBD | Marex SFTP | Preliminary (uncleared) trade records |

### Trade Break Monitoring (1 script)

| Script | Description |
|--------|-------------|
| `nav_trade_breaks_v2_2026_feb_24.py` | Identifies discrepancies between internal and NAV trade records |

### Email/Distribution Scripts (3 scripts)

| Script | Description |
|--------|-------------|
| `send_clear_street_trades_to_mufg_v1_2026_feb_02.py` | Sends cleaned Clear Street trades to MUFG |
| `send_clear_street_trades_to_nav_v1_2026_feb_02.py` | Sends cleaned Clear Street trades to NAV |
| `send_marex_allocated_trades_to_nav_v1_2026_feb_02.py` | Sends cleaned Marex trades to NAV |

## Refresh Cadence

- **Positions:** T+1 (files arrive overnight, pulled next morning)
- **Trades (end-of-day):** T+1
- **Trades (intraday):** Multiple times per trading day
- **Trigger:** Scheduled

## dbt Views

### Positions Cleaned (`positions_cleaned` schema)

The positions pipeline combines Marex and NAV position data through a multi-step staging process:
1. **Combined** -- Union Marex + NAV positions into one dataset
2. **Forward Fill** -- Fill missing values for positions held across dates
3. **Add Columns** -- Add derived fields (product codes, exchange info)
4. **Exchange Codes** -- Standardize exchange code formatting

Final mart: combined Marex + NAV positions with standardized fields.

### Trades Cleaned (`trades_cleaned` schema)

| View | Description |
|------|-------------|
| `clear_street_trades` | Cleaned end-of-day Clear Street trade confirmations |
| `clear_street_intraday_trades` | Cleaned intraday Clear Street trade confirmations |
| `marex_allocated_trades` | Cleaned Marex allocated (cleared) trades |

Each trade staging pipeline adds product codes and standardized columns.

## dbt Reference Tables

| Table | Schema | Description |
|-------|--------|-------------|
| `source_v1_positions_and_trades_product_lookup` | `dbt` | Maps raw product symbols to standardized product codes |
| `source_v1_positions_and_trades_accounts_lookup` | `dbt` | Maps account IDs to fund names |
| `source_v1_positions_and_trades_traders_lookup` | `dbt` | Maps trader IDs to trader names |

## Known Caveats

- Directory is misspelled as `postions_and_trades` (missing 'i') -- this is the actual folder name
- SFTP file arrival times depend on counterparty systems and may be delayed
- Trade break detection (`nav_trade_breaks`) is critical for operations -- any breaks need same-day resolution
- Position forward-fill logic assumes missing dates mean the position is unchanged

## Owner

TBD

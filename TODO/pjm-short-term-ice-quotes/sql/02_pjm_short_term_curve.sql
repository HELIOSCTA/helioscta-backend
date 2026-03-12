-- =============================================================================
-- 02_pjm_short_term_curve.sql
-- Builds one ordered PJM short-term curve result set combining:
--   1. RT on-peak settles for weekdays already occurred in the current week
--   2. Current LAST PJM RT  (PDP D1-IUS)
--   3. Current LAST PJM DA  (PDA D1-IUS)
--   4. Bal Week              (PDP W0-IUS, only if it exists today)
--   5. Remaining weeklies for the current month
--   6. Current monthly PJM   (PMI %-IUS)
-- =============================================================================
--
-- Assumptions:
--   - pjm_cleaned.pjm_lmps_daily columns: date, hub, period, market, lmp_total
--       hub = 'WESTERN HUB', market IN ('da','rt'), period IN ('flat','onpeak','offpeak')
--   - ice_python.intraday_quotes: long format, PK = (trade_date, snapshot_at, data_type, symbol)
--   - ice_python.contract_dates:  PK = (trade_date, symbol), columns: strip, start_date, end_date
--   - "Current week" = Mon-Sun week containing CURRENT_DATE (ISO week).
--   - On-peak RT settles are for weekdays (Mon-Fri) in the current week before today.
--   - Weekly contracts whose start_date has not yet passed are "remaining".
-- =============================================================================

-- ─── Section 1: RT on-peak settles for past weekdays this week ──────────────
WITH current_week_bounds AS (
    -- Monday of the current ISO week through today (exclusive).
    SELECT
        DATE_TRUNC('week', CURRENT_DATE)::DATE AS week_start,  -- Monday
        CURRENT_DATE                            AS today
),

rt_onpeak_settles AS (
    SELECT
        d.date,
        d.lmp_total                                                      AS value,
        'RT Settle'                                                      AS section,
        TO_CHAR(d.date, 'Dy Mon-DD')                                     AS label,
        1                                                                AS section_order,
        d.date                                                           AS sort_date
    FROM pjm_cleaned.pjm_lmps_daily d
    CROSS JOIN current_week_bounds w
    WHERE d.hub     = 'WESTERN HUB'
      AND d.market  = 'rt'
      AND d.period  = 'onpeak'
      -- Weekdays already occurred this week (Mon=1 .. Fri=5 in ISO DOW).
      AND d.date >= w.week_start
      AND d.date <  w.today
      AND EXTRACT(ISODOW FROM d.date) BETWEEN 1 AND 5
),

-- ─── Latest ICE snapshot for today ──────────────────────────────────────────
ice_latest_snapshot AS (
    SELECT
        iq.symbol,
        iq.snapshot_at,
        iq.data_type,
        iq.value,
        DENSE_RANK() OVER (
            PARTITION BY iq.symbol
            ORDER BY iq.snapshot_at DESC
        ) AS snapshot_rank
    FROM ice_python.intraday_quotes iq
    WHERE iq.trade_date = CURRENT_DATE
),

ice_today AS (
    SELECT symbol, data_type, value
    FROM ice_latest_snapshot
    WHERE snapshot_rank = 1
),

-- Helper: latest "Last" price per symbol.
ice_last AS (
    SELECT symbol, value AS last_price
    FROM ice_today
    WHERE data_type = 'Last'
),

-- Helper: latest "Recent Settlement" per symbol.
ice_recent_settle AS (
    SELECT symbol, value AS recent_settlement
    FROM ice_today
    WHERE data_type = 'Recent Settlement'
),

-- Contract date metadata for today's symbols.
contract_info AS (
    SELECT symbol, strip, start_date, end_date
    FROM ice_python.contract_dates
    WHERE trade_date = CURRENT_DATE
),

-- ─── Section 2: Current LAST PJM RT ────────────────────────────────────────
pjm_rt_last AS (
    SELECT
        NULL::DATE                  AS date,
        il.last_price               AS value,
        'PJM RT Last'               AS section,
        'PDP D1-IUS (RT Last)'      AS label,
        2                           AS section_order,
        CURRENT_DATE                AS sort_date
    FROM ice_last il
    WHERE il.symbol = 'PDP D1-IUS'
),

-- ─── Section 3: Current LAST PJM DA ────────────────────────────────────────
pjm_da_last AS (
    SELECT
        NULL::DATE                  AS date,
        il.last_price               AS value,
        'PJM DA Last'               AS section,
        'PDA D1-IUS (DA Last)'      AS label,
        3                           AS section_order,
        CURRENT_DATE                AS sort_date
    FROM ice_last il
    WHERE il.symbol = 'PDA D1-IUS'
),

-- ─── Section 4: Bal Week (only if PDP W0-IUS exists today) ─────────────────
bal_week AS (
    SELECT
        ci.start_date               AS date,
        COALESCE(il.last_price, irs.recent_settlement) AS value,
        'Bal Week'                  AS section,
        'PDP W0-IUS (Bal Week)'     AS label,
        4                           AS section_order,
        COALESCE(ci.start_date, CURRENT_DATE) AS sort_date
    FROM contract_info ci
    LEFT JOIN ice_last il          ON il.symbol = ci.symbol
    LEFT JOIN ice_recent_settle irs ON irs.symbol = ci.symbol
    WHERE ci.symbol = 'PDP W0-IUS'
),

-- ─── Section 5: Remaining weeklies for the current month ───────────────────
-- A weekly is "remaining" if its start_date has not yet fully elapsed.
remaining_weeklies AS (
    SELECT
        ci.start_date               AS date,
        COALESCE(il.last_price, irs.recent_settlement) AS value,
        'Weekly'                    AS section,
        ci.symbol || ' (' || TO_CHAR(ci.start_date, 'Mon DD') || '-'
                           || TO_CHAR(ci.end_date,   'Mon DD') || ')' AS label,
        5                           AS section_order,
        ci.start_date               AS sort_date
    FROM contract_info ci
    LEFT JOIN ice_last il          ON il.symbol = ci.symbol
    LEFT JOIN ice_recent_settle irs ON irs.symbol = ci.symbol
    WHERE ci.symbol IN ('PDP W1-IUS','PDP W2-IUS','PDP W3-IUS','PDP W4-IUS')
      -- Only weeklies whose period end is within the current calendar month.
      AND ci.end_date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE
      -- Only "remaining" = start_date >= today.
      AND ci.start_date >= CURRENT_DATE
),

-- ─── Section 6: Current monthly PJM (PMI) ──────────────────────────────────
current_monthly AS (
    SELECT
        ci.start_date               AS date,
        COALESCE(il.last_price, irs.recent_settlement) AS value,
        'Monthly'                   AS section,
        ci.symbol || ' (' || TO_CHAR(ci.start_date, 'Mon') || ')' AS label,
        6                           AS section_order,
        ci.start_date               AS sort_date
    FROM contract_info ci
    LEFT JOIN ice_last il          ON il.symbol = ci.symbol
    LEFT JOIN ice_recent_settle irs ON irs.symbol = ci.symbol
    WHERE ci.symbol LIKE 'PMI %-IUS'
      -- Current month's monthly contract: start_date within this calendar month.
      AND ci.start_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
      AND ci.start_date <  (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month')::DATE
),

-- ─── Combine all sections ──────────────────────────────────────────────────
combined AS (
    SELECT date, value, section, label, section_order, sort_date FROM rt_onpeak_settles
    UNION ALL
    SELECT date, value, section, label, section_order, sort_date FROM pjm_rt_last
    UNION ALL
    SELECT date, value, section, label, section_order, sort_date FROM pjm_da_last
    UNION ALL
    SELECT date, value, section, label, section_order, sort_date FROM bal_week
    UNION ALL
    SELECT date, value, section, label, section_order, sort_date FROM remaining_weeklies
    UNION ALL
    SELECT date, value, section, label, section_order, sort_date FROM current_monthly
)

SELECT
    section_order,
    section,
    label,
    date,
    ROUND(value::NUMERIC, 2) AS value
FROM combined
ORDER BY
    section_order,
    sort_date,
    label;

-- =============================================================================
-- Script 2: PJM RT OnPeak Monthly Calendar
-- =============================================================================
-- Replicates the right side of the PJM short-term ICE quotes spreadsheet.
-- Builds a calendar for the current month where each weekday gets a price:
--
--   1. Past weekdays        → RT onpeak settle (from pjm_cleaned.pjm_lmps_daily)
--   2. Current day          → LAST PJM RT (PDP D0-IUS) from ICE intraday quotes
--   3. Balance of week      → PDP W0-IUS Recent Settlement (if contract exists)
--   4. Future full weeks    → PDP W1/W2/W3/W4 Recent Settlement (matched by date range)
--   5. Monthly reference    → PMI front-month Recent Settlement
--
-- Sources:
--   pjm_cleaned.pjm_lmps_daily       (RT onpeak settlements)
--   ice_python.intraday_quotes        (current ICE quotes)
--   ice_python.contract_dates         (weekly contract date ranges)
--
-- Onpeak definition: HE 8-23 (per dbt staging_v1_pjm_lmps_daily)
-- =============================================================================

WITH

-- =========================================================================
-- Calendar: every day of the current month
-- =========================================================================
month_calendar AS (
    SELECT
        d::DATE AS date,
        EXTRACT(DOW FROM d::DATE) AS dow,  -- 0=Sun, 1=Mon, ..., 6=Sat
        TO_CHAR(d::DATE, 'Dy') AS day_name,
        TO_CHAR(d::DATE, 'Dy Mon-DD') AS date_label,
        (EXTRACT(DOW FROM d::DATE) BETWEEN 1 AND 5) AS is_weekday
    FROM generate_series(
        DATE_TRUNC('month', CURRENT_DATE),
        DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day',
        INTERVAL '1 day'
    ) AS d
),

-- =========================================================================
-- 1. Past RT onpeak settlements (PJM Western Hub)
-- =========================================================================
rt_settles AS (
    SELECT
        date,
        lmp_total AS rt_onpeak
    FROM pjm_cleaned.pjm_lmps_daily
    WHERE hub = 'WESTERN HUB'
      AND market = 'rt'
      AND period = 'onpeak'
      AND date >= DATE_TRUNC('month', CURRENT_DATE)
      AND date < CURRENT_DATE
),

-- =========================================================================
-- 2. Current day: latest LAST for PJM RT (PDP D0-IUS) and DA (PDA D1-IUS)
-- =========================================================================
current_day_snapshot AS (
    SELECT
        iq.symbol,
        iq.value
    FROM ice_python.intraday_quotes iq
    INNER JOIN (
        SELECT symbol, MAX(snapshot_at) AS max_snapshot_at
        FROM ice_python.intraday_quotes
        WHERE trade_date = CURRENT_DATE
          AND data_type = 'Last'
          AND symbol IN ('PDP D0-IUS', 'PDP D1-IUS', 'PDA D1-IUS')
        GROUP BY symbol
    ) ls ON iq.symbol = ls.symbol AND iq.snapshot_at = ls.max_snapshot_at
    WHERE iq.trade_date = CURRENT_DATE
      AND iq.data_type = 'Last'
),

current_rt_last AS (
    SELECT value AS rt_last
    FROM current_day_snapshot
    WHERE symbol = 'PDP D0-IUS'
),

current_da_last AS (
    SELECT value AS da_last
    FROM current_day_snapshot
    WHERE symbol = 'PDA D1-IUS'
),

-- =========================================================================
-- 3 & 4. Weekly contracts: get Recent Settlement and date ranges
-- =========================================================================
weekly_quotes AS (
    SELECT
        iq.symbol,
        iq.value AS weekly_price,
        cd.start_date,
        cd.end_date
    FROM ice_python.intraday_quotes iq
    INNER JOIN (
        SELECT symbol, MAX(snapshot_at) AS max_snapshot_at
        FROM ice_python.intraday_quotes
        WHERE trade_date = CURRENT_DATE
          AND data_type = 'Recent Settlement'
          AND symbol IN ('PDP W0-IUS', 'PDP W1-IUS', 'PDP W2-IUS', 'PDP W3-IUS', 'PDP W4-IUS')
        GROUP BY symbol
    ) ls ON iq.symbol = ls.symbol AND iq.snapshot_at = ls.max_snapshot_at
    INNER JOIN ice_python.contract_dates cd
        ON cd.symbol = iq.symbol
        AND cd.trade_date = CURRENT_DATE
    WHERE iq.trade_date = CURRENT_DATE
      AND iq.data_type = 'Recent Settlement'
),

-- =========================================================================
-- 5. PMI monthly: front-month Recent Settlement
-- =========================================================================
pmi_monthly AS (
    SELECT
        iq.value AS pmi_price,
        cd.start_date AS pmi_start,
        cd.end_date AS pmi_end
    FROM ice_python.intraday_quotes iq
    INNER JOIN (
        SELECT symbol, MAX(snapshot_at) AS max_snapshot_at
        FROM ice_python.intraday_quotes
        WHERE trade_date = CURRENT_DATE
          AND data_type = 'Recent Settlement'
          AND symbol LIKE 'PMI%'
        GROUP BY symbol
    ) ls ON iq.symbol = ls.symbol AND iq.snapshot_at = ls.max_snapshot_at
    INNER JOIN ice_python.contract_dates cd
        ON cd.symbol = iq.symbol
        AND cd.trade_date = CURRENT_DATE
    WHERE iq.trade_date = CURRENT_DATE
      AND iq.data_type = 'Recent Settlement'
    LIMIT 1
),

-- =========================================================================
-- Assign a price to each calendar day
-- =========================================================================
calendar_with_prices AS (
    SELECT
        mc.date,
        mc.day_name,
        mc.date_label,
        mc.is_weekday,
        mc.dow,
        -- Past settled days
        rs.rt_onpeak,
        -- Current day
        CASE WHEN mc.date = CURRENT_DATE
            THEN (SELECT rt_last FROM current_rt_last)
        END AS current_rt_last,
        CASE WHEN mc.date = CURRENT_DATE
            THEN (SELECT da_last FROM current_da_last)
        END AS current_da_last,
        -- Weekly contract price (for future weekdays within a weekly range)
        wq.weekly_price,
        wq.symbol AS weekly_symbol,
        -- Blended price: use the best available source
        CASE
            -- Past settled weekday
            WHEN mc.date < CURRENT_DATE AND mc.is_weekday AND rs.rt_onpeak IS NOT NULL
                THEN rs.rt_onpeak
            -- Current day: use RT last
            WHEN mc.date = CURRENT_DATE AND mc.is_weekday
                THEN (SELECT rt_last FROM current_rt_last)
            -- Future weekday covered by a weekly contract
            WHEN mc.date > CURRENT_DATE AND mc.is_weekday AND wq.weekly_price IS NOT NULL
                THEN wq.weekly_price
            -- Weekend: no price
            ELSE NULL
        END AS price
    FROM month_calendar mc
    LEFT JOIN rt_settles rs ON rs.date = mc.date
    LEFT JOIN weekly_quotes wq
        ON mc.date BETWEEN wq.start_date AND wq.end_date
        AND mc.date > CURRENT_DATE
        AND mc.is_weekday
)

-- =========================================================================
-- Final output: monthly calendar + summary rows
-- =========================================================================
SELECT
    date_label,
    is_weekday,
    ROUND(price::NUMERIC, 2) AS price,
    ROUND(rt_onpeak::NUMERIC, 2) AS rt_settle,
    ROUND(current_rt_last::NUMERIC, 2) AS rt_last,
    ROUND(current_da_last::NUMERIC, 2) AS da_last,
    ROUND(weekly_price::NUMERIC, 2) AS weekly_quote,
    weekly_symbol,
    CASE
        WHEN NOT is_weekday THEN 'WEEKEND'
        WHEN date < CURRENT_DATE AND rt_onpeak IS NOT NULL THEN 'RT SETTLE'
        WHEN date = CURRENT_DATE THEN 'CURRENT DAY'
        WHEN date > CURRENT_DATE AND weekly_price IS NOT NULL THEN weekly_symbol
        ELSE 'NO DATA'
    END AS price_source
FROM calendar_with_prices

UNION ALL

-- MTD Weekday Average
SELECT
    'AVG' AS date_label,
    TRUE AS is_weekday,
    ROUND(AVG(price)::NUMERIC, 2) AS price,
    NULL, NULL, NULL, NULL, NULL,
    'WEEKDAY AVG' AS price_source
FROM calendar_with_prices
WHERE is_weekday AND price IS NOT NULL

UNION ALL

-- PMI Monthly Reference
SELECT
    'MAR PMI' AS date_label,
    TRUE AS is_weekday,
    ROUND(pm.pmi_price::NUMERIC, 2) AS price,
    NULL, NULL, NULL, NULL, NULL,
    'PMI MONTHLY' AS price_source
FROM pmi_monthly pm

ORDER BY
    CASE
        WHEN date_label = 'AVG' THEN '9998-01-01'
        WHEN date_label = 'MAR PMI' THEN '9999-01-01'
        ELSE date_label
    END;

--------------------------------------------------
-- NORTHEASTERN FLOW SUMMARY
-- Database: Criterion PostgreSQL
-- Source: Pipeline Flows + Production + Demand (Northeast)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 34 (27 flow + 1 production + 6 demand)
--
-- Matches the "Northeastern Flow Summary" report layout:
--   Production, Flows Out/In, Canadian & LNG trade,
--   NE Demand, Imbalance, Daily Change, Prior Week Avg
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        -- Production (1)
        'FDSD.NGPR.NE.APP.A'
        -- NE→MW flows (12)
        || ',PLAG.NE2MW.076.ANRSE.A,PLAG.NE2MW.099.TCO.A,PLAG.NE2MW.101.CROSSR.A,PLAG.NE2MW.065.ETNG.A,PLAG.NE2MW.375.NEX.A,PLAG.NE2MW.093.PEPL.A,PLAG.NE2MW.058.REX.A,PLAG.NE2MW.337.ROV.A,PLAG.NE2MW.073.TET24.A,PLAG.NE2MW.073.TET30.A,PLAG.NE2MW.054.TGP.A,PLAG.NE2MW.114.TGT.A'
        -- MW→NE reverse (1)
        || ',PLAG.MW2NE.093.PEPL.A'
        -- NE→SE (1)
        || ',PLAG.NE2SE.109.TRCO.A'
        -- Canadian cross-border: CN→US (6)
        || ',PLAG.CN2US.081.WADD.A,PLAG.CN2US.067.BRUNS.A,PLAG.CN2US.027.PITTS.A,PLAG.CN2US.086.NAPIER.A,PLAG.CN2US.086.CORNW.A,PLAG.CN2US.086.PHILIP.A'
        -- Canadian cross-border: US→CN (3)
        || ',PLAG.US2CN.139.CHIPP.A,PLAG.US2CN.067.BVILLE.A,PLAG.US2CN.054.NIAGRA.A'
        -- LNG (4)
        || ',PLAG.LNGIMP.SUM.EVER.A,PLAG.LNGIMP.SUM.COVE.A,PLAG.LNGIMP.SUM.NEGWY.A,PLAG.LNGEXP.SUM.COVE.A'
        -- NE Demand: power, rescomm, industrial — actual + forecast (6)
        || ',FDSD.NGPWR.NE.SUM.A,FDSD.NGPWR.NE.SUM.F,FDSD.NGRSCM.NE.SUM.A,FDSD.NGRSCM.NE.SUM.F,FDSD.NGIND.NE.SUM.A,FDSD.NGIND.NE.SUM.F'
    )
    GROUP BY date, ticker
),

--------------------------------------------------
-- DAILY COMPONENTS: extract each line item per day
--------------------------------------------------
DAILY_COMPONENTS AS (
    SELECT
        date,

        -- APPALACHIAN PRODUCTION
        AVG(CASE WHEN ticker = 'FDSD.NGPR.NE.APP.A' THEN value END) AS production,

        -- FLOWS OUT: NE → MIDWEST (12 pipelines)
          COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.076.ANRSE.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.099.TCO.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.101.CROSSR.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.065.ETNG.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.375.NEX.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.093.PEPL.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.058.REX.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.337.ROV.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.073.TET24.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.073.TET30.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.054.TGP.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2MW.114.TGT.A' THEN value END), 0)
        AS to_midwest,

        -- FLOWS OUT: NE → SOUTHEAST
        COALESCE(AVG(CASE WHEN ticker = 'PLAG.NE2SE.109.TRCO.A' THEN value END), 0) AS to_southeast,

        -- FLOWS IN: MW → NE
        COALESCE(AVG(CASE WHEN ticker = 'PLAG.MW2NE.093.PEPL.A' THEN value END), 0) AS from_midwest,

        -- CANADIAN IMPORTS (CN → US, 6 pipelines)
          COALESCE(AVG(CASE WHEN ticker = 'PLAG.CN2US.081.WADD.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.CN2US.067.BRUNS.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.CN2US.027.PITTS.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.CN2US.086.NAPIER.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.CN2US.086.CORNW.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.CN2US.086.PHILIP.A' THEN value END), 0)
        AS canadian_imports,

        -- CANADIAN EXPORTS (US → CN, 3 pipelines)
          COALESCE(AVG(CASE WHEN ticker = 'PLAG.US2CN.139.CHIPP.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.US2CN.067.BVILLE.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.US2CN.054.NIAGRA.A' THEN value END), 0)
        AS canadian_exports,

        -- LNG IMPORTS
          COALESCE(AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.EVER.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.COVE.A' THEN value END), 0)
        + COALESCE(AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.NEGWY.A' THEN value END), 0)
        AS lng_imports,

        -- LNG EXPORTS
        COALESCE(AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.COVE.A' THEN value END), 0) AS lng_exports,

        -- NE DEMAND (power + rescomm + industrial; actual preferred, forecast fallback)
          COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.NE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.NE.SUM.F' THEN value END),
            0
        ) + COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.NE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.NE.SUM.F' THEN value END),
            0
        ) + COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.NE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.NE.SUM.F' THEN value END),
            0
        ) AS ne_demand

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
),

--------------------------------------------------
-- DAILY SUMMARY: computed totals + imbalance
--------------------------------------------------
DAILY_SUMMARY AS (
    SELECT
        date,

        -- Appalachian Production
        production,

        -- Flows Out of the Northeast
        to_midwest,
        to_southeast,
        to_midwest + to_southeast AS total_outflows,

        -- Flows Into the Northeast
        from_midwest,
        from_midwest AS total_inflows,

        -- Exports/Imports from Northeast
        canadian_imports,
        canadian_exports,
        lng_imports,
        lng_exports,
        (canadian_imports - canadian_exports) - (lng_exports - lng_imports) AS net_imports_exports,

        -- Northeast Demand
        ne_demand,

        -- Imbalance = Production - Outflows + Inflows + Net Import/(Export) - Demand
        production
            - (to_midwest + to_southeast)
            + from_midwest
            + ((canadian_imports - canadian_exports) - (lng_exports - lng_imports))
            - ne_demand
        AS imbalance

    FROM DAILY_COMPONENTS
),

--------------------------------------------------
-- FINAL: add daily change + prior week average
--------------------------------------------------
FINAL AS (
    SELECT
        date,

        -- ===== CORE METRICS =====
        production,
        to_midwest,
        to_southeast,
        total_outflows,
        from_midwest,
        total_inflows,
        canadian_imports,
        canadian_exports,
        lng_imports,
        lng_exports,
        net_imports_exports,
        ne_demand,
        imbalance,

        -- ===== DAILY CHANGE (vs prior day) =====
        production     - LAG(production)     OVER (ORDER BY date) AS production_daily_chg,
        total_outflows - LAG(total_outflows) OVER (ORDER BY date) AS total_outflows_daily_chg,
        total_inflows  - LAG(total_inflows)  OVER (ORDER BY date) AS total_inflows_daily_chg,
        net_imports_exports - LAG(net_imports_exports) OVER (ORDER BY date) AS net_imports_exports_daily_chg,
        ne_demand      - LAG(ne_demand)      OVER (ORDER BY date) AS ne_demand_daily_chg,
        imbalance      - LAG(imbalance)      OVER (ORDER BY date) AS imbalance_daily_chg,

        -- ===== PRIOR WEEK AVERAGE (7-day avg ending 1 day before) =====
        AVG(production)     OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS production_prior_wk,
        AVG(to_midwest)     OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS to_midwest_prior_wk,
        AVG(to_southeast)   OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS to_southeast_prior_wk,
        AVG(total_outflows)  OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS total_outflows_prior_wk,
        AVG(from_midwest)   OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS from_midwest_prior_wk,
        AVG(total_inflows)   OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS total_inflows_prior_wk,
        AVG(canadian_imports) OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS canadian_imports_prior_wk,
        AVG(canadian_exports) OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS canadian_exports_prior_wk,
        AVG(lng_imports)     OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS lng_imports_prior_wk,
        AVG(lng_exports)     OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS lng_exports_prior_wk,
        AVG(net_imports_exports) OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS net_imports_exports_prior_wk,
        AVG(ne_demand)       OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS ne_demand_prior_wk,
        AVG(imbalance)       OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS imbalance_prior_wk

    FROM DAILY_SUMMARY
)

SELECT * FROM FINAL
ORDER BY date DESC

--------------------------------------------------
-- L48 SUPPLY / DEMAND BALANCE
-- Database: Criterion PostgreSQL
-- Source: .refactor/dbt_criterion_postgresql/l48_supply_demand_v1_2026_jan_05/
-- Units: Bcf/d (source MMcf/d / 1000)
-- Grain: Daily, from 2020-01-01
--------------------------------------------------

-- Tickers:
-- FDSD.NGPR.L48.SUM.A     L48 Dry Gas Production
-- PLAG.CN2US.SUM.NET.A    Net Canadian Imports
-- PLAG.LNGIMP.SUM.US.A    LNG Imports
-- FDSD.NGPWR.US.SUM.A/F   Power Demand (Actual / Forecast)
-- FDSD.NGRSCM.US.SUM.A/F  Res/Comm Demand (Actual / Forecast)
-- FDSD.NGIND.US.SUM.A/F   Industrial Demand (Actual / Forecast)
-- FDSD.LNP.US.SUM.A       Lease & Plant Fuel
-- FDSD.PIPELOS.US.SUM.A   Pipeline Loss
-- PLAG.US2MX.SUM.NET.A    Net Mexican Exports
-- PLAG.LNGEXP.SUM.US.A    LNG Feed Gas

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'FDSD.NGPR.L48.SUM.A,PLAG.CN2US.SUM.NET.A,FDSD.NGPWR.US.SUM.A,FDSD.NGRSCM.US.SUM.A,FDSD.NGIND.US.SUM.A,FDSD.NGPWR.US.SUM.F,FDSD.NGRSCM.US.SUM.F,FDSD.NGIND.US.SUM.F,FDSD.LNP.US.SUM.A,FDSD.PIPELOS.US.SUM.A,PLAG.US2MX.SUM.NET.A,PLAG.LNGEXP.SUM.US.A,PLAG.LNGIMP.SUM.US.A'
    )
    GROUP BY date, ticker
),

DAILY AS (
    SELECT
        date,

        -- SUPPLY (Bcf/d)
        AVG(CASE WHEN ticker = 'FDSD.NGPR.L48.SUM.A' THEN value / 1000 END) AS lower_48_prod,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.SUM.NET.A' THEN value / 1000 END) AS cad_imports,

        -- DEMAND (Bcf/d) — actual preferred, forecast fallback
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.US.SUM.A' THEN value / 1000 END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.US.SUM.F' THEN value / 1000 END)
        ) AS power_demand,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.US.SUM.A' THEN value / 1000 END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.US.SUM.F' THEN value / 1000 END)
        ) AS rescomm,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.US.SUM.A' THEN value / 1000 END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.US.SUM.F' THEN value / 1000 END)
        ) AS industrial,
        AVG(CASE WHEN ticker = 'FDSD.LNP.US.SUM.A' THEN value / 1000 END) AS lease_and_plant_fuel,
        AVG(CASE WHEN ticker = 'FDSD.PIPELOS.US.SUM.A' THEN value / 1000 END) AS pipe_loss,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.SUM.NET.A' THEN value / 1000 END) AS mex_exports,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.US.A' THEN value / 1000 END) AS lng

    FROM DATA_SERIES
    GROUP BY date
),

FINAL AS (
    SELECT
        date,
        (lower_48_prod + cad_imports) AS total_supply,
        (power_demand + rescomm + industrial + lease_and_plant_fuel + pipe_loss + mex_exports + lng) AS total_demand,
        (lower_48_prod + cad_imports) - (power_demand + rescomm + industrial + lease_and_plant_fuel + pipe_loss + mex_exports + lng) AS net_balance,
        lower_48_prod,
        cad_imports,
        power_demand,
        rescomm,
        industrial,
        lease_and_plant_fuel,
        pipe_loss,
        mex_exports,
        lng
    FROM DAILY
    WHERE
        date >= '2020-01-01'::DATE
        AND date <= (CURRENT_TIMESTAMP AT TIME ZONE 'America/Denver')::DATE
)

SELECT * FROM FINAL
ORDER BY date DESC

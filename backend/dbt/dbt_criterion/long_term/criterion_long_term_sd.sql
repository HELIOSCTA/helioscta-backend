--------------------------------------------------
-- LONG-TERM SUPPLY & DEMAND FORECASTS (>14 DAYS OUT)
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog (Long Term)
-- Units: MMcf/d (source units)
-- Grain: Daily forecast horizon
-- Tickers: 40 (LTSD demand/production/trade + PLST storage forecasts)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'LTSD.NGPWR.US.SUM.F,LTSD.NGRSCM.US.SUM.F,LTSD.NGIND.US.SUM.F,LTSD.LNGEXP.SUM.US.F,LTSD.CN2US.SUM.NET.F,LTSD.US2MX.SUM.NET.F,LTSD.NGFX.L48.SUM.F,LTSD.NGRSCM.SC.SUM.F,LTSD.NGRSCM.ROX.SUM.F,LTSD.NGRSCM.SE.SUM.F,LTSD.NGRSCM.MW.SUM.F,LTSD.NGRSCM.NE.SUM.F,LTSD.NGRSCM.WST.SUM.F,LTSD.NGIND.SE.SUM.F,LTSD.NGIND.NE.SUM.F,LTSD.NGIND.MW.SUM.F,LTSD.NGIND.SC.SUM.F,LTSD.NGIND.ROX.SUM.F,LTSD.NGIND.WST.SUM.F,LTSD.NGPWR.SE.SUM.F,LTSD.NGPWR.NE.SUM.F,LTSD.NGPWR.MW.SUM.F,LTSD.NGPWR.SC.SUM.F,LTSD.NGPWR.ROX.SUM.F,LTSD.NGPWR.WST.SUM.F,LTSD.NGFX.NE.SUM.F,LTSD.NGFX.ROX.SUM.F,LTSD.NGFX.ROX.DJ.F,LTSD.NGFX.ROX.WILSTN.F,LTSD.NGFX.GOM.SUM.F,LTSD.NGFX.MW.SUM.F,LTSD.NGFX.WST.SUM.F,LTSD.NGFX.SE.SUM.F,LTSD.NGFX.SC.SUM.F,LTSD.NGFX.SC.PERM.F,LTSD.NGFX.SC.HVILL.F,LTSD.NGFX.SC.ANDRK.F,LTSD.NGFX.SC.EAGFRD.F,LTSD.NGFX.SC.FVILL.F,LTSD.NGFX.SC.OTHER.F'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- L48 DEMAND COMPONENTS
        AVG(CASE WHEN ticker = 'LTSD.NGPWR.US.SUM.F' THEN value END) AS power_demand,
        AVG(CASE WHEN ticker = 'LTSD.NGRSCM.US.SUM.F' THEN value END) AS rescomm,
        AVG(CASE WHEN ticker = 'LTSD.NGIND.US.SUM.F' THEN value END) AS industrial,
        AVG(CASE WHEN ticker = 'LTSD.LNGEXP.SUM.US.F' THEN value END) AS lng_exports,
        AVG(CASE WHEN ticker = 'LTSD.CN2US.SUM.NET.F' THEN value END) AS canadian_imports,
        AVG(CASE WHEN ticker = 'LTSD.US2MX.SUM.NET.F' THEN value END) AS mexican_exports,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.L48.SUM.F' THEN value END) AS l48_production,

        -- REGIONAL RESCOMM FORECAST
        AVG(CASE WHEN ticker = 'LTSD.NGRSCM.NE.SUM.F' THEN value END) AS rescomm_ne,
        AVG(CASE WHEN ticker = 'LTSD.NGRSCM.MW.SUM.F' THEN value END) AS rescomm_mw,
        AVG(CASE WHEN ticker = 'LTSD.NGRSCM.SC.SUM.F' THEN value END) AS rescomm_sc,
        AVG(CASE WHEN ticker = 'LTSD.NGRSCM.SE.SUM.F' THEN value END) AS rescomm_se,
        AVG(CASE WHEN ticker = 'LTSD.NGRSCM.ROX.SUM.F' THEN value END) AS rescomm_rox,
        AVG(CASE WHEN ticker = 'LTSD.NGRSCM.WST.SUM.F' THEN value END) AS rescomm_wst,

        -- REGIONAL INDUSTRIAL FORECAST
        AVG(CASE WHEN ticker = 'LTSD.NGIND.NE.SUM.F' THEN value END) AS industrial_ne,
        AVG(CASE WHEN ticker = 'LTSD.NGIND.MW.SUM.F' THEN value END) AS industrial_mw,
        AVG(CASE WHEN ticker = 'LTSD.NGIND.SC.SUM.F' THEN value END) AS industrial_sc,
        AVG(CASE WHEN ticker = 'LTSD.NGIND.SE.SUM.F' THEN value END) AS industrial_se,
        AVG(CASE WHEN ticker = 'LTSD.NGIND.ROX.SUM.F' THEN value END) AS industrial_rox,
        AVG(CASE WHEN ticker = 'LTSD.NGIND.WST.SUM.F' THEN value END) AS industrial_wst,

        -- REGIONAL POWER FORECAST
        AVG(CASE WHEN ticker = 'LTSD.NGPWR.NE.SUM.F' THEN value END) AS power_ne,
        AVG(CASE WHEN ticker = 'LTSD.NGPWR.MW.SUM.F' THEN value END) AS power_mw,
        AVG(CASE WHEN ticker = 'LTSD.NGPWR.SC.SUM.F' THEN value END) AS power_sc,
        AVG(CASE WHEN ticker = 'LTSD.NGPWR.SE.SUM.F' THEN value END) AS power_se,
        AVG(CASE WHEN ticker = 'LTSD.NGPWR.ROX.SUM.F' THEN value END) AS power_rox,
        AVG(CASE WHEN ticker = 'LTSD.NGPWR.WST.SUM.F' THEN value END) AS power_wst,

        -- REGIONAL PRODUCTION FORECAST
        AVG(CASE WHEN ticker = 'LTSD.NGFX.NE.SUM.F' THEN value END) AS prod_ne,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SC.SUM.F' THEN value END) AS prod_sc,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SC.PERM.F' THEN value END) AS prod_permian,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SC.HVILL.F' THEN value END) AS prod_haynesville,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SC.ANDRK.F' THEN value END) AS prod_anadarko,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SC.EAGFRD.F' THEN value END) AS prod_eagle_ford,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SC.FVILL.F' THEN value END) AS prod_fayetteville,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SC.OTHER.F' THEN value END) AS prod_sc_other,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.ROX.SUM.F' THEN value END) AS prod_rox,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.ROX.DJ.F' THEN value END) AS prod_dj_basin,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.ROX.WILSTN.F' THEN value END) AS prod_williston,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.GOM.SUM.F' THEN value END) AS prod_gom,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.MW.SUM.F' THEN value END) AS prod_mw,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.WST.SUM.F' THEN value END) AS prod_wst,
        AVG(CASE WHEN ticker = 'LTSD.NGFX.SE.SUM.F' THEN value END) AS prod_se

    FROM DATA_SERIES
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC

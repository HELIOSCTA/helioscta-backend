--------------------------------------------------
-- PRODUCTION BY REGION & SUB-REGION
-- Database: Criterion PostgreSQL
-- Source: .refactor/dbt_criterion_postgresql/prod_v1_2026_jan_05/
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2010-01-01
-- Tickers: 38 total
--------------------------------------------------

WITH CRITERION_PROD AS (
    SELECT DISTINCT *
    FROM data_series.fin_json_to_excel_tickers(
        'FDSD.NGPR.L48.SUM.A,FDSD.NGPR.NE.SUM.E,FDSD.NGPR.NE.APP.A,FDSD.NGPR.SC.SUM.A,FDSD.NGPR.SC.PERM.A,FDSD.NGPR.SC.HVILL.A,FDSD.NGPR.SC.HVILLLA.A,FDSD.NGPR.SC.HVILLTX.A,FDSD.NGPR.SC.EAGFRD.A,FDSD.NGPR.SC.ANDRK.A,FDSD.NGPR.SC.BARN.A,FDSD.NGPR.SC.FVILL.A,FDSD.NGPR.SC.GRANWSH.A,FDSD.NGPR.SC.KS.A,FDSD.NGPR.SC.DEEPSHLF.A,FDSD.NGPR.SC.TMS.A,FDSD.NGPR.SC.OTHERLA.A,FDSD.NGPR.SC.OTHER.E,FDSD.NGPR.ROX.SUM.A,FDSD.NGPR.ROX.WY.A,FDSD.NGPR.ROX.DJ.A,FDSD.NGPR.ROX.WILSTN.A,FDSD.NGPR.ROX.SNJUAN.A,FDSD.NGPR.ROX.SJCO.A,FDSD.NGPR.ROX.SJNM.A,FDSD.NGPR.ROX.PICEA.A,FDSD.NGPR.ROX.UT.A,FDSD.NGPR.ROX.MT.A,FDSD.NGPR.ROX.RATTOT.A,FDSD.NGPR.ROX.RATCO.A,FDSD.NGPR.ROX.RATNM.A,FDSD.NGPR.ROX.BRAVDOME.A,FDSD.NGPR.ROX.OTHER.E,FDSD.NGPR.MW.SUM.A,FDSD.NGPR.WST.SUM.A,FDSD.NGPR.SE.SUM.A,FDSD.NGPR.GOM.SUM.A'
    )
),

FINAL AS (
    SELECT
        date,

        -- L48 TOTAL
        AVG(CASE WHEN ticker = 'FDSD.NGPR.L48.SUM.A' THEN value END) AS lower_48,

        -- REGIONAL TOTALS
        AVG(CASE WHEN ticker = 'FDSD.NGPR.NE.APP.A' THEN value END) AS north_east,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.SUM.A' THEN value END) AS south_central,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.MW.SUM.A' THEN value END) AS midwest,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.SUM.A' THEN value END) AS rockies,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.WST.SUM.A' THEN value END) AS west,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SE.SUM.A' THEN value END) AS south_east,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.GOM.SUM.A' THEN value END) AS gulf_of_mexico,

        -- SOUTH CENTRAL SUB-REGIONS
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.PERM.A' THEN value END) AS permian,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.HVILL.A' THEN value END) AS haynesville,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.HVILLLA.A' THEN value END) AS haynesville_la,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.HVILLTX.A' THEN value END) AS haynesville_tx,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.EAGFRD.A' THEN value END) AS eagle_ford,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.ANDRK.A' THEN value END) AS oklahoma,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.BARN.A' THEN value END) AS barnett,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.FVILL.A' THEN value END) AS arkansas,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.GRANWSH.A' THEN value END) AS granite_wash,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.KS.A' THEN value END) AS kansas,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.DEEPSHLF.A' THEN value END) AS deep_shelf_la,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.TMS.A' THEN value END) AS tuscaloosa_marine_shale_la,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.SC.OTHERLA.A' THEN value END) AS other_la,

        -- ROCKIES SUB-REGIONS
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.WY.A' THEN value END) AS wyoming,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.DJ.A' THEN value END) AS dj_basin_co,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.WILSTN.A' THEN value END) AS williston_nd,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.SNJUAN.A' THEN value END) AS san_juan_basin,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.SJCO.A' THEN value END) AS san_juan_co,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.SJNM.A' THEN value END) AS san_juan_nm,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.PICEA.A' THEN value END) AS piceance_co,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.UT.A' THEN value END) AS utah,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.MT.A' THEN value END) AS montana,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.RATTOT.A' THEN value END) AS raton_basin,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.RATCO.A' THEN value END) AS raton_co,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.RATNM.A' THEN value END) AS raton_nm,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.BRAVDOME.A' THEN value END) AS bravo_dome,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.ROX.OTHER.E' THEN value END) AS other_rockies,

        -- NORTHEAST
        AVG(CASE WHEN ticker = 'FDSD.NGPR.NE.APP.A' THEN value END) AS appalachia

    FROM CRITERION_PROD
    WHERE date >= '2010-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC

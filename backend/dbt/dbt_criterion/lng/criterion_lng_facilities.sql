--------------------------------------------------
-- LNG FACILITIES — ALL 9 US TERMINALS + FREEPORT PIPELINE DETAIL
-- Database: Criterion PostgreSQL
-- Source: .refactor/dbt_criterion_postgresql/lng_v1_2026_jan_05/
-- Units: Bcf/d (source MMcf/d / 1000)
-- Grain: Daily by report_date, from 2020-01-01
--------------------------------------------------

WITH LNG_TOTALS AS (
    SELECT
        post_date AS report_date,
        date,

        -- L48 TOTAL
        SUM(CASE WHEN ticker IN (
            'PLAG.LNGEXP.SUM.CALCP.A', 'PLAG.LNGEXP.SUM.CAMER.A', 'PLAG.LNGEXP.IMPLIED.CCL.A',
            'PLAG.LNGEXP.SUM.COVE.A', 'PLAG.LNGEXP.SUM.ELBA.A', 'PLAG.LNGEXP.SUM.FLNG.A',
            'PLAG.LNGEXP.SUM.GP.A', 'PLAG.LNGEXP.SUM.PLQ.A', 'PLAG.LNGEXP.SUM.SPL.A'
        ) THEN value END) AS criterion_lng,

        -- INDIVIDUAL FACILITIES
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.CALCP.A' THEN value END) AS calcasieu,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.CAMER.A' THEN value END) AS cameron,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.IMPLIED.CCL.A' THEN value END) AS corpus_christi,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.COVE.A' THEN value END) AS cove_point,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.ELBA.A' THEN value END) AS elba,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.FLNG.A' THEN value END) AS freeport,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.GP.A' THEN value END) AS golden_pass,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.PLQ.A' THEN value END) AS plaquemines,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.SPL.A' THEN value END) AS sabine,

        -- CORPUS CHRISTI DETAIL
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.IMPLIED.CCL.A' THEN value END) AS cc_implied_flows,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.CCL.A' THEN value END) AS cc_feed_gas,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.ADCC.CCL.A' THEN value END) AS cc_intrastate_receipts

    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.LNGEXP.CALCP.CAPOFF.F,PLAG.LNGEXP.CALCP.DESCAP.F,PLAG.LNGEXP.CALCP.MAINTCAP.F,PLAG.LNGEXP.CALCP.SEASCAP.F,PLAG.LNGEXP.SUM.CALCP.A,PLAG.LNGEXP.CAMER.CAPOFF.F,PLAG.LNGEXP.CAMER.DESCAP.F,PLAG.LNGEXP.CAMER.MAINTCAP.F,PLAG.LNGEXP.CAMER.SEASCAP.F,PLAG.LNGEXP.SUM.CAMER.A,PLAG.LNGEXP.ADCC.CCL.A,PLAG.LNGEXP.CCL.CAPOFF.F,PLAG.LNGEXP.CCL.DESCAP.F,PLAG.LNGEXP.CCL.MAINTCAP.F,PLAG.LNGEXP.CCL.SEASCAP.F,PLAG.LNGEXP.IMPLIED.CCL.A,PLAG.LNGEXP.SUM.CCL.A,PLAG.LNGEXP.COVE.CAPOFF.F,PLAG.LNGEXP.COVE.DESCAP.F,PLAG.LNGEXP.COVE.MAINTCAP.F,PLAG.LNGEXP.COVE.SEASCAP.F,PLAG.LNGEXP.SUM.COVE.A,PLAG.LNGIMP.SUM.COVE.A,PLAG.LNGEXP.ELBA.CAPOFF.F,PLAG.LNGEXP.ELBA.DESCAP.F,PLAG.LNGEXP.ELBA.MAINTCAP.F,PLAG.LNGEXP.ELBA.SEASCAP.F,PLAG.LNGEXP.SUM.ELBA.A,PLAG.LNGIMP.SUM.ELBA.A,PLAG.LNGEXP.FLNG.CAPOFF.F,PLAG.LNGEXP.FLNG.DESCAP.F,PLAG.LNGEXP.FLNG.MAINTCAP.F,PLAG.LNGEXP.FLNG.SEASCAP.F,PLAG.LNGEXP.SUM.FLNG.A,PLAG.LNGEXP.PLQ.CAPOFF.F,PLAG.LNGEXP.PLQ.DESCAP.F,PLAG.LNGEXP.PLQ.MAINTCAP.F,PLAG.LNGEXP.PLQ.SEASCAP.F,PLAG.LNGEXP.SUM.PLQ.A,PLAG.LNGEXP.SPL.CAPOFF.F,PLAG.LNGEXP.SPL.DESCAP.F,PLAG.LNGEXP.SPL.MAINTCAP.F,PLAG.LNGEXP.SPL.SEASCAP.F,PLAG.LNGEXP.SUM.SPL.A,PLAG.LNGEXP.GP.CAPOFF.F,PLAG.LNGEXP.GP.DESCAP.F,PLAG.LNGEXP.GP.MAINTCAP.F,PLAG.LNGEXP.GP.SEASCAP.F,PLAG.LNGEXP.SUM.GP.A'
    )
    WHERE date >= '2020-01-01' AND date <= CURRENT_DATE
    GROUP BY post_date, date
),

FREEPORT_NOMS AS (
    SELECT
        meta.ticker,
        meta.rec_del_sign,
        noms.eff_gas_day,
        noms.scheduled_quantity * meta.rec_del_sign AS scheduled_quantity_sign_adj
    FROM pipelines.nomination_points noms
    INNER JOIN pipelines.metadata meta ON meta.metadata_id = noms.metadata_id
    WHERE meta.ticker IN ('PLNM.073.79999.2') AND noms.eff_gas_day >= '2020-01-01'
),

FREEPORT_INTRASTATE AS (
    SELECT
        eff_gas_day,
        ABS(AVG(CASE WHEN ticker = 'PLNM.073.79999.2' THEN scheduled_quantity_sign_adj / 1000 END)) AS freeport_intrastate
    FROM FREEPORT_NOMS
    GROUP BY eff_gas_day
),

FINAL AS (
    SELECT
        lng.report_date,
        lng.date,
        lng.criterion_lng / 1000 AS criterion_lng,
        lng.calcasieu / 1000 AS calcasieu,
        lng.cameron / 1000 AS cameron,
        lng.corpus_christi / 1000 AS corpus_christi,
        lng.cove_point / 1000 AS cove_point,
        lng.elba / 1000 AS elba,
        lng.freeport / 1000 AS freeport,
        lng.golden_pass / 1000 AS golden_pass,
        lng.plaquemines / 1000 AS plaquemines,
        lng.sabine / 1000 AS sabine,
        lng.cc_implied_flows / 1000 AS cc_implied_flows,
        lng.cc_feed_gas / 1000 AS cc_feed_gas,
        lng.cc_intrastate_receipts / 1000 AS cc_intrastate_receipts,
        lng.freeport / 1000 AS freeport_implied_flows,
        (lng.freeport - COALESCE(fp.freeport_intrastate, 0)) / 1000 AS freeport_feed_gas,
        COALESCE(fp.freeport_intrastate, 0) / 1000 AS freeport_intrastate_receipts
    FROM LNG_TOTALS lng
    LEFT JOIN FREEPORT_INTRASTATE fp ON lng.date = fp.eff_gas_day
)

SELECT * FROM FINAL
ORDER BY report_date DESC, date DESC

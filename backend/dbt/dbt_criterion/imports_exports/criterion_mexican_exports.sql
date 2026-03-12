--------------------------------------------------
-- US EXPORTS TO MEXICO (BY PIPELINE / EXIT POINT)
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog (History & Short Term)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 25 (aggregate + individual pipelines)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.US2MX.SUM.NET.A,PLAG.US2MX.358.HPLARG.A,PLAG.US2MX.373.HPLNUE.A,PLAG.US2MX.207.KMTX.A,PLAG.US2MX.358.KMRAM.A,PLAG.US2MX.358.NETMX.A,PLAG.US2MX.054.TGPRIO.A,PLAG.US2MX.054.TGPPMX.A,PLAG.US2MX.358.TETARG.A,PLAG.US2MX.379.VCP.A,PLAG.US2MX.345.CMNCH.A,PLAG.US2MX.042.EPCH.A,PLAG.US2MX.222.OKTX.A,PLAG.US2MX.283.RoadR.A,PLAG.US2MX.344.TPECOS.A,PLAG.US2MX.WTG.ACUNA.A,PLAG.US2MX.WTG.PIEDR.A,PLAG.US2MX.042.EPAGUA.A,PLAG.US2MX.042.EPCOB.A,PLAG.US2MX.042.EPGNI.A,PLAG.US2MX.042.EPPMX.A,PLAG.US2MX.051.SIAGUA.A,PLAG.US2MX.082.NBAJA.A,PLAG.US2MX.SDGE.CALEX.A,PLAG.US2MX.053.SOCAL.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- NET TOTAL
        AVG(CASE WHEN ticker = 'PLAG.US2MX.SUM.NET.A' THEN value END) AS net_mexican_exports,

        -- SOUTH TEXAS / GULF COAST
        AVG(CASE WHEN ticker = 'PLAG.US2MX.358.HPLARG.A' THEN value END) AS houston_pipe_arguelles,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.373.HPLNUE.A' THEN value END) AS howard_energy_nuevo_era,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.207.KMTX.A' THEN value END) AS kinder_morgan_texas,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.358.KMRAM.A' THEN value END) AS km_border_ramones,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.358.NETMX.A' THEN value END) AS net_mexico_noreste,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.054.TGPRIO.A' THEN value END) AS tgp_gasoducto_del_rio,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.054.TGPPMX.A' THEN value END) AS tgp_pemex,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.358.TETARG.A' THEN value END) AS texas_eastern_arguelles,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.379.VCP.A' THEN value END) AS sur_de_texas,

        -- WEST TEXAS / PERMIAN
        AVG(CASE WHEN ticker = 'PLAG.US2MX.345.CMNCH.A' THEN value END) AS comanche_trail_san_isidro,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.222.OKTX.A' THEN value END) AS oktex_gas_natural,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.283.RoadR.A' THEN value END) AS roadrunner_tarahumara,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.344.TPECOS.A' THEN value END) AS trans_pecos_ojinaga,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.WTG.ACUNA.A' THEN value END) AS wtg_acuna,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.WTG.PIEDR.A' THEN value END) AS wtg_piedras_negras,

        -- EL PASO SYSTEM
        AVG(CASE WHEN ticker = 'PLAG.US2MX.042.EPCH.A' THEN value END) AS el_paso_chihuahua,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.042.EPAGUA.A' THEN value END) AS el_paso_aguaprieta,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.042.EPCOB.A' THEN value END) AS el_paso_cobre,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.042.EPGNI.A' THEN value END) AS el_paso_gas_natural,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.042.EPPMX.A' THEN value END) AS el_paso_pemex,

        -- ARIZONA / CALIFORNIA
        AVG(CASE WHEN ticker = 'PLAG.US2MX.051.SIAGUA.A' THEN value END) AS sierreta_aguaprieta,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.082.NBAJA.A' THEN value END) AS north_baja_rosarito,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.SDGE.CALEX.A' THEN value END) AS sdge_calexico,
        AVG(CASE WHEN ticker = 'PLAG.US2MX.053.SOCAL.A' THEN value END) AS socal_baja

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC

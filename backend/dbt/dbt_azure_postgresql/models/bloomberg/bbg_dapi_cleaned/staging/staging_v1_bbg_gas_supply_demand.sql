{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- LATEST REVISION ONLY
-- data_type is always PX_LAST
---------------------------

WITH LATEST AS (
    SELECT
        date,
        security,
        value
    FROM {{ ref('staging_v1_bbg_historical_with_tickers') }}
    WHERE revision = max_revision
),

---------------------------
-- PIVOT: LONG → WIDE
-- One row per date, one column per security
---------------------------

PIVOTED AS (
    SELECT
        date,

        -- production
        MAX(CASE WHEN security = 'GSPRODUS Index' THEN value END)::NUMERIC AS production,
        MAX(CASE WHEN security = 'GSPRDAPP Index' THEN value END)::NUMERIC AS appalachia,
        MAX(CASE WHEN security = 'GSPRDBAK Index' THEN value END)::NUMERIC AS bakken,
        MAX(CASE WHEN security = 'GSPRDGLF Index' THEN value END)::NUMERIC AS gulf,
        MAX(CASE WHEN security = 'GSPRDHNV Index' THEN value END)::NUMERIC AS haynesville,
        MAX(CASE WHEN security = 'GSPRDMCN Index' THEN value END)::NUMERIC AS midcon,
        MAX(CASE WHEN security = 'GSPRDMEA Index' THEN value END)::NUMERIC AS mw_east,
        MAX(CASE WHEN security = 'GSPRDMWE Index' THEN value END)::NUMERIC AS mw_west,
        MAX(CASE WHEN security = 'GSPRDNEA Index' THEN value END)::NUMERIC AS north_east,
        MAX(CASE WHEN security = 'GSPRDNEN Index' THEN value END)::NUMERIC AS new_england,
        MAX(CASE WHEN security = 'GSPRDPNW Index' THEN value END)::NUMERIC AS pac_nw,
        MAX(CASE WHEN security = 'GSPRDPRM Index' THEN value END)::NUMERIC AS permian,
        MAX(CASE WHEN security = 'GSPRDROC Index' THEN value END)::NUMERIC AS rockies,
        MAX(CASE WHEN security = 'GSPRDSEA Index' THEN value END)::NUMERIC AS southeast,
        MAX(CASE WHEN security = 'GSPRDSWE Index' THEN value END)::NUMERIC AS southwest,

        -- canada imports
        MAX(CASE WHEN security = 'GSFLCTOT Index' THEN value END)::NUMERIC AS cad_imports,
        MAX(CASE WHEN security = 'GSFLCANE Index' THEN value END)::NUMERIC AS cad_to_north_east,
        MAX(CASE WHEN security = 'GSFLCAEN Index' THEN value END)::NUMERIC AS cad_to_new_england,
        MAX(CASE WHEN security = 'GSFLCAWW Index' THEN value END)::NUMERIC AS cad_to_midwest,
        MAX(CASE WHEN security = 'GSFLCAMW Index' THEN value END)::NUMERIC AS cad_to_michigan,
        MAX(CASE WHEN security = 'GSFLCABA Index' THEN value END)::NUMERIC AS cad_to_bakken,
        MAX(CASE WHEN security = 'GSFLCAPN Index' THEN value END)::NUMERIC AS cad_to_pac_nw,

        -- demand
        MAX(CASE WHEN security = 'GSDEDUSP Index' THEN value END)::NUMERIC AS power_burn,
        MAX(CASE WHEN security = 'GSDEDUSI Index' THEN value END)::NUMERIC AS industrial,
        MAX(CASE WHEN security = 'GSDEDUSR Index' THEN value END)::NUMERIC AS rescom,
        MAX(CASE WHEN security = 'GSDEDUSF Index' THEN value END)::NUMERIC AS plant_fuel,
        MAX(CASE WHEN security = 'GSDEDUSD Index' THEN value END)::NUMERIC AS pipe_loss,

        -- mexico exports
        MAX(CASE WHEN security = 'GSFLUSMX Index' THEN value END)::NUMERIC AS mexico_exports,
        MAX(CASE WHEN security = 'GSFLMNMX Index' THEN value END)::NUMERIC AS gulf_to_mexico,
        MAX(CASE WHEN security = 'GSFLPAMX Index' THEN value END)::NUMERIC AS sw_to_mexico,
        MAX(CASE WHEN security = 'GSFLSCMX Index' THEN value END)::NUMERIC AS cali_to_mexico,

        -- lng (raw values; ABS applied in next CTE)
        MAX(CASE WHEN security = 'GSLIQTOT Index' THEN value END)::NUMERIC AS lng_raw,
        MAX(CASE WHEN security = 'GSLIQSPI Index' THEN value END)::NUMERIC AS sabine_raw,
        MAX(CASE WHEN security = 'GSLIQCAM Index' THEN value END)::NUMERIC AS cameron_raw,
        MAX(CASE WHEN security = 'GSLIQCCH Index' THEN value END)::NUMERIC AS corpus_raw,
        MAX(CASE WHEN security = 'GSLIQCOV Index' THEN value END)::NUMERIC AS cove_point_raw,
        MAX(CASE WHEN security = 'GSLIQELB Index' THEN value END)::NUMERIC AS elba_raw,
        MAX(CASE WHEN security = 'GSLIQFPT Index' THEN value END)::NUMERIC AS freeport_raw,
        MAX(CASE WHEN security = 'GSLIQCLC Index' THEN value END)::NUMERIC AS calcasieu_raw,
        MAX(CASE WHEN security = 'GSLIQPLQ Index' THEN value END)::NUMERIC AS plaquemines_raw,

        -- storage
        MAX(CASE WHEN security = 'GSFLDUSS Index' THEN value END)::NUMERIC AS storage,
        MAX(CASE WHEN security = 'GSTMSMPL Index' THEN value END)::NUMERIC AS salt,

        -- weather
        MAX(CASE WHEN security = 'HISTCNEC Index' THEN value END)::NUMERIC AS elec_cdd,
        MAX(CASE WHEN security = 'HISTCNEH Index' THEN value END)::NUMERIC AS elec_hdd,
        MAX(CASE WHEN security = 'HISTCNGC Index' THEN value END)::NUMERIC AS gas_cdd,
        MAX(CASE WHEN security = 'HISTCNGH Index' THEN value END)::NUMERIC AS gas_hdd,

        -- spot prices
        MAX(CASE WHEN security = 'NGNEZN5S BNGC Index' THEN value END)::NUMERIC AS z5_spot,
        MAX(CASE WHEN security = 'NGNEAGNG BNGC Index' THEN value END)::NUMERIC AS m3_spot,
        MAX(CASE WHEN security = 'NGGCTR85 BNGC Index' THEN value END)::NUMERIC AS st85_spot,
        MAX(CASE WHEN security = 'NGUSHHUB BNGC Index' THEN value END)::NUMERIC AS henry_spot,
        MAX(CASE WHEN security = 'NGGCHOUS BNGC Index' THEN value END)::NUMERIC AS hsc_spot,
        MAX(CASE WHEN security = 'NGTXOASI BNGC Index' THEN value END)::NUMERIC AS waha_spot,
        MAX(CASE WHEN security = 'NAGANGPL BNGC Index' THEN value END)::NUMERIC AS chicago_spot,
        MAX(CASE WHEN security = 'NGRMNWRM BNGC Index' THEN value END)::NUMERIC AS rox_spot,
        MAX(CASE WHEN security = 'NGWCPGSP BNGC Index' THEN value END)::NUMERIC AS malin_spot,
        MAX(CASE WHEN security = 'NGWCPGNE BNGC Index' THEN value END)::NUMERIC AS pge_spot,
        MAX(CASE WHEN security = 'NGWCSCAL BNGC Index' THEN value END)::NUMERIC AS socal_border_spot,
        MAX(CASE WHEN security = 'NGWCSCCG BNGC Index' THEN value END)::NUMERIC AS socal_city_spot,
        MAX(CASE WHEN security = 'NGCGBOST BNGC Index' THEN value END)::NUMERIC AS agt_spot,
        MAX(CASE WHEN security = 'NGCGNYNY Index' THEN value END)::NUMERIC AS nyc_spot

    FROM LATEST
    GROUP BY date
),

---------------------------
-- LNG: ABS (Bloomberg reports as negative)
---------------------------

DAILY AS (
    SELECT
        date,

        -- supply
        (COALESCE(production, 0) + COALESCE(cad_imports, 0))::NUMERIC AS total_supply,

        -- production
        production,
        appalachia,
        bakken,
        gulf,
        haynesville,
        midcon,
        mw_east,
        mw_west,
        north_east,
        new_england,
        pac_nw,
        permian,
        rockies,
        southeast,
        southwest,

        -- canada imports
        cad_imports,
        cad_to_north_east,
        cad_to_new_england,
        cad_to_midwest,
        cad_to_michigan,
        cad_to_bakken,
        cad_to_pac_nw,

        -- demand
        (COALESCE(power_burn, 0) + COALESCE(industrial, 0) + COALESCE(rescom, 0) + COALESCE(plant_fuel, 0) + COALESCE(pipe_loss, 0))::NUMERIC AS lower_48_demand,
        power_burn,
        industrial,
        rescom,
        plant_fuel,
        pipe_loss,

        -- mexico exports
        mexico_exports,
        gulf_to_mexico,
        sw_to_mexico,
        cali_to_mexico,

        -- lng (absolute values)
        ABS(lng_raw)::NUMERIC AS lng,
        ABS(sabine_raw)::NUMERIC AS sabine,
        ABS(cameron_raw)::NUMERIC AS cameron,
        ABS(corpus_raw)::NUMERIC AS corpus,
        ABS(cove_point_raw)::NUMERIC AS cove_point,
        ABS(elba_raw)::NUMERIC AS elba,
        ABS(freeport_raw)::NUMERIC AS freeport,
        ABS(calcasieu_raw)::NUMERIC AS calcasieu,
        ABS(plaquemines_raw)::NUMERIC AS plaquemines,

        -- storage
        storage,
        salt,

        -- weather
        elec_cdd,
        elec_hdd,
        gas_cdd,
        gas_hdd,

        -- spot prices
        z5_spot,
        m3_spot,
        st85_spot,
        henry_spot,
        hsc_spot,
        waha_spot,
        chicago_spot,
        rox_spot,
        malin_spot,
        pge_spot,
        socal_border_spot,
        socal_city_spot,
        agt_spot,
        nyc_spot

    FROM PIVOTED
),

---------------------------
-- TOTAL DEMAND / IMPLIED STORAGE / BALANCING
---------------------------

TOTAL_DEMAND AS (
    SELECT
        *,
        (COALESCE(lower_48_demand, 0) + COALESCE(mexico_exports, 0) + COALESCE(lng, 0))::NUMERIC AS total_demand
    FROM DAILY
),

IMPLIED_STORAGE AS (
    SELECT
        *,
        (total_supply - total_demand)::NUMERIC AS implied_storage
    FROM TOTAL_DEMAND
),

BALANCING_ITEM AS (
    SELECT
        *,
        (implied_storage - COALESCE(storage, 0))::NUMERIC AS balancing_item
    FROM IMPLIED_STORAGE
),

FINAL AS (
    SELECT * FROM BALANCING_ITEM
)

SELECT * FROM FINAL

--------------------------------------------------
-- PIPELINE REGIONAL MAPPINGS
-- Database: Criterion Snowflake (Production)
-- Source: pipelines.metadata joined to pipelines.regions via state
-- Description: Explore how pipeline nomination points map to
--              EIA regions, states, pipelines, and storage facilities.
--              Use this to discover available points and their
--              regional classifications before querying flows.
--------------------------------------------------

-- 1. FULL REGIONAL MAPPING CATALOGUE
--    Every metadata point joined to its EIA region via state

SELECT
    meta.metadata_id,
    meta.ticker,
    meta.pipeline_name,
    meta.loc_name,
    meta.category_short,
    meta.sub_category_desc,
    meta.rec_del_sign,
    meta.state_name,
    meta.state_abb,
    rgn.eia_ng_regions,
    rgn.eia_padd_regions,
    meta.storage_name,
    meta.storage_calc_flag,
    meta.basin_name,
    meta.connecting_pipeline,
    meta.connecting_entity
FROM pipelines.metadata meta
LEFT JOIN pipelines.regions rgn ON meta.state_abb = rgn.state_abb
ORDER BY rgn.eia_ng_regions, meta.pipeline_name, meta.ticker

-- FILTER EXAMPLES (add WHERE before ORDER BY):
-- WHERE rgn.eia_ng_regions = 'East'              -- Single EIA region
-- WHERE rgn.eia_ng_regions LIKE '%South%'         -- South Central / Southeast
-- WHERE meta.pipeline_name ILIKE '%transco%'      -- Specific pipeline
-- WHERE meta.state_name = 'Texas'                 -- Specific state
-- WHERE meta.storage_name IS NOT NULL             -- Only storage-mapped points
-- WHERE meta.storage_calc_flag IS NOT NULL         -- Only storage calc points
-- WHERE meta.ticker LIKE 'PLNM.%'                -- Pipeline nomination tickers only
-- WHERE meta.ticker LIKE 'PLST.%'                -- Pipeline storage tickers only
-- WHERE meta.basin_name IS NOT NULL               -- Only points with basin assignment

;

-- 2. REGION SUMMARY
--    Count of mapped points per EIA region + state

-- SELECT
--     rgn.eia_ng_regions,
--     rgn.eia_padd_regions,
--     meta.state_name,
--     meta.state_abb,
--     COUNT(DISTINCT meta.metadata_id) AS point_count,
--     COUNT(DISTINCT meta.pipeline_name) AS pipeline_count,
--     COUNT(DISTINCT meta.storage_name) AS storage_facility_count
-- FROM pipelines.metadata meta
-- LEFT JOIN pipelines.regions rgn ON meta.state_abb = rgn.state_abb
-- GROUP BY rgn.eia_ng_regions, rgn.eia_padd_regions, meta.state_name, meta.state_abb
-- ORDER BY rgn.eia_ng_regions, meta.state_name

;

-- 3. PIPELINE INVENTORY BY REGION
--    Which pipelines operate in each region

-- SELECT
--     rgn.eia_ng_regions,
--     meta.pipeline_name,
--     COUNT(DISTINCT meta.metadata_id) AS point_count,
--     COUNT(DISTINCT meta.state_abb) AS state_count,
--     ARRAY_AGG(DISTINCT meta.state_abb) AS states
-- FROM pipelines.metadata meta
-- LEFT JOIN pipelines.regions rgn ON meta.state_abb = rgn.state_abb
-- WHERE meta.pipeline_name IS NOT NULL
-- GROUP BY rgn.eia_ng_regions, meta.pipeline_name
-- ORDER BY rgn.eia_ng_regions, meta.pipeline_name

;

-- 4. STORAGE FACILITIES BY REGION
--    Storage points with their calc flags and parent pipelines

-- SELECT
--     rgn.eia_ng_regions,
--     meta.state_name,
--     meta.storage_name,
--     meta.storage_calc_flag,
--     meta.pipeline_name,
--     meta.ticker,
--     meta.loc_name,
--     meta.rec_del_sign
-- FROM pipelines.metadata meta
-- LEFT JOIN pipelines.regions rgn ON meta.state_abb = rgn.state_abb
-- WHERE meta.storage_calc_flag IS NOT NULL
-- ORDER BY rgn.eia_ng_regions, meta.storage_name, meta.ticker

;

-- 5. DISTINCT VALUES (schema introspection helpers)

-- Uncomment any of these to see all unique values for a column:
-- SELECT DISTINCT eia_ng_regions FROM pipelines.regions ORDER BY 1;
-- SELECT DISTINCT eia_padd_regions FROM pipelines.regions ORDER BY 1;
-- SELECT DISTINCT state_name, state_abb FROM pipelines.regions ORDER BY 1;
-- SELECT DISTINCT pipeline_name FROM pipelines.metadata WHERE pipeline_name IS NOT NULL ORDER BY 1;
-- SELECT DISTINCT storage_name FROM pipelines.metadata WHERE storage_name IS NOT NULL ORDER BY 1;
-- SELECT DISTINCT storage_calc_flag FROM pipelines.metadata WHERE storage_calc_flag IS NOT NULL ORDER BY 1;
-- SELECT DISTINCT category_short FROM pipelines.metadata ORDER BY 1;
-- SELECT DISTINCT sub_category_desc FROM pipelines.metadata ORDER BY 1;
-- SELECT DISTINCT basin_name FROM pipelines.metadata WHERE basin_name IS NOT NULL ORDER BY 1;

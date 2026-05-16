{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- 5-Minute RT LMPs aggregated to hourly
-- Grain: 1 row per date x hour x hub
-- Captures intra-hour spike severity masked by hourly averages
-- (e.g., HE22 3/24: hourly avg $161 but 5-min intervals likely $300-500+)
---------------------------

WITH FIVE_MIN AS (
    SELECT * FROM {{ ref('source_v1_pjm_unverified_five_min_lmps') }}
),

HOURLY AS (
    SELECT
        date
        ,hour_ending
        ,hub

        -- 5-min statistics per hour
        ,AVG(five_min_rt_lmp) AS rt_lmp_avg
        ,MAX(five_min_rt_lmp) AS rt_lmp_max
        ,MIN(five_min_rt_lmp) AS rt_lmp_min
        ,(MAX(five_min_rt_lmp) - MIN(five_min_rt_lmp)) AS rt_lmp_range
        ,COUNT(*) AS intervals_in_hour

        -- Spike detection: max vs avg ratio
        ,CASE
            WHEN AVG(five_min_rt_lmp) > 0
            THEN MAX(five_min_rt_lmp) / AVG(five_min_rt_lmp)
            ELSE NULL
        END AS spike_ratio

    FROM FIVE_MIN
    GROUP BY date, hour_ending, hub
)

SELECT
    date + (hour_ending || ' hours')::interval AS datetime
    ,*
FROM HOURLY
ORDER BY date DESC, hour_ending DESC, hub

--------------------------------------------------
-- DATE DIMENSION (NERC holidays, EIA storage weeks, seasonal flags)
-- Database: Criterion PostgreSQL
-- Source: .refactor/dbt_criterion_postgresql/l48_supply_demand_v1_2026_jan_05/ (Snowflake->PG port)
-- Grain: Daily, from 2010-01-01 through 15 days ahead
-- Note: Excludes Feb 29 (leap day)
--------------------------------------------------

WITH NERC_HOLIDAYS AS (
    SELECT nerc_holiday::DATE AS nerc_holiday
    FROM (
        VALUES
            ('2014-01-01'), ('2014-05-26'), ('2014-07-04'), ('2014-09-01'), ('2014-11-27'), ('2014-12-25'),
            ('2015-01-01'), ('2015-05-25'), ('2015-07-04'), ('2015-09-07'), ('2015-11-26'), ('2015-12-25'),
            ('2016-01-01'), ('2016-05-30'), ('2016-07-04'), ('2016-09-05'), ('2016-11-24'), ('2016-12-26'),
            ('2017-01-02'), ('2017-05-29'), ('2017-07-04'), ('2017-09-04'), ('2017-11-23'), ('2017-12-25'),
            ('2018-01-01'), ('2018-05-28'), ('2018-07-04'), ('2018-09-03'), ('2018-11-22'), ('2018-12-25'),
            ('2019-01-01'), ('2019-05-27'), ('2019-07-04'), ('2019-09-02'), ('2019-11-28'), ('2019-12-25'),
            ('2020-01-01'), ('2020-05-25'), ('2020-07-04'), ('2020-09-07'), ('2020-11-26'), ('2020-12-25'),
            ('2021-01-01'), ('2021-05-31'), ('2021-07-05'), ('2021-09-06'), ('2021-11-25'), ('2021-12-25'),
            ('2022-01-01'), ('2022-05-30'), ('2022-07-04'), ('2022-09-05'), ('2022-11-24'), ('2022-12-26'),
            ('2023-01-02'), ('2023-05-29'), ('2023-07-04'), ('2023-09-04'), ('2023-11-23'), ('2023-12-25'),
            ('2024-01-01'), ('2024-05-27'), ('2024-07-04'), ('2024-09-02'), ('2024-11-28'), ('2024-12-25'),
            ('2025-01-01'), ('2025-05-26'), ('2025-07-04'), ('2025-09-01'), ('2025-11-27'), ('2025-12-25'),
            ('2026-01-01'), ('2026-05-25'), ('2026-07-04'), ('2026-09-07'), ('2026-11-26'), ('2026-12-25'),
            ('2027-01-01'), ('2027-05-31'), ('2027-07-05'), ('2027-09-06'), ('2027-11-25'), ('2027-12-25'),
            ('2028-01-01'), ('2028-05-29'), ('2028-07-04'), ('2028-09-04'), ('2028-11-23'), ('2028-12-25')
    ) AS t(nerc_holiday)
),

DAYS AS (
    SELECT (DATE '2010-01-01' + gs * INTERVAL '1 day')::DATE AS date
    FROM generate_series(0, 9999) AS gs
    WHERE (DATE '2010-01-01' + gs * INTERVAL '1 day')::DATE
        <= ((CURRENT_TIMESTAMP AT TIME ZONE 'America/Denver')::DATE + 15)
),

FINAL AS (
    SELECT
        date,
        EXTRACT(YEAR FROM date)::INTEGER AS year,
        EXTRACT(YEAR FROM date)::TEXT || '-' || EXTRACT(MONTH FROM date)::TEXT AS year_month,
        EXTRACT(MONTH FROM date)::INTEGER AS month,
        TO_CHAR(date, 'MM-DD') AS mm_dd,
        (EXTRACT(YEAR FROM CURRENT_DATE)::TEXT || '-' || TO_CHAR(date, 'MM-DD'))::DATE AS mm_dd_cy,
        CASE
            WHEN EXTRACT(MONTH FROM date) IN (11, 12, 1, 2, 3) THEN 'WINTER'
            WHEN EXTRACT(MONTH FROM date) IN (4, 5, 6, 7, 8, 9, 10) THEN 'SUMMER'
        END AS summer_winter,
        CASE
            WHEN EXTRACT(MONTH FROM date) IN (1, 2, 3) THEN 'XH-' || RIGHT(EXTRACT(YEAR FROM date)::TEXT, 2)
            WHEN EXTRACT(MONTH FROM date) IN (11, 12) THEN 'XH-' || RIGHT((EXTRACT(YEAR FROM date) + 1)::TEXT, 2)
            WHEN EXTRACT(MONTH FROM date) IN (4, 5, 6, 7, 8, 9, 10) THEN 'JV-' || RIGHT(EXTRACT(YEAR FROM date)::TEXT, 2)
        END AS summer_winter_yyyy,
        (date + (
            CASE
                WHEN EXTRACT(DOW FROM date)::INTEGER >= 5
                THEN 12 - EXTRACT(DOW FROM date)::INTEGER
                ELSE 5 - EXTRACT(DOW FROM date)::INTEGER
            END
        ) * INTERVAL '1 day')::DATE AS eia_storage_week,
        EXTRACT(WEEK FROM (date + (
            CASE
                WHEN EXTRACT(DOW FROM date)::INTEGER >= 5
                THEN 12 - EXTRACT(DOW FROM date)::INTEGER
                ELSE 5 - EXTRACT(DOW FROM date)::INTEGER
            END
        ) * INTERVAL '1 day')::DATE)::INTEGER AS eia_storage_week_number,
        TRIM(TO_CHAR(date, 'Day')) AS day_of_week,
        EXTRACT(DOW FROM date)::INTEGER AS day_of_week_number,
        CASE WHEN EXTRACT(DOW FROM date) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend,
        CASE WHEN date IN (SELECT nerc_holiday FROM NERC_HOLIDAYS) THEN 1 ELSE 0 END AS is_nerc_holiday
    FROM DAYS
    WHERE TO_CHAR(date, 'MM-DD') != '02-29'
)

SELECT * FROM FINAL
ORDER BY date

-- Insert into the target table 'actors_history_scd'
INSERT INTO ChrisTaulbee.actors_history_scd

-- Common Table Expression (CTE) to select records from the previous year
WITH previous_year_cte AS (
    SELECT
        *
    FROM
        ChrisTaulbee.actors_history_scd
    WHERE YEAR(end_date) = (SELECT MAX(YEAR(end_date)) FROM ChrisTaulbee.actors_history_scd) -- Use a subquery to get the latest year
),

-- CTE to select records from the current year
current_year_cte AS (
    SELECT 
        *
    FROM
        ChrisTaulbee.actors
    WHERE
        current_year = (SELECT MAX(YEAR(end_date)) FROM ChrisTaulbee.actors_history_scd) + 1 -- Use a subquery to get the latest year + 1
),

-- CTE to combine previous and current year data, identifying changes
combined AS (
    SELECT
        COALESCE(py.actor_id, cy.actor_id) AS actor_id,
        (SELECT MAX(YEAR(end_date)) FROM ChrisTaulbee.actors_history_scd) + 1 AS latest_year,
        py.is_active AS is_active_last_year,
        cy.is_active AS is_active_this_year,
        py.quality_class AS quality_class_last_year,
        cy.quality_class AS quality_class_this_year,
        COALESCE(py.start_date, DATE(CONCAT(cy.current_year, '-01-01'))) AS start_date,
        COALESCE(py.end_date, DATE(CONCAT(cy.current_year, '-12-31'))) AS end_date,
        CASE
            WHEN py.is_active <> cy.is_active THEN 1
            WHEN py.quality_class <> cy.quality_class THEN 1
            ELSE 0
        END AS did_change
    FROM
        previous_year_cte py
    FULL OUTER JOIN
        current_year_cte cy ON py.actor_id = cy.actor_id
),

-- CTE to handle changes and create an array of changes
changes AS (
    SELECT 
        actor_id,
        latest_year,
        CASE
            WHEN did_change = 0 THEN ARRAY[
                CAST(ROW(is_active_last_year, start_date, end_date + INTERVAL '1 year') AS ROW(is_active BOOLEAN, start_date DATE, end_date DATE))
            ]
            WHEN did_change = 1 THEN ARRAY[
                CAST(ROW(is_active_last_year, start_date, end_date) AS ROW(is_active BOOLEAN, start_date DATE, end_date DATE)), 
                CAST(ROW(is_active_this_year, start_date, end_date) AS ROW(is_active BOOLEAN, start_date DATE, end_date DATE))
            ]
            ELSE ARRAY[
                CAST(ROW(is_active_this_year, start_date, end_date) AS ROW(is_active BOOLEAN, start_date DATE, end_date DATE))
            ]
        END AS change_array
    FROM 
        combined
)

-- Final selection and unnesting of the change array
SELECT
    actor_id,
    arr.is_active,
    arr.start_date,
    arr.end_date,
    latest_year
FROM
    changes
CROSS JOIN UNNEST(change_array) AS t(arr)

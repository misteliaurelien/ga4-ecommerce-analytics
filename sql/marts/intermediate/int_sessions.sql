CREATE OR REPLACE TABLE

    `ga4-e-commerce-performance.ga4_analytics.int_sessions`

PARTITION BY session_date

CLUSTER BY acquisition_channel, device_category

AS

SELECT

    -- Session identifiers

    user_pseudo_id,

    ga_session_id,

    -- Session timing

    MIN(event_date) AS session_date,

    MIN(event_timestamp) AS session_start_timestamp,

    MAX(event_timestamp) AS session_end_timestamp,

    MAX(

        IF(event_name = 'session_start', 1, 0)

    ) AS has_session_start,

    -- User acquisition

    MIN(acquisition_date) AS acquisition_date,

    DATE_TRUNC(

        MIN(acquisition_date),

        ISOWEEK

    ) AS acquisition_week,

    -- New vs Returning

    CASE

        WHEN MIN(acquisition_date) IS NULL

            THEN 'Unknown'

        WHEN MIN(event_date) = MIN(acquisition_date)

            THEN 'New'

        WHEN MIN(event_date) > MIN(acquisition_date)

            THEN 'Returning'

        ELSE 'Invalid'

    END AS segment,

    -- Dimensions

    ANY_VALUE(acquisition_channel) AS acquisition_channel,

    ANY_VALUE(device_category) AS device_category,

    ANY_VALUE(country) AS country,

    -- Engagement

    MAX(

        COALESCE(session_engaged, 0)

    ) AS is_engaged,

    SUM(

        COALESCE(engagement_time_msec, 0)

    ) AS engagement_time_msec,

    -- Event volume

    COUNT(*) AS event_count,

    COUNTIF(

        event_name = 'page_view'

    ) AS page_views,

    COUNTIF(

        event_name = 'view_item'

    ) AS product_views,

    -- Funnel flags

    MAX(

        IF(event_name = 'view_item', 1, 0)

    ) AS has_product_view,

    MAX(

        IF(event_name = 'add_to_cart', 1, 0)

    ) AS has_add_to_cart,

    MAX(

        IF(event_name = 'begin_checkout', 1, 0)

    ) AS has_checkout,

    MAX(

        IF(event_name = 'purchase', 1, 0)

    ) AS has_purchase,

    -- Ecommerce

    COUNTIF(

        event_name = 'purchase'

    ) AS purchases,

    SUM(

        IF(

            event_name = 'purchase',

            COALESCE(purchase_revenue, 0),

            0

        )

    ) AS revenue

FROM `ga4-e-commerce-performance.ga4_analytics.int_events_enriched`

WHERE ga_session_id IS NOT NULL

GROUP BY

    user_pseudo_id,

    ga_session_id;

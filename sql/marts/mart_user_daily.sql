CREATE OR REPLACE TABLE

    `ga4-e-commerce-performance.ga4_analytics.mart_user_daily`

PARTITION BY dates

CLUSTER BY segment, acquisition_channel, device_category

AS

SELECT

    -- Grain

    session_date AS dates,

    user_pseudo_id,

    device_category,

    -- User/session classification

    segment,

    acquisition_channel,

    -- Activity

    COUNT(*) AS sessions,

    COUNTIF(

        is_engaged = 1

    ) AS engaged_sessions,

    SUM(engagement_time_msec) AS engagement_time_msec,

    SUM(page_views) AS page_views,

    SUM(product_views) AS product_views,

    -- Funnel behavior

    COUNTIF(

        has_add_to_cart = 1

    ) AS add_to_cart_sessions,

    COUNTIF(

        has_checkout = 1

    ) AS checkout_sessions,

    COUNTIF(

        has_purchase = 1

    ) AS purchase_sessions,

    -- Ecommerce

    SUM(purchases) AS purchases,

    SUM(revenue) AS revenue

FROM `ga4-e-commerce-performance.ga4_analytics.int_sessions`

WHERE segment != 'Invalid'

GROUP BY

    session_date,

    user_pseudo_id,

    device_category,

    segment,

    acquisition_channel;

CREATE OR REPLACE TABLE

    `ga4-e-commerce-performance.ga4_analytics.mart_funnel_daily`

PARTITION BY dates

CLUSTER BY acquisition_channel, device_category, segment

AS

WITH product_view AS (

    -- First product view in each session

    SELECT

        user_pseudo_id,

        ga_session_id,

        MIN(event_timestamp) AS product_view_ts

    FROM `ga4-e-commerce-performance.ga4_analytics.int_events_enriched`

    WHERE event_name = 'view_item'

      AND ga_session_id IS NOT NULL

    GROUP BY

        user_pseudo_id,

        ga_session_id

),

add_to_cart AS (

    -- First add_to_cart AFTER the qualifying product view

    SELECT

        e.user_pseudo_id,

        e.ga_session_id,

        MIN(e.event_timestamp) AS add_to_cart_ts

    FROM `ga4-e-commerce-performance.ga4_analytics.int_events_enriched` e

    INNER JOIN product_view p

        ON e.user_pseudo_id = p.user_pseudo_id

       AND e.ga_session_id = p.ga_session_id

       AND e.event_timestamp >= p.product_view_ts

    WHERE e.event_name = 'add_to_cart'

    GROUP BY

        e.user_pseudo_id,

        e.ga_session_id

),

checkout AS (

    -- First checkout AFTER the qualifying add_to_cart

    SELECT

        e.user_pseudo_id,

        e.ga_session_id,

        MIN(e.event_timestamp) AS checkout_ts

    FROM `ga4-e-commerce-performance.ga4_analytics.int_events_enriched` e

    INNER JOIN add_to_cart c

        ON e.user_pseudo_id = c.user_pseudo_id

       AND e.ga_session_id = c.ga_session_id

       AND e.event_timestamp >= c.add_to_cart_ts

    WHERE e.event_name = 'begin_checkout'

    GROUP BY

        e.user_pseudo_id,

        e.ga_session_id

),

purchase AS (

    -- First purchase AFTER the qualifying checkout

    SELECT

        e.user_pseudo_id,

        e.ga_session_id,

        MIN(e.event_timestamp) AS purchase_ts

    FROM `ga4-e-commerce-performance.ga4_analytics.int_events_enriched` e

    INNER JOIN checkout c

        ON e.user_pseudo_id = c.user_pseudo_id

       AND e.ga_session_id = c.ga_session_id

       AND e.event_timestamp >= c.checkout_ts

    WHERE e.event_name = 'purchase'

    GROUP BY

        e.user_pseudo_id,

        e.ga_session_id

),

session_funnel AS (

    SELECT

        s.session_date AS dates,

        s.user_pseudo_id,

        s.ga_session_id,

        s.segment,

        s.acquisition_channel,

        s.device_category,

        -- Sequential funnel

        1 AS step_session,

        IF(p.product_view_ts IS NOT NULL, 1, 0)

            AS step_product_view,

        IF(c.add_to_cart_ts IS NOT NULL, 1, 0)

            AS step_add_to_cart,

        IF(ch.checkout_ts IS NOT NULL, 1, 0)

            AS step_checkout,

        IF(pu.purchase_ts IS NOT NULL, 1, 0)

            AS step_purchase,

        -- Actual purchase behavior, regardless of funnel path

        s.has_purchase,

        s.purchases,

        s.revenue

    FROM `ga4-e-commerce-performance.ga4_analytics.int_sessions` s

    LEFT JOIN product_view p

        ON s.user_pseudo_id = p.user_pseudo_id

       AND s.ga_session_id = p.ga_session_id

    LEFT JOIN add_to_cart c

        ON s.user_pseudo_id = c.user_pseudo_id

       AND s.ga_session_id = c.ga_session_id

    LEFT JOIN checkout ch

        ON s.user_pseudo_id = ch.user_pseudo_id

       AND s.ga_session_id = ch.ga_session_id

    LEFT JOIN purchase pu

        ON s.user_pseudo_id = pu.user_pseudo_id

       AND s.ga_session_id = pu.ga_session_id

    WHERE s.segment != 'Invalid'

)

SELECT

    dates,

    segment,

    acquisition_channel,

    device_category,

    -- Funnel volumes

    SUM(step_session) AS sessions,

    SUM(step_product_view) AS product_view_sessions,

    SUM(step_add_to_cart) AS add_to_cart_sessions,

    SUM(step_checkout) AS checkout_sessions,

    SUM(step_purchase) AS standard_funnel_purchase_sessions,

    -- All purchasing sessions

    COUNTIF(has_purchase = 1) AS total_purchase_sessions,

    -- Purchased without completing our standard sequence

    COUNTIF(

        has_purchase = 1

        AND step_purchase = 0

    ) AS outside_standard_funnel_purchase_sessions,

    -- Step conversion rates

    SAFE_DIVIDE(

        SUM(step_product_view),

        SUM(step_session)

    ) AS session_to_product_rate,

    SAFE_DIVIDE(

        SUM(step_add_to_cart),

        SUM(step_product_view)

    ) AS product_to_cart_rate,

    SAFE_DIVIDE(

        SUM(step_checkout),

        SUM(step_add_to_cart)

    ) AS cart_to_checkout_rate,

    SAFE_DIVIDE(

        SUM(step_purchase),

        SUM(step_checkout)

    ) AS checkout_to_purchase_rate,

    -- Full standard journey

    SAFE_DIVIDE(

        SUM(step_purchase),

        SUM(step_session)

    ) AS standard_funnel_conversion,

    -- Share of purchasing sessions outside standard journey

    SAFE_DIVIDE(

        COUNTIF(

            has_purchase = 1

            AND step_purchase = 0

        ),

        COUNTIF(has_purchase = 1)

    ) AS outside_standard_funnel_purchase_rate,

    -- Business reconciliation

    SUM(purchases) AS purchases,

    SUM(revenue) AS revenue

FROM session_funnel

GROUP BY

    dates,

    segment,

    acquisition_channel,

    device_category;

CREATE OR REPLACE TABLE

    `ga4-e-commerce-performance.ga4_analytics.int_users`

CLUSTER BY acquisition_channel

AS

SELECT

    user_pseudo_id,

    -- Acquisition

    MIN(acquisition_date) AS acquisition_date,

    DATE_TRUNC(

        MIN(acquisition_date),

        ISOWEEK

    ) AS acquisition_week,

    ANY_VALUE(acquisition_channel) AS acquisition_channel,

    ANY_VALUE(acquisition_source) AS acquisition_source,

    ANY_VALUE(acquisition_medium) AS acquisition_medium,

    -- Observability

    MIN(event_date) AS first_observed_date,

    MAX(event_date) AS last_observed_date,

    -- Useful lifecycle fields

    COUNT(DISTINCT ga_session_id) AS lifetime_sessions,

    MIN(

        IF(event_name = 'purchase', event_date, NULL)

    ) AS first_purchase_date,

    COUNTIF(event_name = 'purchase') AS lifetime_purchases,

    SUM(

        IF(

            event_name = 'purchase',

            COALESCE(purchase_revenue, 0),

            0

        )

    ) AS lifetime_revenue

FROM `ga4-e-commerce-performance.ga4_analytics.int_events_enriched`

GROUP BY

    user_pseudo_id;

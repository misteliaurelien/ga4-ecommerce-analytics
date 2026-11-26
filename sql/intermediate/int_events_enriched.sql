CREATE OR REPLACE TABLE

    `ga4-e-commerce-performance.ga4_analytics.int_events_enriched`

PARTITION BY event_date

CLUSTER BY event_name, acquisition_channel, device_category

AS

SELECT

    -- Event identifiers / timing

    PARSE_DATE('%Y%m%d', a.event_date) AS event_date,

    TIMESTAMP_MICROS(a.event_timestamp) AS event_timestamp,

    a.event_timestamp AS event_timestamp_raw,

    a.event_name,

    a.event_bundle_sequence_id,

    -- User

    a.user_pseudo_id,

    DATE(TIMESTAMP_MICROS(a.user_first_touch_timestamp)) AS acquisition_date,

    -- Acquisition

    CASE

        WHEN a.traffic_source.medium = 'cpc' THEN 'Paid'

        WHEN a.traffic_source.medium = 'organic' THEN 'Organic'

        WHEN a.traffic_source.medium = 'referral' THEN 'Referral'

        WHEN a.traffic_source.medium = '(none)' THEN 'Direct'

        WHEN a.traffic_source.medium = '(data deleted)' THEN 'Unknown'

        ELSE 'Other'

    END AS acquisition_channel,

    a.traffic_source.source AS acquisition_source,

    a.traffic_source.medium AS acquisition_medium,

    a.traffic_source.name AS acquisition_campaign,

    -- Device / geography

    a.device.category AS device_category,

    a.geo.country AS country,

    -- Session parameters

    MAX(

        IF(

            ep.key = 'ga_session_id',

            ep.value.int_value,

            NULL

        )

    ) AS ga_session_id,

    MAX(

        IF(

            ep.key = 'session_engaged',

            COALESCE(

                SAFE_CAST(ep.value.string_value AS INT64),

                ep.value.int_value

            ),

            NULL

        )

    ) AS session_engaged,

    MAX(

        IF(

            ep.key = 'engagement_time_msec',

            ep.value.int_value,

            NULL

        )

    ) AS engagement_time_msec,

    -- Ecommerce

    a.ecommerce.transaction_id,

    a.ecommerce.purchase_revenue,

    a.ecommerce.total_item_quantity

FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events\_*` AS a

LEFT JOIN UNNEST(a.event_params) AS ep

WHERE

    a.user_pseudo_id IS NOT NULL

GROUP BY

    a.event_date,

    a.event_timestamp,

    a.event_name,

    a.event_bundle_sequence_id,

    a.user_pseudo_id,

    a.user_first_touch_timestamp,

    a.traffic_source.source,

    a.traffic_source.medium,

    a.traffic_source.name,

    a.device.category,

    a.geo.country,

    a.ecommerce.transaction_id,

    a.ecommerce.purchase_revenue,

    a.ecommerce.total_item_quantity;

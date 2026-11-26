CREATE OR REPLACE VIEW
  `ga4-e-commerce-performance.ga4_analytics.viz_purchase_paths` AS

SELECT
  dates,
  segment,
  acquisition_channel,
  device_category,
  'Standard Funnel' AS purchase_path,
  standard_funnel_purchase_sessions AS purchase_sessions
FROM `ga4-e-commerce-performance.ga4_analytics.mart_funnel_daily`

UNION ALL

SELECT
  dates,
  segment,
  acquisition_channel,
  device_category,
  'Outside Standard Funnel' AS purchase_path,
  outside_standard_funnel_purchase_sessions AS purchase_sessions
FROM `ga4-e-commerce-performance.ga4_analytics.mart_funnel_daily`;

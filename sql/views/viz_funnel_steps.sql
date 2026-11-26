CREATE OR REPLACE VIEW
  `ga4-e-commerce-performance.ga4_analytics.viz_funnel_steps` AS

SELECT
  dates,
  segment,
  acquisition_channel,
  device_category,
  step_order,
  funnel_step,
  sessions_count
FROM
  `ga4-e-commerce-performance.ga4_analytics.mart_funnel_daily`
UNPIVOT (
  sessions_count FOR funnel_step IN (
    sessions AS 'Session',
    product_view_sessions AS 'Product View',
    add_to_cart_sessions AS 'Add to Cart',
    checkout_sessions AS 'Checkout',
    standard_funnel_purchase_sessions AS 'Purchase'
  )
)
CROSS JOIN UNNEST([
  CASE funnel_step
    WHEN 'Session' THEN 1
    WHEN 'Product View' THEN 2
    WHEN 'Add to Cart' THEN 3
    WHEN 'Checkout' THEN 4
    WHEN 'Purchase' THEN 5
  END
]) AS step_order;

-- Run after rebuilding the mart. All checks should return 0 failures.
WITH m AS (
  SELECT *,
    LAG(cumulative_sessions) OVER (PARTITION BY acquisition_week, acquisition_channel ORDER BY week_number) AS previous_cumulative_sessions,
    LAG(cumulative_purchases) OVER (PARTITION BY acquisition_week, acquisition_channel ORDER BY week_number) AS previous_cumulative_purchases,
    LAG(cumulative_revenue) OVER (PARTITION BY acquisition_week, acquisition_channel ORDER BY week_number) AS previous_cumulative_revenue
  FROM `ga4-e-commerce-performance.ga4_analytics.mart_acquisition_cohort_weekly`
)
SELECT
  COUNTIF(acquired_users <= 0) AS invalid_cohort_sizes,
  COUNTIF(active_users > acquired_users) AS active_exceeds_acquired,
  COUNTIF(week_number < 0) AS negative_weeks,
  COUNTIF(week_number > 0 AND cumulative_sessions != previous_cumulative_sessions + sessions) AS sessions_cumulative_mismatch,
  COUNTIF(week_number > 0 AND cumulative_purchases != previous_cumulative_purchases + purchases) AS purchases_cumulative_mismatch,
  COUNTIF(week_number > 0 AND ABS(cumulative_revenue - ROUND(previous_cumulative_revenue + revenue, 2)) > 0.02) AS revenue_cumulative_mismatch,
  COUNT(*) - COUNT(DISTINCT TO_JSON_STRING(STRUCT(acquisition_week, acquisition_channel, week_number))) AS duplicate_grain_rows
FROM m;

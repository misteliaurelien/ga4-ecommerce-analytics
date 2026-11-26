-- Reconstructed V2 from the project history and original V1 notes.
-- Grain: acquisition_week x acquisition_channel x week_number.
-- Cohort population: first-touch dates within the observable GA4 sample.
-- IMPORTANT: acquired_users repeats for each week_number; do not sum across weeks.

CREATE OR REPLACE TABLE `ga4-e-commerce-performance.ga4_analytics.mart_acquisition_cohort_weekly`
PARTITION BY acquisition_week
CLUSTER BY acquisition_channel
AS
WITH eligible_users AS (
  SELECT
    user_pseudo_id,
    acquisition_date,
    acquisition_week,
    acquisition_channel
  FROM `ga4-e-commerce-performance.ga4_analytics.int_users`
  WHERE acquisition_date BETWEEN DATE '2020-11-01' AND DATE '2021-01-31'
),
cohort_sizes AS (
  SELECT
    acquisition_week,
    acquisition_channel,
    COUNT(DISTINCT user_pseudo_id) AS acquired_users
  FROM eligible_users
  GROUP BY 1, 2
),
user_weekly_activity AS (
  SELECT
    u.acquisition_week,
    u.acquisition_channel,
    u.user_pseudo_id,
    DATE_DIFF(DATE_TRUNC(s.session_date, ISOWEEK), u.acquisition_week, ISOWEEK) AS week_number,
    s.ga_session_id,
    s.is_engaged,
    s.has_purchase,
    s.purchases,
    s.revenue
  FROM eligible_users u
  JOIN `ga4-e-commerce-performance.ga4_analytics.int_sessions` s
    ON s.user_pseudo_id = u.user_pseudo_id
   AND s.session_date >= u.acquisition_date
   AND s.session_date <= DATE '2021-01-31'
  WHERE s.segment != 'Invalid'
),
weekly_metrics AS (
  SELECT
    acquisition_week,
    acquisition_channel,
    week_number,
    COUNT(DISTINCT user_pseudo_id) AS active_users,
    COUNT(*) AS sessions,
    COUNTIF(is_engaged = 1) AS engaged_sessions,
    COUNT(DISTINCT IF(has_purchase = 1, user_pseudo_id, NULL)) AS purchasers,
    SUM(purchases) AS purchases,
    SUM(revenue) AS revenue
  FROM user_weekly_activity
  WHERE week_number >= 0
  GROUP BY 1, 2, 3
),
cohort_weeks AS (
  SELECT
    c.acquisition_week,
    c.acquisition_channel,
    c.acquired_users,
    week_number
  FROM cohort_sizes c
  CROSS JOIN UNNEST(
    GENERATE_ARRAY(
      0,
      DATE_DIFF(DATE_TRUNC(DATE '2021-01-31', ISOWEEK), c.acquisition_week, ISOWEEK)
    )
  ) AS week_number
),
cohort_metrics AS (
  SELECT
    c.acquisition_week,
    c.acquisition_channel,
    c.week_number,
    c.acquired_users,
    COALESCE(w.active_users, 0) AS active_users,
    COALESCE(w.sessions, 0) AS sessions,
    COALESCE(w.engaged_sessions, 0) AS engaged_sessions,
    COALESCE(w.purchasers, 0) AS purchasers,
    COALESCE(w.purchases, 0) AS purchases,
    COALESCE(w.revenue, 0) AS revenue
  FROM cohort_weeks c
  LEFT JOIN weekly_metrics w
    USING (acquisition_week, acquisition_channel, week_number)
)
SELECT
  acquisition_week,
  acquisition_channel,
  week_number,
  acquired_users,
  active_users,
  sessions,
  engaged_sessions,
  purchasers,
  purchases,
  ROUND(revenue, 2) AS revenue,
  SAFE_DIVIDE(active_users, acquired_users) AS active_user_rate,
  SAFE_DIVIDE(sessions, acquired_users) AS sessions_per_acquired_user,
  SAFE_DIVIDE(engaged_sessions, sessions) AS engagement_rate,
  SAFE_DIVIDE(purchasers, acquired_users) AS weekly_purchase_conversion,
  SAFE_DIVIDE(revenue, acquired_users) AS revenue_per_acquired_user,
  SUM(sessions) OVER cohort_window AS cumulative_sessions,
  SUM(purchases) OVER cohort_window AS cumulative_purchases,
  ROUND(SUM(revenue) OVER cohort_window, 2) AS cumulative_revenue
FROM cohort_metrics
WINDOW cohort_window AS (
  PARTITION BY acquisition_week, acquisition_channel
  ORDER BY week_number
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
);

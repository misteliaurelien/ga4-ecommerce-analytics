CREATE OR REPLACE VIEW
  `ga4-e-commerce-performance.ga4_analytics.viz_acquisition_kpis` AS

WITH cohort_kpis AS (
  SELECT
    acquisition_week,
    acquisition_channel,
    MAX(IF(week_number = 0, acquired_users, NULL)) AS acquired_users,
    MAX(IF(
      week_number = 1
      AND acquisition_week <= DATE '2021-01-18',
      active_users, NULL
    )) AS w1_active_users,
    MAX(IF(
      week_number = 2
      AND acquisition_week <= DATE '2021-01-11',
      active_users, NULL
    )) AS w2_active_users,
    MAX(IF(
      week_number = 1
      AND acquisition_week <= DATE '2021-01-18',
      acquired_users, NULL
    )) AS w1_eligible_users,
    MAX(IF(
      week_number = 2
      AND acquisition_week <= DATE '2021-01-11',
      acquired_users, NULL
    )) AS w2_eligible_users,
    SUM(sessions) AS total_sessions,
    SUM(purchases) AS total_purchases,
    SUM(engaged_sessions) AS total_engaged_sessions,
    SUM(revenue) AS total_revenue
  FROM `ga4-e-commerce-performance.ga4_analytics.mart_acquisition_cohort_weekly`
  GROUP BY 1, 2
),

cumulative_activation AS (
  SELECT
    u.acquisition_week,
    u.acquisition_channel,
    COUNT(DISTINCT IF(
      DATE_DIFF(
        DATE_TRUNC(s.session_date, ISOWEEK),
        u.acquisition_week,
        WEEK(MONDAY)
      ) IN (1, 2),
      u.user_pseudo_id,
      NULL
    )) AS w2_cumulative_active_users
  FROM `ga4-e-commerce-performance.ga4_analytics.int_users` u
  LEFT JOIN `ga4-e-commerce-performance.ga4_analytics.int_sessions` s
    ON u.user_pseudo_id = s.user_pseudo_id
  WHERE u.acquisition_date BETWEEN DATE '2020-11-01'
                               AND DATE '2021-01-31'
    AND u.acquisition_week <= DATE '2021-01-11'
  GROUP BY 1, 2
)

SELECT
  k.*,
  IF(
    k.w2_eligible_users IS NOT NULL,
    COALESCE(a.w2_cumulative_active_users, 0),
    NULL
  ) AS w2_cumulative_active_users
FROM cohort_kpis k
LEFT JOIN cumulative_activation a
  ON k.acquisition_week = a.acquisition_week
 AND k.acquisition_channel = a.acquisition_channel;

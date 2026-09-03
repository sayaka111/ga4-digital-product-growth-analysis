-- analysis result extract.
-- Every section declares its grain and exposes real denominators.

WITH channel AS (
  SELECT
    first_touch_source,
    first_touch_medium,
    SUM(new_users) AS new_users,
    SUM(activated_users) AS activated_users,
    SUM(feature_24h_eligible_users) AS feature_24h_eligible_users,
    SUM(meaningful_activated_users_24h) AS meaningful_activated_users_24h,
    SUM(d7_eligible_users) AS d7_eligible_users,
    SUM(d7_product_returned_users) AS d7_returned_users,
    SUM(d30_eligible_users) AS d30_eligible_users,
    SUM(d30_product_returned_users) AS d30_returned_users,
    SUM(future_30d_eligible_users) AS future_30d_eligible_users,
    SUM(users_converted_24h_to_30d) AS converted_users,
    SUM(positive_recognized_value_users_24h_to_30d) AS positive_value_users,
    SUM(recognized_revenue_24h_to_30d_usd) AS recognized_revenue_usd,
    LOGICAL_OR(is_probable_self_referral) AS is_probable_self_referral
  FROM `growth_core.acquisition_channel_quality`
  GROUP BY 1, 2
),
funnel_device AS (
  SELECT COALESCE(device_category, '(missing)') AS dimension,
    COUNTIF(ordered_core_value) AS core_sessions,
    COUNTIF(ordered_high_intent) AS high_intent_sessions,
    COUNTIF(ordered_begin_checkout) AS checkout_sessions,
    COUNTIF(ordered_conversion) AS conversion_sessions
  FROM `growth_core.conversion_funnel_session`
  GROUP BY 1
),
funnel_source AS (
  SELECT CONCAT(COALESCE(first_touch_source, '(missing)'), ' / ', COALESCE(first_touch_medium, '(missing)')) AS dimension,
    COUNTIF(ordered_core_value) AS core_sessions,
    COUNTIF(ordered_high_intent) AS high_intent_sessions,
    COUNTIF(ordered_begin_checkout) AS checkout_sessions,
    COUNTIF(ordered_conversion) AS conversion_sessions
  FROM `growth_core.conversion_funnel_session`
  WHERE NOT (
    LOWER(COALESCE(first_touch_source, '')) = 'shop.googlemerchandisestore.com'
    AND LOWER(COALESCE(first_touch_medium, '')) = 'referral'
  )
  GROUP BY 1
),
funnel_calendar_month AS (
  SELECT FORMAT_DATE('%Y-%m', session_date) AS dimension,
    COUNTIF(ordered_core_value) AS core_sessions,
    COUNTIF(ordered_high_intent) AS high_intent_sessions,
    COUNTIF(ordered_begin_checkout) AS checkout_sessions,
    COUNTIF(ordered_conversion) AS conversion_sessions
  FROM `growth_core.conversion_funnel_session`
  GROUP BY 1
),
funnel_acquisition_cohort_first_session AS (
  SELECT FORMAT_DATE('%Y-%m', u.cohort_date) AS dimension,
    COUNTIF(f.ordered_core_value) AS core_sessions,
    COUNTIF(f.ordered_high_intent) AS high_intent_sessions,
    COUNTIF(f.ordered_begin_checkout) AS checkout_sessions,
    COUNTIF(f.ordered_conversion) AS conversion_sessions
  FROM `growth_core.conversion_funnel_session` AS f
  INNER JOIN `growth_core.user_first_session` AS u
    ON f.session_key = u.first_session_key
  GROUP BY 1
),
activation_long AS (
  SELECT '核心体验：首会话核心价值' AS activation_level,
    TRUE AS feature_eligible, activated_primary AS reached,
    d7_core_behavior_returned, future_30d_eligible, converted_24h_to_30d
  FROM `growth_core.early_behavior_features`
  UNION ALL
  SELECT '有意义激活：24小时内至少2次核心价值',
    feature_24h_eligible, meaningful_activation_24h,
    d7_core_behavior_returned, future_30d_eligible, converted_24h_to_30d
  FROM `growth_core.early_behavior_features`
  UNION ALL
  SELECT '深度意向：24小时内高意向行为',
    feature_24h_eligible, high_intent_events_24h > 0,
    d7_core_behavior_returned, future_30d_eligible, converted_24h_to_30d
  FROM `growth_core.early_behavior_features`
),
activation_summary AS (
  SELECT
    activation_level,
    COUNTIF(feature_eligible AND reached) AS reached_users,
    COUNTIF(feature_eligible) AS feature_eligible_users,
    COUNTIF(feature_eligible AND reached AND d7_core_behavior_returned IS NOT NULL) AS d7_eligible_users,
    COUNTIF(feature_eligible AND reached AND d7_core_behavior_returned) AS d7_core_returned_users,
    COUNTIF(feature_eligible AND reached AND future_30d_eligible) AS future_eligible_reached_users,
    COUNTIF(feature_eligible AND reached AND converted_24h_to_30d) AS converted_users
  FROM activation_long
  GROUP BY 1
),
value_long AS (
  SELECT '首次会话完成激活' AS feature_name, TRUE AS feature_eligible,
    activated_primary AS exposed, future_30d_eligible,
    recognized_revenue_24h_to_30d_usd AS revenue
  FROM `growth_core.early_behavior_features`
  UNION ALL
  SELECT '24小时内完成深度激活', feature_24h_eligible,
    high_intent_events_24h > 0, future_30d_eligible, recognized_revenue_24h_to_30d_usd
  FROM `growth_core.early_behavior_features`
  UNION ALL
  SELECT '24小时内再次开启会话', feature_24h_eligible,
    returned_within_24h, future_30d_eligible, recognized_revenue_24h_to_30d_usd
  FROM `growth_core.early_behavior_features`
  UNION ALL
  SELECT '24小时内重复完成核心价值行为', feature_24h_eligible,
    meaningful_activation_24h, future_30d_eligible, recognized_revenue_24h_to_30d_usd
  FROM `growth_core.early_behavior_features`
),
value_summary AS (
  SELECT
    feature_name,
    exposed,
    COUNTIF(feature_eligible AND future_30d_eligible AND revenue > 0) AS positive_value_users,
    AVG(IF(feature_eligible AND future_30d_eligible AND revenue > 0, revenue, NULL)) AS mean_positive_revenue,
    APPROX_QUANTILES(IF(feature_eligible AND future_30d_eligible AND revenue > 0, revenue, NULL), 100 IGNORE NULLS)[OFFSET(50)] AS median_positive_revenue,
    APPROX_QUANTILES(IF(feature_eligible AND future_30d_eligible AND revenue > 0, revenue, NULL), 100 IGNORE NULLS)[OFFSET(75)] AS p75_positive_revenue,
    APPROX_QUANTILES(IF(feature_eligible AND future_30d_eligible AND revenue > 0, revenue, NULL), 100 IGNORE NULLS)[OFFSET(90)] AS p90_positive_revenue
  FROM value_long
  WHERE exposed IS NOT NULL
  GROUP BY 1, 2
),
lifecycle_denominators AS (
  SELECT COUNT(*) AS all_users,
    COUNTIF(days_observed >= 8) AS eligible_8d_users,
    COUNTIF(days_observed >= 30) AS eligible_30d_users
  FROM `growth_core.lifecycle_user_snapshot`
)
SELECT 'lifecycle' AS section, activity_status AS dimension_1, CAST(NULL AS STRING) AS dimension_2,
  CAST(COUNT(*) AS FLOAT64) AS n,
  CAST(CASE
    WHEN activity_status = 'Dormant' THEN ANY_VALUE(d.eligible_30d_users)
    WHEN activity_status = 'Cooling' THEN ANY_VALUE(d.eligible_8d_users)
    ELSE ANY_VALUE(d.all_users)
  END AS FLOAT64) AS eligible_n,
  SAFE_DIVIDE(COUNT(*), CASE
    WHEN activity_status = 'Dormant' THEN ANY_VALUE(d.eligible_30d_users)
    WHEN activity_status = 'Cooling' THEN ANY_VALUE(d.eligible_8d_users)
    ELSE ANY_VALUE(d.all_users)
  END) AS metric_1,
  CAST(NULL AS FLOAT64) AS metric_2, CAST(NULL AS FLOAT64) AS metric_3,
  CAST(NULL AS FLOAT64) AS metric_4, CAST(NULL AS FLOAT64) AS metric_5,
  'metric_1=status share using its applicable maturity denominator' AS notes
FROM `growth_core.lifecycle_user_snapshot`
CROSS JOIN lifecycle_denominators AS d
GROUP BY activity_status

UNION ALL
SELECT 'channel', first_touch_source, first_touch_medium,
  new_users, d7_eligible_users,
  SAFE_DIVIDE(activated_users, new_users),
  SAFE_DIVIDE(d7_returned_users, d7_eligible_users),
  SAFE_DIVIDE(d30_returned_users, d30_eligible_users),
  SAFE_DIVIDE(converted_users, future_30d_eligible_users),
  SAFE_DIVIDE(recognized_revenue_usd, future_30d_eligible_users),
  FORMAT('feature24_eligible=%d; d30_eligible=%d; future30_eligible=%d', feature_24h_eligible_users, d30_eligible_users, future_30d_eligible_users)
FROM channel
WHERE NOT is_probable_self_referral
  AND new_users >= 500 AND d7_eligible_users >= 500 AND future_30d_eligible_users >= 500

UNION ALL
SELECT 'self_referral_audit', first_touch_source, first_touch_medium,
  new_users, future_30d_eligible_users,
  SAFE_DIVIDE(activated_users, new_users),
  SAFE_DIVIDE(d7_returned_users, d7_eligible_users),
  SAFE_DIVIDE(d30_returned_users, d30_eligible_users),
  SAFE_DIVIDE(converted_users, future_30d_eligible_users),
  SAFE_DIVIDE(recognized_revenue_usd, future_30d_eligible_users),
  FORMAT('probable self-referral; positive-value users=%d; retained for attribution audit only', positive_value_users)
FROM channel
WHERE is_probable_self_referral

UNION ALL
SELECT 'funnel_device', dimension, NULL, core_sessions, core_sessions,
  SAFE_DIVIDE(high_intent_sessions, core_sessions),
  SAFE_DIVIDE(checkout_sessions, high_intent_sessions),
  SAFE_DIVIDE(conversion_sessions, checkout_sessions),
  SAFE_DIVIDE(conversion_sessions, core_sessions), CAST(NULL AS FLOAT64),
  'core sessions are base scale; each step uses the prior stage; metric_4 uses core sessions'
FROM funnel_device WHERE core_sessions >= 500

UNION ALL
SELECT 'funnel_source', dimension, NULL, core_sessions, core_sessions,
  SAFE_DIVIDE(high_intent_sessions, core_sessions),
  SAFE_DIVIDE(checkout_sessions, high_intent_sessions),
  SAFE_DIVIDE(conversion_sessions, checkout_sessions),
  SAFE_DIVIDE(conversion_sessions, core_sessions), CAST(NULL AS FLOAT64),
  'full-session funnel; minimum 500 core sessions'
FROM funnel_source WHERE core_sessions >= 500

UNION ALL
SELECT 'funnel_calendar_month', dimension, NULL, core_sessions, core_sessions,
  SAFE_DIVIDE(high_intent_sessions, core_sessions),
  SAFE_DIVIDE(checkout_sessions, high_intent_sessions),
  SAFE_DIVIDE(conversion_sessions, checkout_sessions),
  SAFE_DIVIDE(conversion_sessions, core_sessions), CAST(NULL AS FLOAT64),
  'all sessions grouped by the actual GA4 reporting-date calendar month'
FROM funnel_calendar_month WHERE core_sessions >= 500

UNION ALL
SELECT 'funnel_acquisition_cohort_first_session', dimension, NULL, core_sessions, core_sessions,
  SAFE_DIVIDE(high_intent_sessions, core_sessions),
  SAFE_DIVIDE(checkout_sessions, high_intent_sessions),
  SAFE_DIVIDE(conversion_sessions, checkout_sessions),
  SAFE_DIVIDE(conversion_sessions, core_sessions), CAST(NULL AS FLOAT64),
  'one first session per acquired user; equal lifecycle-relative window'
FROM funnel_acquisition_cohort_first_session WHERE core_sessions >= 500

UNION ALL
SELECT 'activation_level', activation_level, NULL,
  reached_users, feature_eligible_users,
  SAFE_DIVIDE(reached_users, feature_eligible_users),
  SAFE_DIVIDE(d7_core_returned_users, d7_eligible_users),
  SAFE_DIVIDE(converted_users, future_eligible_reached_users),
  CAST(NULL AS FLOAT64), CAST(NULL AS FLOAT64),
  FORMAT('D7 reached eligible=%d; fixed-future reached eligible=%d', d7_eligible_users, future_eligible_reached_users)
FROM activation_summary

UNION ALL
SELECT 'positive_value', feature_name, IF(exposed, '发生组', '未发生组'),
  positive_value_users, positive_value_users,
  mean_positive_revenue, median_positive_revenue,
  p75_positive_revenue, p90_positive_revenue, CAST(NULL AS FLOAT64),
  'positive-value users only; fixed [24h,30d) window; amounts in USD'
FROM value_summary

ORDER BY section, n DESC, dimension_1, dimension_2;

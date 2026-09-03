-- Grain: one published KPI.
-- Each row exposes its numerator, denominator, value, unit, and analysis scope.

CREATE OR REPLACE VIEW `growth_core.portfolio_kpi_snapshot` AS
WITH acquisition_activation AS (
  SELECT
    COUNT(*) AS new_users,
    COUNTIF(activated_primary) AS activated_users,
    COUNTIF(feature_24h_eligible) AS feature_24h_eligible_users,
    COUNTIF(meaningful_activation_24h) AS meaningful_activated_users_24h,
    COUNTIF(high_intent_events_24h > 0) AS deep_activated_users_24h,
    COUNTIF(future_30d_eligible) AS future_30d_eligible_users,
    COUNTIF(converted_24h_to_30d) AS converted_users_24h_to_30d,
    COUNTIF(has_identifiable_order_24h_to_30d) AS identifiable_order_users_24h_to_30d,
    COUNTIF(has_recognized_revenue_24h_to_30d) AS recognized_revenue_users_24h_to_30d,
    COUNTIF(has_positive_recognized_value_24h_to_30d) AS positive_recognized_value_users_24h_to_30d,
    SUM(revenue_recognized_orders_24h_to_30d) AS revenue_recognized_orders_24h_to_30d,
    SUM(recognized_revenue_24h_to_30d_usd) AS recognized_revenue_24h_to_30d_usd
  FROM `growth_core.early_behavior_features`
),
retention AS (
  SELECT
    day_offset,
    COUNTIF(is_eligible) AS eligible_users,
    COUNTIF(product_returned) AS product_returned_users,
    COUNTIF(core_behavior_returned) AS core_behavior_returned_users
  FROM `growth_core.retention_user`
  GROUP BY day_offset
),
funnel AS (
  SELECT
    COUNT(*) AS sessions,
    COUNTIF(ordered_core_value) AS core_sessions,
    COUNTIF(ordered_high_intent) AS high_intent_sessions,
    COUNTIF(ordered_begin_checkout) AS checkout_sessions,
    COUNTIF(ordered_conversion) AS conversion_sessions
  FROM `growth_core.conversion_funnel_session`
),
value AS (
  SELECT
    COUNT(*) AS new_users,
    COUNTIF(canonical_orders > 0) AS identifiable_order_users,
    COUNTIF(revenue_recognized_orders > 0) AS recognized_revenue_users,
    COUNTIF(recognized_revenue_usd > 0) AS positive_recognized_value_users,
    SUM(canonical_orders) AS canonical_orders,
    SUM(revenue_recognized_orders) AS revenue_recognized_orders,
    SUM(revenue_null_orders) AS revenue_null_orders,
    SUM(revenue_conflict_orders) AS revenue_conflict_orders,
    SUM(recognized_revenue_usd) AS recognized_revenue_usd
  FROM `growth_core.user_value_user`
),
lifecycle AS (
  SELECT
    COUNT(*) AS new_users,
    COUNTIF(days_observed >= 8) AS returning_eligible_users,
    COUNTIF(days_observed >= 30) AS mature_30d_users,
    COUNTIF(activity_status = 'Active') AS active_users,
    COUNTIF(activity_status = 'Cooling') AS cooling_users,
    COUNTIF(activity_status = 'Dormant') AS dormant_users,
    COUNTIF(activity_status = 'Not Mature') AS not_mature_users,
    COUNTIF(highest_stage = 'Converted') AS converted_stage_users
  FROM `growth_core.lifecycle_user_snapshot`
)
SELECT 'Acquisition' AS module, 'New device users' AS metric_name,
  CAST(new_users AS FLOAT64) AS numerator, CAST(NULL AS FLOAT64) AS denominator,
  CAST(new_users AS FLOAT64) AS metric_value, 'users' AS unit,
  'Users with first_visit in the 92-day window' AS scope
FROM acquisition_activation

UNION ALL
SELECT 'Activation', 'Primary activation rate', activated_users, new_users,
  SAFE_DIVIDE(activated_users, new_users), 'rate', 'Core value reached in first session'
FROM acquisition_activation

UNION ALL
SELECT 'Activation', 'Meaningful activation rate 24h', meaningful_activated_users_24h, feature_24h_eligible_users,
  SAFE_DIVIDE(meaningful_activated_users_24h, feature_24h_eligible_users), 'rate', 'At least two core-value events; denominator has a complete 24-hour feature window'
FROM acquisition_activation

UNION ALL
SELECT 'Activation', 'Deep activation rate 24h', deep_activated_users_24h, feature_24h_eligible_users,
  SAFE_DIVIDE(deep_activated_users_24h, feature_24h_eligible_users), 'rate', 'High-intent event; denominator has a complete 24-hour feature window'
FROM acquisition_activation

UNION ALL
SELECT 'Conversion', 'Fixed-window conversion rate 24h-to-30d', converted_users_24h_to_30d, future_30d_eligible_users,
  SAFE_DIVIDE(converted_users_24h_to_30d, future_30d_eligible_users), 'rate', 'Conversion in [first_visit+24h, first_visit+30d); complete 30-day cohorts only'
FROM acquisition_activation

SELECT 'User Value', 'Fixed-window positive recognized value user rate 24h-to-30d', positive_recognized_value_users_24h_to_30d, future_30d_eligible_users,
  SAFE_DIVIDE(positive_recognized_value_users_24h_to_30d, future_30d_eligible_users), 'rate', 'Recognized revenue > 0 in [first_visit+24h, first_visit+30d); complete 30-day cohorts only'
FROM acquisition_activation

UNION ALL
SELECT 'User Value', 'Fixed-window recognized value per eligible user 24h-to-30d', recognized_revenue_24h_to_30d_usd, future_30d_eligible_users,
  SAFE_DIVIDE(recognized_revenue_24h_to_30d_usd, future_30d_eligible_users), 'USD per user', 'Recognized revenue in fixed window; complete 30-day cohorts only'
FROM acquisition_activation

UNION ALL
SELECT 'Retention', FORMAT('D%d product return rate', day_offset), product_returned_users, eligible_users,
  SAFE_DIVIDE(product_returned_users, eligible_users), 'rate', 'Exact calendar-day return; eligible cohorts only'
FROM retention

UNION ALL
SELECT 'Retention', FORMAT('D%d core behavior return rate', day_offset), core_behavior_returned_users, eligible_users,
  SAFE_DIVIDE(core_behavior_returned_users, eligible_users), 'rate', 'Exact calendar-day core behavior; eligible cohorts only'
FROM retention

UNION ALL
SELECT 'Conversion Funnel', 'Core to high-intent ordered rate', high_intent_sessions, core_sessions,
  SAFE_DIVIDE(high_intent_sessions, core_sessions), 'rate', 'Session grain; strictly increasing UTC event timestamps; equal timestamps excluded as order unknown'
FROM funnel

UNION ALL
SELECT 'Conversion Funnel', 'High-intent to checkout ordered rate', checkout_sessions, high_intent_sessions,
  SAFE_DIVIDE(checkout_sessions, high_intent_sessions), 'rate', 'Session grain; strictly increasing UTC event timestamps; equal timestamps excluded as order unknown'
FROM funnel

UNION ALL
SELECT 'Conversion Funnel', 'Checkout to conversion ordered rate', conversion_sessions, checkout_sessions,
  SAFE_DIVIDE(conversion_sessions, checkout_sessions), 'rate', 'Session grain; strictly increasing UTC event timestamps; equal timestamps excluded as order unknown'
FROM funnel

UNION ALL
SELECT 'Conversion Funnel', 'Core to conversion ordered rate', conversion_sessions, core_sessions,
  SAFE_DIVIDE(conversion_sessions, core_sessions), 'rate', 'Session grain; strictly increasing UTC event timestamps; equal timestamps excluded as order unknown'
FROM funnel

UNION ALL
SELECT 'Lifecycle', 'Active user share at snapshot', active_users, new_users,
  SAFE_DIVIDE(active_users, new_users), 'rate', 'Engaged in final 7 calendar days'
FROM lifecycle

UNION ALL
SELECT 'Lifecycle', 'Cooling user share at snapshot', cooling_users, returning_eligible_users,
  SAFE_DIVIDE(cooling_users, returning_eligible_users), 'rate', 'No engagement in final 7 days; engagement in prior 8-29 days. Denominator: users observed at least 8 days'
FROM lifecycle

UNION ALL
SELECT 'Lifecycle', 'Dormant user share at snapshot', dormant_users, mature_30d_users,
  SAFE_DIVIDE(dormant_users, mature_30d_users), 'rate', 'Denominator: users observed at least 30 days'
FROM lifecycle

UNION ALL
SELECT 'Lifecycle', 'Not mature user share at snapshot', not_mature_users, new_users,
  SAFE_DIVIDE(not_mature_users, new_users), 'rate', 'Observed fewer than 30 days and not classifiable as Active or Cooling'
FROM lifecycle

UNION ALL
SELECT 'User Value', 'Identifiable order user rate', identifiable_order_users, new_users,
  SAFE_DIVIDE(identifiable_order_users, new_users), 'rate', 'At least one canonical order with a valid order key; observed-to-data-end descriptive total'
FROM value

SELECT 'User Value', 'Positive recognized value user rate', positive_recognized_value_users, new_users,
  SAFE_DIVIDE(positive_recognized_value_users, new_users), 'rate', 'Recognized revenue > 0; observed-to-data-end descriptive total'
FROM value

UNION ALL
SELECT 'User Value', 'Recognized value per new user', recognized_revenue_usd, new_users,
  SAFE_DIVIDE(recognized_revenue_usd, new_users), 'USD per user', 'Observed-to-data-end descriptive total; not used for cross-group comparison'
FROM value

UNION ALL
SELECT 'User Value', 'Recognized AOV', recognized_revenue_usd, revenue_recognized_orders,
  SAFE_DIVIDE(recognized_revenue_usd, revenue_recognized_orders), 'USD per order', 'Recognized revenue / canonical orders with one unambiguous non-NULL revenue value; unknown and conflict orders excluded'
FROM value;

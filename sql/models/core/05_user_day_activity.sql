-- Grain: one device-level user per observed calendar date.
-- Supports DAU-style activity, dual retention, lifecycle, and frequency analysis.

CREATE OR REPLACE VIEW `growth_core.user_day_activity` AS
WITH event_day AS (
  SELECT
    user_pseudo_id,
    event_date AS activity_date,
    COUNT(*) AS event_count,
    COUNTIF(is_valid_activity_event) AS valid_event_count,
    COUNT(DISTINCT session_key) AS sessions,
    COUNTIF(event_name = 'first_visit') AS first_visit_events,
    COUNTIF(is_core_value_event) AS core_value_events,
    COUNTIF(is_high_intent_event) AS high_intent_events,
    COUNTIF(event_name = 'begin_checkout') AS begin_checkout_events,
    COUNTIF(is_conversion_event) AS conversion_events,
    COUNT(DISTINCT IF(is_core_value_event, session_key, NULL)) AS core_value_sessions,
    COUNT(DISTINCT IF(is_high_intent_event, session_key, NULL)) AS high_intent_sessions
  FROM `growth_core.stg_ga4_events`
  GROUP BY user_pseudo_id, activity_date
),
session_day AS (
  SELECT
    user_pseudo_id,
    session_date AS activity_date,
    COUNT(*) AS session_count,
    COUNTIF(is_engaged_session) AS engaged_sessions,
    SUM(engagement_time_msec) AS engagement_time_msec
  FROM `growth_core.session_fact`
  GROUP BY user_pseudo_id, activity_date
),
order_day AS (
  SELECT
    user_pseudo_id,
    order_date AS activity_date,
    COUNT(*) AS canonical_orders,
    COUNTIF(revenue_recognized) AS revenue_recognized_orders,
    COUNTIF(revenue_all_null) AS revenue_null_orders,
    COUNTIF(zero_revenue_order) AS zero_revenue_orders,
    COUNTIF(revenue_conflict) AS revenue_conflict_orders,
    SUM(recognized_revenue_usd) AS recognized_revenue_usd
  FROM `growth_core.order_fact`
  GROUP BY user_pseudo_id, activity_date
)
SELECT
  e.user_pseudo_id,
  e.activity_date,
  e.event_count,
  e.valid_event_count,
  e.sessions,
  COALESCE(s.session_count, 0) AS session_count,
  COALESCE(s.engaged_sessions, 0) AS engaged_sessions,
  COALESCE(s.engagement_time_msec, 0) AS engagement_time_msec,
  e.first_visit_events,
  e.core_value_events,
  e.high_intent_events,
  e.begin_checkout_events,
  e.conversion_events,
  e.core_value_sessions,
  e.high_intent_sessions,
  COALESCE(o.canonical_orders, 0) AS canonical_orders,
  COALESCE(o.revenue_recognized_orders, 0) AS revenue_recognized_orders,
  COALESCE(o.revenue_null_orders, 0) AS revenue_null_orders,
  COALESCE(o.zero_revenue_orders, 0) AS zero_revenue_orders,
  COALESCE(o.revenue_conflict_orders, 0) AS revenue_conflict_orders,
  COALESCE(o.recognized_revenue_usd, 0) AS recognized_revenue_usd,
  e.valid_event_count > 0 AS is_observed_active,
  COALESCE(s.engaged_sessions, 0) > 0 AS is_product_return_activity,
  e.core_value_events > 0 AS is_core_behavior_activity
FROM event_day AS e
LEFT JOIN session_day AS s
  USING (user_pseudo_id, activity_date)
LEFT JOIN order_day AS o
  USING (user_pseudo_id, activity_date);

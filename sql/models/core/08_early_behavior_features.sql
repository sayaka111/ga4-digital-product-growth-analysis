-- Grain: one device-level new user.
-- 24h features require a complete 24-hour window.
-- Comparable future outcomes use the fixed interval [first_visit + 24h, first_visit + 30d).
-- Ineligible feature/outcome values are NULL, never FALSE or zero.

CREATE OR REPLACE VIEW `growth_core.early_behavior_features` AS
WITH bounds AS (
  SELECT MAX(event_datetime_utc) AS data_end_at_utc
  FROM `growth_core.stg_ga4_events`
),
new_users AS (
  SELECT
    u.*,
    b.data_end_at_utc,
    TIMESTAMP_ADD(u.first_visit_at_utc, INTERVAL 24 HOUR) AS feature_window_24h_end,
    TIMESTAMP_ADD(u.first_visit_at_utc, INTERVAL 30 DAY) AS outcome_window_30d_end,
    TIMESTAMP_ADD(u.first_visit_at_utc, INTERVAL 24 HOUR) <= b.data_end_at_utc AS feature_24h_eligible,
    TIMESTAMP_ADD(u.first_visit_at_utc, INTERVAL 30 DAY) <= b.data_end_at_utc AS future_30d_eligible
  FROM `growth_core.user_first_session` AS u
  CROSS JOIN bounds AS b
),
events_24h AS (
  SELECT
    u.user_pseudo_id,
    COUNT(*) AS events_24h,
    COUNTIF(e.is_valid_activity_event) AS valid_events_24h,
    COUNT(DISTINCT e.session_key) AS sessions_24h,
    COUNT(DISTINCT e.page_location) AS distinct_pages_24h,
    COALESCE(SUM(e.engagement_time_msec), 0) AS engagement_time_msec_24h,
    COUNTIF(e.is_core_value_event) AS core_value_events_24h,
    COUNTIF(e.is_high_intent_event) AS high_intent_events_24h,
    COUNTIF(e.event_name = 'begin_checkout') AS begin_checkout_events_24h,
    COUNTIF(e.is_conversion_event) AS conversion_events_24h,
    COUNT(DISTINCT e.session_key) > 1 AS returned_within_24h
  FROM new_users AS u
  INNER JOIN `growth_core.stg_ga4_events` AS e
    ON u.user_pseudo_id = e.user_pseudo_id
    AND e.event_datetime_utc >= u.first_visit_at_utc
    AND e.event_datetime_utc < u.feature_window_24h_end
  GROUP BY u.user_pseudo_id
),
items_24h AS (
  SELECT
    u.user_pseudo_id,
    COUNT(DISTINCT item.item_id) AS unique_items_viewed_24h
  FROM new_users AS u
  INNER JOIN `growth_core.stg_ga4_events` AS e
    ON u.user_pseudo_id = e.user_pseudo_id
    AND e.event_datetime_utc >= u.first_visit_at_utc
    AND e.event_datetime_utc < u.feature_window_24h_end,
  UNNEST(e.items) AS item
  WHERE e.event_name = 'view_item'
  GROUP BY u.user_pseudo_id
),
retention_outcomes AS (
  SELECT
    user_pseudo_id,
    ANY_VALUE(IF(day_offset = 7, product_returned, NULL)) AS d7_product_returned,
    ANY_VALUE(IF(day_offset = 7, core_behavior_returned, NULL)) AS d7_core_behavior_returned,
    ANY_VALUE(IF(day_offset = 30, product_returned, NULL)) AS d30_product_returned,
    ANY_VALUE(IF(day_offset = 30, core_behavior_returned, NULL)) AS d30_core_behavior_returned
  FROM `growth_core.retention_user`
  GROUP BY user_pseudo_id
),
fixed_future_conversion AS (
  SELECT
    u.user_pseudo_id,
    COUNTIF(e.is_conversion_event) > 0 AS converted_24h_to_30d,
    MIN(IF(e.is_conversion_event, e.event_datetime_utc, NULL)) AS first_conversion_24h_to_30d_at_utc
  FROM new_users AS u
  LEFT JOIN `growth_core.stg_ga4_events` AS e
    ON u.user_pseudo_id = e.user_pseudo_id
    AND e.event_datetime_utc >= u.feature_window_24h_end
    AND e.event_datetime_utc < u.outcome_window_30d_end
  GROUP BY u.user_pseudo_id
),
fixed_future_value AS (
  SELECT
    u.user_pseudo_id,
    COUNT(o.canonical_order_key) AS canonical_orders_24h_to_30d,
    COUNTIF(o.revenue_recognized) AS revenue_recognized_orders_24h_to_30d,
    COUNTIF(o.revenue_all_null) AS revenue_null_orders_24h_to_30d,
    COUNTIF(o.zero_revenue_order) AS zero_revenue_orders_24h_to_30d,
    COUNTIF(o.revenue_conflict) AS revenue_conflict_orders_24h_to_30d,
    COALESCE(SUM(o.recognized_revenue_usd), 0) AS recognized_revenue_24h_to_30d_usd
  FROM new_users AS u
  LEFT JOIN `growth_core.order_fact` AS o
    ON u.user_pseudo_id = o.user_pseudo_id
    AND o.order_at_utc >= u.feature_window_24h_end
    AND o.order_at_utc < u.outcome_window_30d_end
  GROUP BY u.user_pseudo_id
)
SELECT
  u.user_pseudo_id,
  u.cohort_date,
  u.first_visit_at_utc,
  u.data_end_at_utc,
  u.feature_window_24h_end,
  u.outcome_window_30d_end,
  u.feature_24h_eligible,
  u.future_30d_eligible,
  u.first_touch_source,
  u.first_touch_medium,
  u.first_touch_campaign,
  u.device_category,
  u.operating_system,
  u.browser,
  u.country,
  u.first_session_event_count,
  u.first_session_valid_event_count,
  u.first_session_distinct_pages,
  u.first_session_engagement_time_msec,
  u.unique_items_viewed_first_session,
  u.activated_primary,
  u.has_high_intent_first_session,
  u.converted_first_session,
  IF(u.feature_24h_eligible, COALESCE(e.events_24h, 0), NULL) AS events_24h,
  IF(u.feature_24h_eligible, COALESCE(e.valid_events_24h, 0), NULL) AS valid_events_24h,
  IF(u.feature_24h_eligible, COALESCE(e.sessions_24h, 0), NULL) AS sessions_24h,
  IF(u.feature_24h_eligible, COALESCE(e.distinct_pages_24h, 0), NULL) AS distinct_pages_24h,
  IF(u.feature_24h_eligible, COALESCE(e.engagement_time_msec_24h, 0), NULL) AS engagement_time_msec_24h,
  IF(u.feature_24h_eligible, COALESCE(e.core_value_events_24h, 0), NULL) AS core_value_events_24h,
  IF(u.feature_24h_eligible, COALESCE(e.core_value_events_24h, 0) >= 2, NULL) AS meaningful_activation_24h,
  IF(u.feature_24h_eligible, COALESCE(e.high_intent_events_24h, 0), NULL) AS high_intent_events_24h,
  IF(u.feature_24h_eligible, COALESCE(e.begin_checkout_events_24h, 0), NULL) AS begin_checkout_events_24h,
  IF(u.feature_24h_eligible, COALESCE(e.conversion_events_24h, 0), NULL) AS conversion_events_24h,
  IF(u.feature_24h_eligible, COALESCE(e.returned_within_24h, FALSE), NULL) AS returned_within_24h,
  IF(u.feature_24h_eligible, COALESCE(i.unique_items_viewed_24h, 0), NULL) AS unique_items_viewed_24h,
  r.d7_product_returned,
  r.d7_core_behavior_returned,
  r.d30_product_returned,
  r.d30_core_behavior_returned,
  IF(u.future_30d_eligible, f.converted_24h_to_30d, NULL) AS converted_24h_to_30d,
  IF(u.future_30d_eligible, f.first_conversion_24h_to_30d_at_utc, NULL) AS first_conversion_24h_to_30d_at_utc,
  IF(u.future_30d_eligible, v.canonical_orders_24h_to_30d, NULL) AS canonical_orders_24h_to_30d,
  IF(u.future_30d_eligible, v.revenue_recognized_orders_24h_to_30d, NULL) AS revenue_recognized_orders_24h_to_30d,
  IF(u.future_30d_eligible, v.revenue_null_orders_24h_to_30d, NULL) AS revenue_null_orders_24h_to_30d,
  IF(u.future_30d_eligible, v.zero_revenue_orders_24h_to_30d, NULL) AS zero_revenue_orders_24h_to_30d,
  IF(u.future_30d_eligible, v.revenue_conflict_orders_24h_to_30d, NULL) AS revenue_conflict_orders_24h_to_30d,
  IF(u.future_30d_eligible, v.recognized_revenue_24h_to_30d_usd, NULL) AS recognized_revenue_24h_to_30d_usd,
  IF(u.future_30d_eligible, v.canonical_orders_24h_to_30d > 0, NULL) AS has_identifiable_order_24h_to_30d,
  IF(u.future_30d_eligible, v.revenue_recognized_orders_24h_to_30d > 0, NULL) AS has_recognized_revenue_24h_to_30d,
  IF(u.future_30d_eligible, v.recognized_revenue_24h_to_30d_usd > 0, NULL) AS has_positive_recognized_value_24h_to_30d
FROM new_users AS u
LEFT JOIN events_24h AS e USING (user_pseudo_id)
LEFT JOIN items_24h AS i USING (user_pseudo_id)
LEFT JOIN retention_outcomes AS r USING (user_pseudo_id)
LEFT JOIN fixed_future_conversion AS f USING (user_pseudo_id)
LEFT JOIN fixed_future_value AS v USING (user_pseudo_id);

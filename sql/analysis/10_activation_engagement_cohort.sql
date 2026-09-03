-- Grain: acquisition cohort date x device category.
-- Engagement measures are descriptive summaries, not causal effects.

CREATE OR REPLACE VIEW `growth_core.activation_engagement_cohort` AS
SELECT
  cohort_date,
  COALESCE(device_category, '(missing)') AS device_category,
  COUNT(*) AS new_users,
  COUNTIF(activated_primary) AS activated_users,
  SAFE_DIVIDE(COUNTIF(activated_primary), COUNT(*)) AS activation_rate,
  COUNTIF(meaningful_activation_24h) AS meaningful_activated_users_24h,
  COUNTIF(feature_24h_eligible) AS feature_24h_eligible_users,
  SAFE_DIVIDE(COUNTIF(meaningful_activation_24h), COUNTIF(feature_24h_eligible)) AS meaningful_activation_rate_24h,
  COUNTIF(high_intent_events_24h > 0) AS deep_activated_users_24h,
  SAFE_DIVIDE(COUNTIF(high_intent_events_24h > 0), COUNTIF(feature_24h_eligible)) AS deep_activation_rate_24h,
  AVG(first_session_valid_event_count) AS avg_first_session_valid_events,
  AVG(first_session_distinct_pages) AS avg_first_session_distinct_pages,
  AVG(first_session_engagement_time_msec) / 1000.0 AS avg_first_session_engagement_seconds,
  AVG(sessions_24h) AS avg_sessions_24h,
  AVG(valid_events_24h) AS avg_valid_events_24h,
  COUNTIF(d7_product_returned IS NOT NULL) AS d7_eligible_users,
  SAFE_DIVIDE(COUNTIF(d7_product_returned), COUNTIF(d7_product_returned IS NOT NULL)) AS d7_product_return_rate,
  SAFE_DIVIDE(COUNTIF(d7_core_behavior_returned), COUNTIF(d7_core_behavior_returned IS NOT NULL)) AS d7_core_behavior_return_rate
FROM `growth_core.early_behavior_features`
GROUP BY cohort_date, device_category;

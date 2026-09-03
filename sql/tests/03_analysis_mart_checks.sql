-- Structural and denominator checks for analytical marts.
-- Every row should return PASS.

WITH checks AS (
  SELECT
    'acquisition_users_reconcile' AS check_name,
    SUM(new_users) = 257314 AS passed,
    FORMAT('%d users', SUM(new_users)) AS detail
  FROM `growth_core.acquisition_channel_quality`

  UNION ALL
  SELECT
    'activation_cohort_users_reconcile',
    SUM(new_users) = 257314,
    FORMAT('%d users', SUM(new_users))
  FROM `growth_core.activation_engagement_cohort`

  UNION ALL
  SELECT
    'retention_denominators_valid',
    COUNTIF(eligible_users > cohort_users OR product_returned_users > eligible_users OR core_behavior_returned_users > eligible_users) = 0,
    FORMAT('%d invalid rows', COUNTIF(eligible_users > cohort_users OR product_returned_users > eligible_users OR core_behavior_returned_users > eligible_users))
  FROM `growth_core.retention_cohort`

  UNION ALL
  SELECT
    'one_lifecycle_row_per_new_user',
    COUNT(*) = 257314 AND COUNT(*) = COUNT(DISTINCT user_pseudo_id),
    FORMAT('%d rows', COUNT(*))
  FROM `growth_core.lifecycle_user_snapshot`

  UNION ALL
  SELECT
    'lifecycle_immaturity_prevents_dormancy',
    COUNTIF(activity_status = 'Dormant' AND days_observed < 30) = 0,
    FORMAT('%d immature dormant rows', COUNTIF(activity_status = 'Dormant' AND days_observed < 30))
  FROM `growth_core.lifecycle_user_snapshot`

  UNION ALL
  SELECT
    'lifecycle_status_is_complete',
    COUNTIF(activity_status NOT IN ('Active', 'Cooling', 'Dormant', 'Not Mature') OR activity_status IS NULL) = 0,
    FORMAT('%d invalid rows', COUNTIF(activity_status NOT IN ('Active', 'Cooling', 'Dormant', 'Not Mature') OR activity_status IS NULL))
  FROM `growth_core.lifecycle_user_snapshot`

  UNION ALL
  SELECT
    'feature_24h_ineligible_values_are_null',
    COUNTIF(NOT feature_24h_eligible AND (
      meaningful_activation_24h IS NOT NULL OR high_intent_events_24h IS NOT NULL
      OR returned_within_24h IS NOT NULL OR core_value_events_24h IS NOT NULL
    )) = 0,
    FORMAT('%d ineligible rows with populated 24h features', COUNTIF(NOT feature_24h_eligible AND (
      meaningful_activation_24h IS NOT NULL OR high_intent_events_24h IS NOT NULL
      OR returned_within_24h IS NOT NULL OR core_value_events_24h IS NOT NULL
    )))
  FROM `growth_core.early_behavior_features`

  UNION ALL
  SELECT
    'future_30d_ineligible_values_are_null',
    COUNTIF(NOT future_30d_eligible AND (
      converted_24h_to_30d IS NOT NULL OR canonical_orders_24h_to_30d IS NOT NULL
      OR recognized_revenue_24h_to_30d_usd IS NOT NULL
      OR has_identifiable_order_24h_to_30d IS NOT NULL
      OR has_recognized_revenue_24h_to_30d IS NOT NULL
      OR has_positive_recognized_value_24h_to_30d IS NOT NULL
    )) = 0,
    FORMAT('%d ineligible rows with populated fixed-window outcomes', COUNTIF(NOT future_30d_eligible AND (
      converted_24h_to_30d IS NOT NULL OR canonical_orders_24h_to_30d IS NOT NULL
      OR recognized_revenue_24h_to_30d_usd IS NOT NULL
      OR has_identifiable_order_24h_to_30d IS NOT NULL
      OR has_recognized_revenue_24h_to_30d IS NOT NULL
      OR has_positive_recognized_value_24h_to_30d IS NOT NULL
    )))
  FROM `growth_core.early_behavior_features`

  UNION ALL
  SELECT
    'future_30d_window_is_complete',
    COUNTIF(future_30d_eligible AND outcome_window_30d_end > data_end_at_utc) = 0,
    FORMAT('%d eligible rows extend beyond data end', COUNTIF(future_30d_eligible AND outcome_window_30d_end > data_end_at_utc))
  FROM `growth_core.early_behavior_features`

  UNION ALL
  SELECT
    'future_conversion_numerator_within_denominator',
    COUNTIF(converted_24h_to_30d) <= COUNTIF(future_30d_eligible),
    FORMAT('%d conversions / %d eligible users', COUNTIF(converted_24h_to_30d), COUNTIF(future_30d_eligible))
  FROM `growth_core.early_behavior_features`

  UNION ALL
  SELECT
    'future_value_binary_hierarchy',
    COUNTIF(has_positive_recognized_value_24h_to_30d)
      <= COUNTIF(has_recognized_revenue_24h_to_30d)
      AND COUNTIF(has_recognized_revenue_24h_to_30d)
      <= COUNTIF(has_identifiable_order_24h_to_30d),
    FORMAT('%d positive <= %d revenue-recognized <= %d identifiable users',
      COUNTIF(has_positive_recognized_value_24h_to_30d),
      COUNTIF(has_recognized_revenue_24h_to_30d),
      COUNTIF(has_identifiable_order_24h_to_30d))
  FROM `growth_core.early_behavior_features`

  UNION ALL
  SELECT
    'future_conversion_differs_from_positive_value',
    COUNTIF(converted_24h_to_30d) != COUNTIF(has_positive_recognized_value_24h_to_30d),
    FORMAT('%d conversions vs %d positive-value users',
      COUNTIF(converted_24h_to_30d), COUNTIF(has_positive_recognized_value_24h_to_30d))
  FROM `growth_core.early_behavior_features`

  UNION ALL
  SELECT
    'one_value_row_per_new_user',
    COUNT(*) = 257314 AND COUNT(*) = COUNT(DISTINCT user_pseudo_id),
    FORMAT('%d rows', COUNT(*))
  FROM `growth_core.user_value_user`
)
SELECT
  check_name,
  IF(passed, 'PASS', 'FAIL') AS status,
  detail
FROM checks
ORDER BY check_name;

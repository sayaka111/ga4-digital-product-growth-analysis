-- Compact aggregate extract for Python statistical validation.
-- Grain: one early feature x feature value x future outcome.
-- 24h features require feature_24h_eligible; fixed future outcomes require future_30d_eligible.

WITH feature_long AS (
  SELECT
    b.user_pseudo_id,
    f.feature_name,
    f.feature_eligible,
    f.feature_value,
    b.d7_product_returned,
    b.d7_core_behavior_returned,
    b.d30_product_returned,
    b.d30_core_behavior_returned,
    b.future_30d_eligible,
    b.converted_24h_to_30d,
    b.has_identifiable_order_24h_to_30d,
    b.has_recognized_revenue_24h_to_30d,
    b.has_positive_recognized_value_24h_to_30d
  FROM `growth_core.early_behavior_features` AS b,
  UNNEST([
    STRUCT('activated_primary' AS feature_name, TRUE AS feature_eligible, b.activated_primary AS feature_value),
    STRUCT('deep_activated_24h', b.feature_24h_eligible, b.high_intent_events_24h > 0),
    STRUCT('returned_within_24h', b.feature_24h_eligible, b.returned_within_24h),
    STRUCT('repeated_core_value_24h', b.feature_24h_eligible, b.meaningful_activation_24h)
  ]) AS f
),
outcome_long AS (
  SELECT
    f.user_pseudo_id,
    f.feature_name,
    f.feature_value,
    o.outcome_name,
    f.feature_eligible AND o.outcome_eligible AS is_eligible,
    o.outcome_value
  FROM feature_long AS f,
  UNNEST([
    STRUCT('d7_product_return' AS outcome_name, f.d7_product_returned IS NOT NULL AS outcome_eligible, COALESCE(f.d7_product_returned, FALSE) AS outcome_value),
    STRUCT('d7_core_behavior_return', f.d7_core_behavior_returned IS NOT NULL, COALESCE(f.d7_core_behavior_returned, FALSE)),
    STRUCT('d30_product_return', f.d30_product_returned IS NOT NULL, COALESCE(f.d30_product_returned, FALSE)),
    STRUCT('d30_core_behavior_return', f.d30_core_behavior_returned IS NOT NULL, COALESCE(f.d30_core_behavior_returned, FALSE)),
    STRUCT('future_conversion_24h_to_30d', f.future_30d_eligible, COALESCE(f.converted_24h_to_30d, FALSE)),
    STRUCT('future_identifiable_order_24h_to_30d', f.future_30d_eligible, COALESCE(f.has_identifiable_order_24h_to_30d, FALSE)),
    STRUCT('future_recognized_revenue_24h_to_30d', f.future_30d_eligible, COALESCE(f.has_recognized_revenue_24h_to_30d, FALSE)),
    STRUCT('future_positive_recognized_value_24h_to_30d', f.future_30d_eligible, COALESCE(f.has_positive_recognized_value_24h_to_30d, FALSE))
  ]) AS o
)
SELECT
  feature_name,
  feature_value,
  outcome_name,
  COUNTIF(is_eligible) AS eligible_users,
  COUNTIF(is_eligible AND outcome_value) AS positive_users,
  SAFE_DIVIDE(COUNTIF(is_eligible AND outcome_value), COUNTIF(is_eligible)) AS outcome_rate
FROM outcome_long
WHERE feature_value IS NOT NULL
GROUP BY feature_name, feature_value, outcome_name
ORDER BY feature_name, outcome_name, feature_value;

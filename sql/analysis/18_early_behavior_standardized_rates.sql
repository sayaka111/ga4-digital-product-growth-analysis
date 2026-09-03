-- Purpose: descriptive robustness check for early behavior associations.
-- Grain: one feature x future outcome.
-- Method: direct standardization over cohort month x device x coarse first-touch channel strata.
-- This reduces observed composition differences but does not identify causal effects.

WITH long_data AS (
  SELECT
    FORMAT_DATE('%Y-%m', cohort_date) AS cohort_month,
    COALESCE(device_category, '(missing)') AS device_category,
    CASE
      WHEN LOWER(COALESCE(first_touch_source, '')) = 'shop.googlemerchandisestore.com'
        AND LOWER(COALESCE(first_touch_medium, '')) = 'referral' THEN 'probable_self_referral'
      WHEN LOWER(COALESCE(first_touch_source, '')) = 'google'
        AND LOWER(COALESCE(first_touch_medium, '')) = 'organic' THEN 'google_organic'
      WHEN LOWER(COALESCE(first_touch_source, '')) = 'google'
        AND LOWER(COALESCE(first_touch_medium, '')) = 'cpc' THEN 'google_cpc'
      WHEN COALESCE(first_touch_source, '') = '(direct)'
        AND COALESCE(first_touch_medium, '') = '(none)' THEN 'direct'
      ELSE 'other'
    END AS coarse_first_touch_channel,
    feature.feature_name,
    feature.feature_eligible,
    feature.exposed,
    outcome.outcome_name,
    outcome.positive
  FROM `growth_core.early_behavior_features`,
  UNNEST([
    STRUCT('primary_activation' AS feature_name, TRUE AS feature_eligible, activated_primary AS exposed),
    STRUCT('meaningful_activation_24h', feature_24h_eligible, meaningful_activation_24h),
    STRUCT('deep_activation_24h', feature_24h_eligible, high_intent_events_24h > 0),
    STRUCT('returned_within_24h', feature_24h_eligible, returned_within_24h)
  ]) AS feature,
  UNNEST([
    STRUCT('d7_product_return' AS outcome_name, d7_product_returned AS positive),
    STRUCT('d7_core_return', d7_core_behavior_returned),
    STRUCT('d30_product_return', d30_product_returned),
    STRUCT('d30_core_return', d30_core_behavior_returned),
    STRUCT('future_conversion_24h_to_30d', converted_24h_to_30d),
    STRUCT('future_identifiable_order_24h_to_30d', has_identifiable_order_24h_to_30d),
    STRUCT('future_recognized_revenue_24h_to_30d', has_recognized_revenue_24h_to_30d),
    STRUCT('future_positive_recognized_value_24h_to_30d', has_positive_recognized_value_24h_to_30d)
  ]) AS outcome
  WHERE feature.feature_eligible AND feature.exposed IS NOT NULL AND outcome.positive IS NOT NULL
),
strata AS (
  SELECT
    feature_name,
    outcome_name,
    cohort_month,
    device_category,
    coarse_first_touch_channel,
    COUNT(*) AS eligible_users,
    COUNTIF(exposed) AS exposed_users,
    COUNTIF(NOT exposed) AS unexposed_users,
    SAFE_DIVIDE(COUNTIF(exposed AND positive), COUNTIF(exposed)) AS exposed_rate,
    SAFE_DIVIDE(COUNTIF(NOT exposed AND positive), COUNTIF(NOT exposed)) AS unexposed_rate
  FROM long_data
  GROUP BY 1, 2, 3, 4, 5
),
common_support AS (
  SELECT
    *,
    SAFE_DIVIDE(eligible_users, SUM(eligible_users) OVER (PARTITION BY feature_name, outcome_name)) AS stratum_weight
  FROM strata
  WHERE exposed_users > 0 AND unexposed_users > 0
)
SELECT
  feature_name,
  outcome_name,
  SUM(stratum_weight * exposed_rate) / SUM(stratum_weight) AS standardized_exposed_rate,
  SUM(stratum_weight * unexposed_rate) / SUM(stratum_weight) AS standardized_unexposed_rate,
  100 * (
    SUM(stratum_weight * exposed_rate) / SUM(stratum_weight)
    - SUM(stratum_weight * unexposed_rate) / SUM(stratum_weight)
  ) AS standardized_risk_difference_pp,
  SUM(eligible_users) AS common_support_users,
  COUNT(*) AS common_support_strata
FROM common_support
GROUP BY feature_name, outcome_name
ORDER BY outcome_name, standardized_risk_difference_pp DESC;

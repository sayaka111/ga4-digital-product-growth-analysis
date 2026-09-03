-- Grain: one first-touch source / medium / campaign combination.
-- Denominators are explicit; retention rates exclude right-censored users.

CREATE OR REPLACE VIEW `growth_core.acquisition_channel_quality` AS
SELECT
  COALESCE(first_touch_source, '(missing)') AS first_touch_source,
  COALESCE(first_touch_medium, '(missing)') AS first_touch_medium,
  COALESCE(first_touch_campaign, '(missing)') AS first_touch_campaign,
  LOWER(COALESCE(first_touch_source, '')) = 'shop.googlemerchandisestore.com'
    AND LOWER(COALESCE(first_touch_medium, '')) = 'referral' AS is_probable_self_referral,
  COUNT(*) AS new_users,
  COUNTIF(activated_primary) AS activated_users,
  SAFE_DIVIDE(COUNTIF(activated_primary), COUNT(*)) AS activation_rate,
  COUNTIF(feature_24h_eligible) AS feature_24h_eligible_users,
  COUNTIF(meaningful_activation_24h) AS meaningful_activated_users_24h,
  SAFE_DIVIDE(COUNTIF(meaningful_activation_24h), COUNTIF(feature_24h_eligible)) AS meaningful_activation_rate_24h,
  COUNTIF(high_intent_events_24h > 0) AS deep_activated_users_24h,
  SAFE_DIVIDE(COUNTIF(high_intent_events_24h > 0), COUNTIF(feature_24h_eligible)) AS deep_activation_rate_24h,
  COUNTIF(d7_product_returned IS NOT NULL) AS d7_eligible_users,
  COUNTIF(d7_product_returned) AS d7_product_returned_users,
  SAFE_DIVIDE(COUNTIF(d7_product_returned), COUNTIF(d7_product_returned IS NOT NULL)) AS d7_product_return_rate,
  COUNTIF(d7_core_behavior_returned) AS d7_core_behavior_returned_users,
  SAFE_DIVIDE(COUNTIF(d7_core_behavior_returned), COUNTIF(d7_core_behavior_returned IS NOT NULL)) AS d7_core_behavior_return_rate,
  COUNTIF(d30_product_returned IS NOT NULL) AS d30_eligible_users,
  COUNTIF(d30_product_returned) AS d30_product_returned_users,
  SAFE_DIVIDE(COUNTIF(d30_product_returned), COUNTIF(d30_product_returned IS NOT NULL)) AS d30_product_return_rate,
  COUNTIF(future_30d_eligible) AS future_30d_eligible_users,
  COUNTIF(converted_24h_to_30d) AS users_converted_24h_to_30d,
  SAFE_DIVIDE(COUNTIF(converted_24h_to_30d), COUNTIF(future_30d_eligible)) AS conversion_rate_24h_to_30d,
  COUNTIF(has_identifiable_order_24h_to_30d) AS identifiable_order_users_24h_to_30d,
  COUNTIF(has_recognized_revenue_24h_to_30d) AS recognized_revenue_users_24h_to_30d,
  COUNTIF(has_positive_recognized_value_24h_to_30d) AS positive_recognized_value_users_24h_to_30d,
  SUM(canonical_orders_24h_to_30d) AS canonical_orders_24h_to_30d,
  SUM(revenue_recognized_orders_24h_to_30d) AS revenue_recognized_orders_24h_to_30d,
  SUM(revenue_null_orders_24h_to_30d) AS revenue_null_orders_24h_to_30d,
  SUM(revenue_conflict_orders_24h_to_30d) AS revenue_conflict_orders_24h_to_30d,
  SUM(recognized_revenue_24h_to_30d_usd) AS recognized_revenue_24h_to_30d_usd,
  SAFE_DIVIDE(SUM(recognized_revenue_24h_to_30d_usd), COUNTIF(future_30d_eligible)) AS recognized_value_per_eligible_user_24h_to_30d
FROM `growth_core.early_behavior_features`
GROUP BY 1, 2, 3, 4;

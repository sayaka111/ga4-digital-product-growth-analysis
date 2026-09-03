-- data_quality audit.
-- Reports canonical revenue policy, fixed-window user outcomes, timestamp ties,
-- and purchase-conditioned item quantity completeness.

WITH order_audit AS (
  SELECT
    COUNT(*) AS canonical_orders_total,
    COUNTIF(revenue_recognized) AS canonical_orders_revenue_recognized,
    COUNTIF(revenue_all_null) AS canonical_orders_revenue_null,
    COUNTIF(zero_revenue_order) AS canonical_orders_zero_revenue,
    COUNTIF(revenue_conflict) AS canonical_orders_revenue_conflict,
    SUM(recognized_revenue_usd) AS recognized_revenue_usd
  FROM `growth_core.order_fact`
),
user_outcomes AS (
  SELECT
    COUNTIF(future_30d_eligible) AS future_30d_eligible_users,
    COUNTIF(converted_24h_to_30d) AS converted_users,
    COUNTIF(has_identifiable_order_24h_to_30d) AS identifiable_order_users,
    COUNTIF(has_recognized_revenue_24h_to_30d) AS recognized_revenue_users,
    COUNTIF(has_positive_recognized_value_24h_to_30d) AS positive_revenue_users
  FROM `growth_core.early_behavior_features`
),
funnel_ties AS (
  SELECT
    COUNTIF(core_high_intent_timestamp_tie) AS core_high_intent_ties,
    COUNTIF(high_intent_checkout_timestamp_tie) AS high_intent_checkout_ties,
    COUNTIF(checkout_conversion_timestamp_tie) AS checkout_conversion_ties
  FROM `growth_core.conversion_funnel_session`
),
purchase_quantity AS (
  SELECT
    COUNT(*) AS purchase_item_rows,
    COUNTIF(item.quantity IS NOT NULL) AS purchase_item_rows_quantity_nonnull,
    COUNTIF(item.quantity > 0) AS purchase_item_rows_quantity_positive
  FROM `growth_core.stg_ga4_events` AS e,
  UNNEST(e.items) AS item
  WHERE e.event_name = 'purchase'
)
SELECT 'order_revenue' AS section, 'canonical_orders_total' AS metric,
  CAST(canonical_orders_total AS FLOAT64) AS value, 'identifiable canonical orders' AS detail FROM order_audit
UNION ALL SELECT 'order_revenue', 'canonical_orders_revenue_recognized', canonical_orders_revenue_recognized, 'exactly one distinct non-NULL revenue value' FROM order_audit
UNION ALL SELECT 'order_revenue', 'canonical_orders_revenue_null', canonical_orders_revenue_null, 'all duplicate rows have NULL revenue' FROM order_audit
UNION ALL SELECT 'order_revenue', 'canonical_orders_zero_revenue', canonical_orders_zero_revenue, 'recognized revenue equals zero' FROM order_audit
UNION ALL SELECT 'order_revenue', 'canonical_orders_revenue_conflict', canonical_orders_revenue_conflict, 'multiple distinct non-NULL values; excluded from primary revenue' FROM order_audit
UNION ALL SELECT 'order_revenue', 'recognized_revenue_usd', recognized_revenue_usd, 'conflicts and all-NULL orders excluded' FROM order_audit
UNION ALL SELECT 'fixed_window_users', 'future_30d_eligible_users', future_30d_eligible_users, '[first_visit+24h, first_visit+30d)' FROM user_outcomes
UNION ALL SELECT 'fixed_window_users', 'converted_users', converted_users, 'purchase conversion event in fixed window' FROM user_outcomes
UNION ALL SELECT 'fixed_window_users', 'identifiable_order_users', identifiable_order_users, 'at least one canonical order' FROM user_outcomes
UNION ALL SELECT 'fixed_window_users', 'recognized_revenue_users', recognized_revenue_users, 'at least one revenue-recognized canonical order' FROM user_outcomes
UNION ALL SELECT 'fixed_window_users', 'positive_revenue_users', positive_revenue_users, 'recognized fixed-window revenue > 0' FROM user_outcomes
UNION ALL SELECT 'timestamp_ties', 'core_high_intent_ties', core_high_intent_ties, 'order unknown; excluded from strict ordered funnel' FROM funnel_ties
UNION ALL SELECT 'timestamp_ties', 'high_intent_checkout_ties', high_intent_checkout_ties, 'order unknown; excluded from strict ordered funnel' FROM funnel_ties
UNION ALL SELECT 'timestamp_ties', 'checkout_conversion_ties', checkout_conversion_ties, 'order unknown; excluded from strict ordered funnel' FROM funnel_ties
UNION ALL SELECT 'purchase_quantity', 'purchase_item_rows', purchase_item_rows, 'purchase event item rows only' FROM purchase_quantity
UNION ALL SELECT 'purchase_quantity', 'purchase_item_rows_quantity_nonnull', purchase_item_rows_quantity_nonnull, 'purchase item rows with quantity populated' FROM purchase_quantity
UNION ALL SELECT 'purchase_quantity', 'purchase_item_rows_quantity_positive', purchase_item_rows_quantity_positive, 'purchase item rows with quantity > 0' FROM purchase_quantity
ORDER BY section, metric;

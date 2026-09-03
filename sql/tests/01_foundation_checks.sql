-- Run after the staging and core views are created.
-- Every row should return PASS. Revenue checks validate policy rather than a stale total.

WITH checks AS (
  SELECT 'source_event_count' AS check_name,
    COUNT(*) = 4295584 AS passed,
    FORMAT('%d events', COUNT(*)) AS detail
  FROM `growth_core.stg_ga4_events`

  UNION ALL
  SELECT 'device_level_users', COUNT(DISTINCT user_pseudo_id) = 270154,
    FORMAT('%d users', COUNT(DISTINCT user_pseudo_id))
  FROM `growth_core.stg_ga4_events`

  UNION ALL
  SELECT 'composite_sessions', COUNT(*) = 360129, FORMAT('%d sessions', COUNT(*))
  FROM `growth_core.session_fact`

  UNION ALL
  SELECT 'canonical_orders', COUNT(*) = 4466, FORMAT('%d orders', COUNT(*))
  FROM `growth_core.order_fact`

  UNION ALL
  SELECT 'invalid_transaction_sentinel_excluded',
    COUNTIF(LOWER(TRIM(ecommerce_transaction_id)) = '(not set)') = 0,
    FORMAT('%d sentinel orders retained', COUNTIF(LOWER(TRIM(ecommerce_transaction_id)) = '(not set)'))
  FROM `growth_core.order_fact`

  UNION ALL
  SELECT 'no_valid_order_key_repeats_across_dates',
    COUNT(*) = 0,
    FORMAT('%d user-transaction pairs span multiple dates', COUNT(*))
  FROM (
    SELECT user_pseudo_id, ecommerce_transaction_id
    FROM `growth_core.order_fact`
    GROUP BY user_pseudo_id, ecommerce_transaction_id
    HAVING COUNT(DISTINCT order_date) > 1
  )

  UNION ALL
  SELECT 'order_revenue_policy_partition',
    COUNT(*) = COUNTIF(revenue_recognized) + COUNTIF(revenue_all_null) + COUNTIF(revenue_conflict),
    FORMAT('%d total = %d recognized + %d all-null + %d conflict',
      COUNT(*), COUNTIF(revenue_recognized), COUNTIF(revenue_all_null), COUNTIF(revenue_conflict))
  FROM `growth_core.order_fact`

  UNION ALL
  SELECT 'recognized_revenue_requires_one_nonnull_value',
    COUNTIF((recognized_revenue_usd IS NOT NULL) != revenue_recognized) = 0,
    FORMAT('%d inconsistent orders', COUNTIF((recognized_revenue_usd IS NOT NULL) != revenue_recognized))
  FROM `growth_core.order_fact`

  UNION ALL
  SELECT 'no_earliest_row_revenue_loss',
    COUNTIF(nonnull_revenue_rows > 0 AND distinct_nonnull_revenue_values = 1 AND recognized_revenue_usd IS NULL) = 0,
    FORMAT('%d recoverable revenues lost', COUNTIF(nonnull_revenue_rows > 0 AND distinct_nonnull_revenue_values = 1 AND recognized_revenue_usd IS NULL))
  FROM `growth_core.order_fact`

  UNION ALL
  SELECT 'revenue_conflicts_excluded',
    COUNTIF(revenue_conflict AND recognized_revenue_usd IS NOT NULL) = 0,
    FORMAT('%d conflicts included in primary revenue', COUNTIF(revenue_conflict AND recognized_revenue_usd IS NOT NULL))
  FROM `growth_core.order_fact`
)
SELECT check_name, IF(passed, 'PASS', 'FAIL') AS status, detail
FROM checks
ORDER BY check_name;

-- Final QA gate: user population coverage and order-key uniqueness.

-- QA 1: every identifiable first_visit user should reach user_first_session.
WITH first_visit_users AS (
  SELECT
    user_pseudo_id,
    COUNTIF(session_key IS NOT NULL) AS linked_first_visit_rows
  FROM `growth_core.stg_ga4_events`
  WHERE event_name = 'first_visit' AND user_pseudo_id IS NOT NULL
  GROUP BY user_pseudo_id
)
SELECT
  'new_user_first_session_coverage' AS qa_name,
  COUNT(*) AS population_users,
  COUNTIF(linked_first_visit_rows > 0) AS covered_users,
  COUNTIF(linked_first_visit_rows = 0) AS uncovered_users,
  SAFE_DIVIDE(COUNTIF(linked_first_visit_rows > 0), COUNT(*)) AS coverage_rate,
  IF(COUNTIF(linked_first_visit_rows = 0) = 0, 'PASS', 'REVIEW') AS status
FROM first_visit_users;

-- QA 2a: quantify invalid '(not set)' purchase identifiers in the source.
SELECT
  'invalid_transaction_id_sentinel' AS qa_name,
  COUNT(*) AS source_purchase_rows,
  COUNT(DISTINCT CONCAT(user_pseudo_id, '|', CAST(event_date AS STRING))) AS affected_user_dates,
  COUNT(DISTINCT user_pseudo_id) AS affected_users,
  COUNT(DISTINCT CONCAT(user_pseudo_id, '|', ecommerce_transaction_id)) AS cross_user_transaction_pairs,
  'EXCLUDE_FROM_IDENTIFIABLE_ORDER_MODEL' AS status
FROM `growth_core.stg_ga4_events`
WHERE event_name = 'purchase'
  AND LOWER(TRIM(ecommerce_transaction_id)) = '(not set)';

-- QA 2b: after invalid-ID exclusion, no valid user-transaction pair may span dates.
WITH cross_day_valid_orders AS (
  SELECT user_pseudo_id, ecommerce_transaction_id
  FROM `growth_core.order_fact`
  GROUP BY user_pseudo_id, ecommerce_transaction_id
  HAVING COUNT(DISTINCT order_date) > 1
)
SELECT
  'valid_order_key_cross_day_uniqueness' AS qa_name,
  COUNT(*) AS cross_day_user_transaction_pairs,
  IF(COUNT(*) = 0, 'PASS', 'REVIEW') AS status
FROM cross_day_valid_orders;

-- Grain: one collision-resistant, identifiable canonical order.
-- Missing, blank, and GA4 sentinel transaction IDs are excluded from this
-- identifiable-order table and audited separately. In this sample, '(not set)'
-- is reused across dates and is not a valid business order identifier.
-- Revenue policy:
--   * one distinct non-NULL value -> recognized, regardless of duplicate event order;
--   * multiple distinct non-NULL values -> conflict and excluded from primary revenue;
--   * all NULL -> identifiable order with unrecognized revenue;
--   * a valid zero is retained as recognized zero revenue.

CREATE OR REPLACE VIEW `growth_core.order_fact` AS
WITH purchase_rows AS (
  SELECT
    CONCAT(
      user_pseudo_id,
      '|',
      CAST(event_date AS STRING),
      '|',
      ecommerce_transaction_id
    ) AS canonical_order_key,
    user_pseudo_id,
    event_date AS order_date,
    event_timestamp,
    event_datetime_utc,
    session_key,
    ecommerce_transaction_id,
    purchase_revenue_in_usd,
    first_touch_source,
    first_touch_medium,
    first_touch_campaign,
    device_category,
    country
  FROM `growth_core.stg_ga4_events`
  WHERE
    event_name = 'purchase'
    AND ecommerce_transaction_id IS NOT NULL
    AND TRIM(ecommerce_transaction_id) != ''
    AND LOWER(TRIM(ecommerce_transaction_id)) != '(not set)'
),
grouped AS (
  SELECT
    canonical_order_key,
    COUNT(*) AS source_purchase_rows,
    COUNTIF(purchase_revenue_in_usd IS NOT NULL) AS nonnull_revenue_rows,
    COUNT(DISTINCT purchase_revenue_in_usd) AS distinct_nonnull_revenue_values,
    MIN(purchase_revenue_in_usd) AS min_nonnull_revenue_usd,
    MAX(purchase_revenue_in_usd) AS max_nonnull_revenue_usd,
    ARRAY_AGG(STRUCT(
      user_pseudo_id,
      order_date,
      event_datetime_utc,
      session_key,
      ecommerce_transaction_id,
      first_touch_source,
      first_touch_medium,
      first_touch_campaign,
      device_category,
      country
    ) ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS first_purchase
  FROM purchase_rows
  GROUP BY canonical_order_key
)
SELECT
  canonical_order_key,
  first_purchase.user_pseudo_id,
  first_purchase.order_date,
  first_purchase.event_datetime_utc AS order_at_utc,
  first_purchase.session_key,
  first_purchase.ecommerce_transaction_id,
  CASE
    WHEN distinct_nonnull_revenue_values = 1 THEN max_nonnull_revenue_usd
    ELSE NULL
  END AS recognized_revenue_usd,
  first_purchase.first_touch_source,
  first_purchase.first_touch_medium,
  first_purchase.first_touch_campaign,
  first_purchase.device_category,
  first_purchase.country,
  source_purchase_rows,
  source_purchase_rows > 1 AS is_duplicate_order_key,
  nonnull_revenue_rows,
  distinct_nonnull_revenue_values,
  min_nonnull_revenue_usd,
  max_nonnull_revenue_usd,
  nonnull_revenue_rows = 0 AS revenue_all_null,
  distinct_nonnull_revenue_values = 1 AS revenue_recognized,
  distinct_nonnull_revenue_values = 1 AND max_nonnull_revenue_usd = 0 AS zero_revenue_order,
  distinct_nonnull_revenue_values > 1 AS revenue_conflict
FROM grouped;

-- Read-only audit for the public GA4 sample.
-- This file records the final identity, first-touch, sequence, and transaction checks.

WITH base AS (
  SELECT
    event_date,
    event_timestamp,
    event_name,
    user_pseudo_id,
    user_id,
    user_first_touch_timestamp,
    CONCAT(
      user_pseudo_id,
      '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    ) AS session_key,
    ecommerce.transaction_id AS tx_id,
    ecommerce.purchase_revenue_in_usd AS usd_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
user_profile AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS observed_first_date,
    MIN(IF(event_name = 'first_visit', event_date, NULL)) AS first_visit_date,
    MIN(IF(
      user_first_touch_timestamp IS NOT NULL,
      FORMAT_DATE('%Y%m%d', DATE(TIMESTAMP_MICROS(user_first_touch_timestamp))),
      NULL
    )) AS first_touch_utc_date,
    COUNTIF(user_id IS NOT NULL AND user_id != '') > 0 AS has_user_id
  FROM base
  GROUP BY user_pseudo_id
),
same_event_ts AS (
  SELECT session_key, event_timestamp, event_name, COUNT(*) AS rows_in_group
  FROM base
  WHERE session_key IS NOT NULL
  GROUP BY session_key, event_timestamp, event_name
  HAVING COUNT(*) > 1
),
purchase_tx AS (
  SELECT
    tx_id,
    COUNT(*) AS rows_per_tx,
    COUNT(DISTINCT user_pseudo_id) AS users_per_tx,
    COUNT(DISTINCT event_date) AS dates_per_tx,
    COUNT(DISTINCT usd_revenue) AS revenue_values
  FROM base
  WHERE event_name = 'purchase' AND tx_id IS NOT NULL AND tx_id != ''
  GROUP BY tx_id
)
SELECT 'identity' AS section, 'users' AS metric, CAST(COUNT(*) AS STRING) AS value FROM user_profile
UNION ALL SELECT 'identity', 'users_with_user_id', CAST(COUNTIF(has_user_id) AS STRING) FROM user_profile
UNION ALL SELECT 'first_touch', 'users_with_first_visit', CAST(COUNTIF(first_visit_date IS NOT NULL) AS STRING) FROM user_profile
UNION ALL SELECT 'first_touch', 'users_missing_first_touch_timestamp', CAST(COUNTIF(first_touch_utc_date IS NULL) AS STRING) FROM user_profile
UNION ALL SELECT 'first_touch', 'first_visit_equals_first_touch_utc', CAST(COUNTIF(first_visit_date = first_touch_utc_date) AS STRING) FROM user_profile
UNION ALL SELECT 'sequence', 'duplicate_same_event_timestamp_groups', CAST(COUNT(*) AS STRING) FROM same_event_ts
UNION ALL SELECT 'sequence', 'extra_rows_in_same_event_timestamp_groups', CAST(COALESCE(SUM(rows_in_group - 1), 0) AS STRING) FROM same_event_ts
UNION ALL SELECT 'transaction', 'duplicate_tx_ids', CAST(COUNTIF(rows_per_tx > 1) AS STRING) FROM purchase_tx
UNION ALL SELECT 'transaction', 'duplicate_tx_cross_users', CAST(COUNTIF(rows_per_tx > 1 AND users_per_tx > 1) AS STRING) FROM purchase_tx
UNION ALL SELECT 'transaction', 'duplicate_tx_cross_dates', CAST(COUNTIF(rows_per_tx > 1 AND dates_per_tx > 1) AS STRING) FROM purchase_tx
UNION ALL SELECT 'transaction', 'duplicate_tx_different_revenue', CAST(COUNTIF(rows_per_tx > 1 AND revenue_values > 1) AS STRING) FROM purchase_tx
ORDER BY section, metric;


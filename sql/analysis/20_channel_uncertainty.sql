-- Grain: one source/medium x quality metric.
-- Binary rates use Wilson 95% intervals. Fixed-window value reports mean,
-- standard error and distribution quantiles over all eligible users (including zero).

WITH base AS (
  SELECT
    COALESCE(first_touch_source, '(missing)') AS first_touch_source,
    COALESCE(first_touch_medium, '(missing)') AS first_touch_medium,
    LOWER(COALESCE(first_touch_source, '')) = 'shop.googlemerchandisestore.com'
      AND LOWER(COALESCE(first_touch_medium, '')) = 'referral' AS is_probable_self_referral,
    b.* EXCEPT(first_touch_source, first_touch_medium)
  FROM `growth_core.early_behavior_features`
  AS b
),
channel_gate AS (
  SELECT first_touch_source, first_touch_medium,
    COUNT(*) AS new_users,
    COUNTIF(d7_product_returned IS NOT NULL) AS d7_eligible_users
  FROM base
  WHERE NOT is_probable_self_referral
  GROUP BY 1, 2
  HAVING new_users >= 500 AND d7_eligible_users >= 500
),
binary_long AS (
  SELECT
    b.first_touch_source,
    b.first_touch_medium,
    m.metric_name,
    m.is_eligible,
    m.is_positive
  FROM base AS b
  INNER JOIN channel_gate AS g USING (first_touch_source, first_touch_medium),
  UNNEST([
    STRUCT('primary_activation' AS metric_name, TRUE AS is_eligible, b.activated_primary AS is_positive),
    STRUCT('meaningful_activation_24h', b.feature_24h_eligible, COALESCE(b.meaningful_activation_24h, FALSE)),
    STRUCT('d7_product_return', b.d7_product_returned IS NOT NULL, COALESCE(b.d7_product_returned, FALSE)),
    STRUCT('d30_product_return', b.d30_product_returned IS NOT NULL, COALESCE(b.d30_product_returned, FALSE)),
    STRUCT('future_conversion_24h_to_30d', b.future_30d_eligible, COALESCE(b.converted_24h_to_30d, FALSE)),
    STRUCT('future_positive_recognized_value_24h_to_30d', b.future_30d_eligible, COALESCE(b.has_positive_recognized_value_24h_to_30d, FALSE))
  ]) AS m
),
binary_counts AS (
  SELECT first_touch_source, first_touch_medium, metric_name,
    COUNTIF(is_eligible) AS n,
    COUNTIF(is_eligible AND is_positive) AS x
  FROM binary_long
  GROUP BY 1, 2, 3
),
binary_intervals AS (
  SELECT
    *,
    SAFE_DIVIDE(x, n) AS estimate,
    SAFE_DIVIDE(
      SAFE_DIVIDE(x, n) + SAFE_DIVIDE(1.96 * 1.96, 2 * n)
        - 1.96 * SQRT(SAFE_DIVIDE(SAFE_DIVIDE(x, n) * (1 - SAFE_DIVIDE(x, n)), n) + SAFE_DIVIDE(1.96 * 1.96, 4 * n * n)),
      1 + SAFE_DIVIDE(1.96 * 1.96, n)
    ) AS ci_low,
    SAFE_DIVIDE(
      SAFE_DIVIDE(x, n) + SAFE_DIVIDE(1.96 * 1.96, 2 * n)
        + 1.96 * SQRT(SAFE_DIVIDE(SAFE_DIVIDE(x, n) * (1 - SAFE_DIVIDE(x, n)), n) + SAFE_DIVIDE(1.96 * 1.96, 4 * n * n)),
      1 + SAFE_DIVIDE(1.96 * 1.96, n)
    ) AS ci_high
  FROM binary_counts
),
value_stats AS (
  SELECT
    b.first_touch_source,
    b.first_touch_medium,
    COUNTIF(b.future_30d_eligible) AS n,
    AVG(IF(b.future_30d_eligible, b.recognized_revenue_24h_to_30d_usd, NULL)) AS estimate,
    SAFE_DIVIDE(
      STDDEV_SAMP(IF(b.future_30d_eligible, b.recognized_revenue_24h_to_30d_usd, NULL)),
      SQRT(COUNTIF(b.future_30d_eligible))
    ) AS standard_error,
    APPROX_QUANTILES(IF(b.future_30d_eligible, b.recognized_revenue_24h_to_30d_usd, NULL), 100 IGNORE NULLS)[OFFSET(50)] AS median,
    APPROX_QUANTILES(IF(b.future_30d_eligible, b.recognized_revenue_24h_to_30d_usd, NULL), 100 IGNORE NULLS)[OFFSET(75)] AS p75,
    APPROX_QUANTILES(IF(b.future_30d_eligible, b.recognized_revenue_24h_to_30d_usd, NULL), 100 IGNORE NULLS)[OFFSET(90)] AS p90
  FROM base AS b
  INNER JOIN channel_gate AS g USING (first_touch_source, first_touch_medium)
  GROUP BY 1, 2
)
SELECT
  'binary_rate' AS section,
  first_touch_source,
  first_touch_medium,
  metric_name,
  n,
  x,
  estimate,
  ci_low,
  ci_high,
  CAST(NULL AS FLOAT64) AS standard_error,
  CAST(NULL AS FLOAT64) AS median,
  CAST(NULL AS FLOAT64) AS p75,
  CAST(NULL AS FLOAT64) AS p90
FROM binary_intervals

UNION ALL
SELECT
  'fixed_window_value', first_touch_source, first_touch_medium,
  'recognized_value_per_eligible_user_24h_to_30d', n, CAST(NULL AS INT64),
  estimate, CAST(NULL AS FLOAT64), CAST(NULL AS FLOAT64),
  standard_error, median, p75, p90
FROM value_stats

ORDER BY first_touch_source, first_touch_medium, section, metric_name;

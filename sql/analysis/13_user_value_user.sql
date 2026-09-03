-- Grain: one device-level new user.
-- Value bands are relative to positive-revenue users in this dataset.

CREATE OR REPLACE VIEW `growth_core.user_value_user` AS
WITH user_value AS (
  SELECT
    u.user_pseudo_id,
    u.cohort_date,
    u.first_touch_source,
    u.first_touch_medium,
    u.first_touch_campaign,
    u.activated_primary,
    COUNT(o.canonical_order_key) AS canonical_orders,
    COUNTIF(o.revenue_recognized) AS revenue_recognized_orders,
    COUNTIF(o.revenue_all_null) AS revenue_null_orders,
    COUNTIF(o.zero_revenue_order) AS zero_revenue_orders,
    COUNTIF(o.revenue_conflict) AS revenue_conflict_orders,
    COALESCE(SUM(o.recognized_revenue_usd), 0) AS recognized_revenue_usd,
    MIN(o.order_at_utc) AS first_order_at_utc,
    MAX(o.order_at_utc) AS last_order_at_utc
  FROM `growth_core.user_first_session` AS u
  LEFT JOIN `growth_core.order_fact` AS o
    ON u.user_pseudo_id = o.user_pseudo_id
    AND o.order_at_utc >= u.first_visit_at_utc
  GROUP BY
    u.user_pseudo_id, u.cohort_date, u.first_touch_source,
    u.first_touch_medium, u.first_touch_campaign, u.activated_primary
),
positive_value_cutoffs AS (
  SELECT
    APPROX_QUANTILES(recognized_revenue_usd, 4)[OFFSET(1)] AS positive_value_p25,
    APPROX_QUANTILES(recognized_revenue_usd, 4)[OFFSET(3)] AS positive_value_p75
  FROM user_value
  WHERE recognized_revenue_usd > 0
)
SELECT
  v.*,
  e.future_30d_eligible,
  e.canonical_orders_24h_to_30d,
  e.revenue_recognized_orders_24h_to_30d,
  e.revenue_null_orders_24h_to_30d,
  e.zero_revenue_orders_24h_to_30d,
  e.revenue_conflict_orders_24h_to_30d,
  e.recognized_revenue_24h_to_30d_usd,
  e.has_identifiable_order_24h_to_30d,
  e.has_recognized_revenue_24h_to_30d,
  e.has_positive_recognized_value_24h_to_30d,
  SAFE_DIVIDE(e.recognized_revenue_24h_to_30d_usd, NULLIF(e.revenue_recognized_orders_24h_to_30d, 0)) AS recognized_aov_24h_to_30d_usd,
  SAFE_DIVIDE(v.recognized_revenue_usd, NULLIF(v.revenue_recognized_orders, 0)) AS recognized_aov_usd,
  CASE
    WHEN v.recognized_revenue_usd = 0 THEN 'No recognized value'
    WHEN v.recognized_revenue_usd <= c.positive_value_p25 THEN 'Low'
    WHEN v.recognized_revenue_usd <= c.positive_value_p75 THEN 'Medium'
    ELSE 'High'
  END AS value_band,
  c.positive_value_p25,
  c.positive_value_p75
FROM user_value AS v
CROSS JOIN positive_value_cutoffs AS c
LEFT JOIN `growth_core.early_behavior_features` AS e
  USING (user_pseudo_id);

-- Grain: one device-level new user at the maximum observed data date.
-- Lifecycle is descriptive within the 92-day data window.

CREATE OR REPLACE VIEW `growth_core.lifecycle_user_snapshot` AS
WITH bounds AS (
  SELECT MAX(activity_date) AS snapshot_date
  FROM `growth_core.user_day_activity`
),
user_observation AS (
  SELECT
    u.user_pseudo_id,
    u.cohort_date,
    u.first_touch_source,
    u.first_touch_medium,
    u.first_touch_campaign,
    u.device_category,
    b.snapshot_date,
    DATE_DIFF(b.snapshot_date, u.cohort_date, DAY) + 1 AS days_observed,
    COUNTIF(a.engaged_sessions > 0) > 0 AS ever_engaged,
    COUNTIF(a.core_value_events > 0) > 0 AS ever_core_value_reached,
    COUNTIF(a.high_intent_events > 0) > 0 AS ever_high_intent,
    COUNTIF(a.canonical_orders > 0) > 0 AS ever_converted,
    MAX(IF(a.engaged_sessions > 0, a.activity_date, NULL)) AS last_engaged_date,
    COALESCE(SUM(a.canonical_orders), 0) AS canonical_orders,
    COALESCE(SUM(a.recognized_revenue_usd), 0) AS recognized_revenue_usd
  FROM `growth_core.user_first_session` AS u
  CROSS JOIN bounds AS b
  LEFT JOIN `growth_core.user_day_activity` AS a
    ON u.user_pseudo_id = a.user_pseudo_id
  GROUP BY
    u.user_pseudo_id, u.cohort_date, u.first_touch_source,
    u.first_touch_medium, u.first_touch_campaign, u.device_category,
    b.snapshot_date
)
SELECT
  *,
  CASE
    WHEN ever_converted THEN 'Converted'
    WHEN ever_high_intent THEN 'High-intent'
    WHEN ever_core_value_reached THEN 'Core Value Reached'
    WHEN ever_engaged THEN 'Engaged'
    ELSE 'New'
  END AS highest_stage,
  CASE
    WHEN last_engaged_date >= DATE_SUB(snapshot_date, INTERVAL 6 DAY) THEN 'Active'
    WHEN days_observed < 8 THEN 'Not Mature'
    WHEN last_engaged_date >= DATE_SUB(snapshot_date, INTERVAL 29 DAY) THEN 'Cooling'
    WHEN days_observed >= 30 THEN 'Dormant'
    ELSE 'Not Mature'
  END AS activity_status
FROM user_observation;

-- Grain: one new user x retention day offset.
-- Ineligible rows are kept with NULL outcomes to make right-censoring explicit.

CREATE OR REPLACE VIEW `growth_core.retention_user` AS
WITH dataset_bounds AS (
  SELECT MAX(event_date) AS max_event_date
  FROM `growth_core.stg_ga4_events`
),
cohort_grid AS (
  SELECT
    u.user_pseudo_id,
    u.cohort_date,
    u.first_touch_source,
    u.first_touch_medium,
    u.first_touch_campaign,
    u.activated_primary,
    day_offset,
    DATE_ADD(u.cohort_date, INTERVAL day_offset DAY) AS target_date,
    DATE_ADD(u.cohort_date, INTERVAL day_offset DAY) <= b.max_event_date AS is_eligible
  FROM `growth_core.user_first_session` AS u
  CROSS JOIN UNNEST([1, 3, 7, 14, 30]) AS day_offset
  CROSS JOIN dataset_bounds AS b
)
SELECT
  g.user_pseudo_id,
  g.cohort_date,
  g.day_offset,
  g.target_date,
  g.is_eligible,
  IF(g.is_eligible, COALESCE(a.is_product_return_activity, FALSE), NULL) AS product_returned,
  IF(g.is_eligible, COALESCE(a.is_core_behavior_activity, FALSE), NULL) AS core_behavior_returned,
  g.activated_primary,
  g.first_touch_source,
  g.first_touch_medium,
  g.first_touch_campaign
FROM cohort_grid AS g
LEFT JOIN `growth_core.user_day_activity` AS a
  ON g.user_pseudo_id = a.user_pseudo_id
  AND g.target_date = a.activity_date;

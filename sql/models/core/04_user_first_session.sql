-- Grain: one device-level new user with a first_visit event.
-- This is the canonical population for acquisition and activation analyses.

CREATE OR REPLACE VIEW `growth_core.user_first_session` AS
WITH ranked_first_visit_sessions AS (
  SELECT
    sf.*,
    ROW_NUMBER() OVER (
      PARTITION BY user_pseudo_id
      ORDER BY first_visit_at_utc, session_start_at_utc, session_key
    ) AS first_visit_session_rank
  FROM `growth_core.session_fact` AS sf
  WHERE has_first_visit
),
first_session_items AS (
  SELECT
    e.user_pseudo_id,
    e.session_key,
    COUNT(DISTINCT item.item_id) AS unique_items_viewed_first_session
  FROM `growth_core.stg_ga4_events` AS e
  INNER JOIN ranked_first_visit_sessions AS f
    ON e.session_key = f.session_key
    AND f.first_visit_session_rank = 1
  CROSS JOIN UNNEST(e.items) AS item
  WHERE e.event_name = 'view_item'
  GROUP BY e.user_pseudo_id, e.session_key
)
SELECT
  f.user_pseudo_id,
  f.session_key AS first_session_key,
  f.session_date AS cohort_date,
  f.first_visit_at_utc,
  f.session_start_at_utc,
  f.session_end_at_utc,
  f.event_count AS first_session_event_count,
  f.valid_event_count AS first_session_valid_event_count,
  f.distinct_pages AS first_session_distinct_pages,
  f.engagement_time_msec AS first_session_engagement_time_msec,
  COALESCE(i.unique_items_viewed_first_session, 0) AS unique_items_viewed_first_session,
  f.is_engaged_session,
  f.has_core_value AS activated_primary,
  f.has_high_intent AS has_high_intent_first_session,
  f.has_conversion AS converted_first_session,
  f.first_engagement_at_utc,
  f.first_core_value_at_utc,
  f.first_high_intent_at_utc,
  f.first_conversion_at_utc,
  f.first_engagement_at_utc IS NOT NULL
    AND f.first_engagement_at_utc > f.first_visit_at_utc AS ordered_reached_engagement,
  f.first_core_value_at_utc IS NOT NULL
    AND f.first_engagement_at_utc IS NOT NULL
    AND f.first_core_value_at_utc > f.first_engagement_at_utc AS ordered_reached_core_value,
  f.first_high_intent_at_utc IS NOT NULL
    AND f.first_core_value_at_utc IS NOT NULL
    AND f.first_high_intent_at_utc > f.first_core_value_at_utc AS ordered_reached_high_intent,
  f.first_touch_source,
  f.first_touch_medium,
  f.first_touch_campaign,
  f.session_source AS first_session_source,
  f.session_medium AS first_session_medium,
  f.session_campaign AS first_session_campaign,
  f.device_category,
  f.operating_system,
  f.browser,
  f.country,
  f.region,
  f.city
FROM ranked_first_visit_sessions AS f
LEFT JOIN first_session_items AS i
  ON f.user_pseudo_id = i.user_pseudo_id
  AND f.session_key = i.session_key
WHERE f.first_visit_session_rank = 1;

-- Grain: one composite GA4 session.

CREATE OR REPLACE VIEW `growth_core.session_fact` AS
SELECT
  session_key,
  user_pseudo_id,
  ga_session_id,
  MIN(ga_session_number) AS ga_session_number,
  MIN(event_datetime_utc) AS session_start_at_utc,
  MAX(event_datetime_utc) AS session_end_at_utc,
  MIN(event_date) AS session_date,
  COUNT(*) AS event_count,
  COUNTIF(is_valid_activity_event) AS valid_event_count,
  COUNT(DISTINCT page_location) AS distinct_pages,
  COALESCE(SUM(engagement_time_msec), 0) AS engagement_time_msec,
  COALESCE(LOGICAL_OR(is_engaged_event), FALSE) AS is_engaged_session,
  LOGICAL_OR(event_name = 'first_visit') AS has_first_visit,
  LOGICAL_OR(is_core_value_event) AS has_core_value,
  LOGICAL_OR(is_high_intent_event) AS has_high_intent,
  LOGICAL_OR(event_name = 'begin_checkout') AS has_begin_checkout,
  LOGICAL_OR(is_conversion_event) AS has_conversion,
  MIN(IF(event_name = 'first_visit', event_datetime_utc, NULL)) AS first_visit_at_utc,
  MIN(IF(is_engaged_event OR event_name = 'user_engagement', event_datetime_utc, NULL)) AS first_engagement_at_utc,
  MIN(IF(is_core_value_event, event_datetime_utc, NULL)) AS first_core_value_at_utc,
  MIN(IF(is_high_intent_event, event_datetime_utc, NULL)) AS first_high_intent_at_utc,
  MIN(IF(event_name = 'begin_checkout', event_datetime_utc, NULL)) AS first_begin_checkout_at_utc,
  MIN(IF(is_conversion_event, event_datetime_utc, NULL)) AS first_conversion_at_utc,
  ARRAY_AGG(session_source_raw IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS session_source,
  ARRAY_AGG(session_medium_raw IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS session_medium,
  ARRAY_AGG(session_campaign_raw IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS session_campaign,
  ANY_VALUE(first_touch_source) AS first_touch_source,
  ANY_VALUE(first_touch_medium) AS first_touch_medium,
  ANY_VALUE(first_touch_campaign) AS first_touch_campaign,
  ANY_VALUE(device_category) AS device_category,
  ANY_VALUE(operating_system) AS operating_system,
  ANY_VALUE(browser) AS browser,
  ANY_VALUE(country) AS country,
  ANY_VALUE(region) AS region,
  ANY_VALUE(city) AS city
FROM `growth_core.stg_ga4_events`
WHERE session_key IS NOT NULL
GROUP BY session_key, user_pseudo_id, ga_session_id;

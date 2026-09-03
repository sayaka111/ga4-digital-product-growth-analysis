-- Grain: one exported GA4 event row.
-- Creates the normalized event layer used by all downstream models.

CREATE OR REPLACE VIEW `growth_core.stg_ga4_events` AS
WITH extracted AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp,
    TIMESTAMP_MICROS(event_timestamp) AS event_datetime_utc,
    event_name,
    user_pseudo_id,
    user_id,
    user_first_touch_timestamp,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS ga_session_number,
    COALESCE(
      SAFE_CAST((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged') AS INT64),
      (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_engaged')
    ) AS session_engaged_value,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title') AS page_title,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS session_source_raw,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS session_medium_raw,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign') AS session_campaign_raw,
    traffic_source.source AS first_touch_source,
    traffic_source.medium AS first_touch_medium,
    traffic_source.name AS first_touch_campaign,
    device.category AS device_category,
    device.operating_system,
    device.web_info.browser AS browser,
    geo.country,
    geo.region,
    geo.city,
    ecommerce.transaction_id AS ecommerce_transaction_id,
    ecommerce.purchase_revenue_in_usd AS purchase_revenue_in_usd,
    items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)
SELECT
  *,
  CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key,
  session_engaged_value = 1 AS is_engaged_event,
  event_name NOT IN ('session_start', 'first_visit') AS is_valid_activity_event,
  event_name = 'view_item' AS is_core_value_event,
  event_name = 'add_to_cart' AS is_high_intent_event,
  event_name = 'purchase' AS is_conversion_event
FROM extracted;

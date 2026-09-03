-- Grain: one session.
-- Ordered stages require strictly increasing timestamps. Equal timestamps are
-- retained as explicit order-unknown flags and are not treated as observed order.

CREATE OR REPLACE VIEW `growth_core.conversion_funnel_session` AS
SELECT
  session_key,
  user_pseudo_id,
  session_date,
  first_touch_source,
  first_touch_medium,
  first_touch_campaign,
  device_category,
  country,
  has_core_value AS reached_core_value,
  has_high_intent AS reached_high_intent,
  has_begin_checkout AS reached_begin_checkout,
  has_conversion AS reached_conversion,
  first_core_value_at_utc,
  first_high_intent_at_utc,
  first_begin_checkout_at_utc,
  first_conversion_at_utc,
  has_core_value AND has_high_intent
    AND first_high_intent_at_utc = first_core_value_at_utc AS core_high_intent_timestamp_tie,
  has_high_intent AND has_begin_checkout
    AND first_begin_checkout_at_utc = first_high_intent_at_utc AS high_intent_checkout_timestamp_tie,
  has_begin_checkout AND has_conversion
    AND first_conversion_at_utc = first_begin_checkout_at_utc AS checkout_conversion_timestamp_tie,
  has_core_value AS ordered_core_value,
  has_core_value
    AND has_high_intent
    AND first_high_intent_at_utc > first_core_value_at_utc AS ordered_high_intent,
  has_core_value
    AND has_high_intent
    AND has_begin_checkout
    AND first_high_intent_at_utc > first_core_value_at_utc
    AND first_begin_checkout_at_utc > first_high_intent_at_utc AS ordered_begin_checkout,
  has_core_value
    AND has_high_intent
    AND has_begin_checkout
    AND has_conversion
    AND first_high_intent_at_utc > first_core_value_at_utc
    AND first_begin_checkout_at_utc > first_high_intent_at_utc
    AND first_conversion_at_utc > first_begin_checkout_at_utc AS ordered_conversion
FROM `growth_core.session_fact`;

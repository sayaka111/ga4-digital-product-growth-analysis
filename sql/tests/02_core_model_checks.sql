-- Structural checks for the user-growth core models.

WITH checks AS (
  SELECT
    'first_visit_users_fully_covered_by_first_session' AS check_name,
    COUNT(*) = COUNTIF(u.user_pseudo_id IS NOT NULL) AS passed,
    FORMAT('%d / %d first-visit users modeled', COUNTIF(u.user_pseudo_id IS NOT NULL), COUNT(*)) AS detail
  FROM (
    SELECT DISTINCT user_pseudo_id
    FROM `growth_core.stg_ga4_events`
    WHERE event_name = 'first_visit' AND user_pseudo_id IS NOT NULL
  ) AS f
  LEFT JOIN `growth_core.user_first_session` AS u
    USING (user_pseudo_id)

  UNION ALL
  SELECT
    'one_first_session_per_new_user' AS check_name,
    COUNT(*) = COUNT(DISTINCT user_pseudo_id) AND COUNT(*) = 257314 AS passed,
    FORMAT('%d rows / %d users', COUNT(*), COUNT(DISTINCT user_pseudo_id)) AS detail
  FROM `growth_core.user_first_session`

  UNION ALL
  SELECT
    'unique_user_day_grain',
    COUNT(*) = COUNT(DISTINCT CONCAT(user_pseudo_id, '|', CAST(activity_date AS STRING))),
    FORMAT('%d rows', COUNT(*))
  FROM `growth_core.user_day_activity`

  UNION ALL
  SELECT
    'five_retention_offsets_per_new_user',
    COUNT(*) = 257314 * 5,
    FORMAT('%d rows', COUNT(*))
  FROM `growth_core.retention_user`

  UNION ALL
  SELECT
    'one_funnel_row_per_session',
    COUNT(*) = 360129 AND COUNT(*) = COUNT(DISTINCT session_key),
    FORMAT('%d rows', COUNT(*))
  FROM `growth_core.conversion_funnel_session`

  UNION ALL
  SELECT
    'ordered_funnel_excludes_timestamp_ties',
    COUNTIF((core_high_intent_timestamp_tie AND ordered_high_intent)
      OR (high_intent_checkout_timestamp_tie AND ordered_begin_checkout)
      OR (checkout_conversion_timestamp_tie AND ordered_conversion)) = 0,
    FORMAT('%d tied sequences incorrectly treated as ordered', COUNTIF(
      (core_high_intent_timestamp_tie AND ordered_high_intent)
      OR (high_intent_checkout_timestamp_tie AND ordered_begin_checkout)
      OR (checkout_conversion_timestamp_tie AND ordered_conversion)))
  FROM `growth_core.conversion_funnel_session`

  UNION ALL
  SELECT
    'one_early_feature_row_per_new_user',
    COUNT(*) = 257314 AND COUNT(*) = COUNT(DISTINCT user_pseudo_id),
    FORMAT('%d rows', COUNT(*))
  FROM `growth_core.early_behavior_features`
)
SELECT
  check_name,
  IF(passed, 'PASS', 'FAIL') AS status,
  detail
FROM checks
ORDER BY check_name;

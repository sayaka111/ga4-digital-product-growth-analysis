-- Question: did users acquired in November and December differ in first-session
-- funnel quality after standardizing first-touch source/medium x device mix?
-- Grain: one acquisition cohort month; exactly one first session per new user.
-- This equal lifecycle-relative window avoids unrestricted future-session bias.

WITH session_base AS (
  SELECT
    FORMAT_DATE('%Y-%m', u.cohort_date) AS cohort_month,
    COALESCE(f.first_touch_source, '(missing)') AS first_touch_source,
    COALESCE(f.first_touch_medium, '(missing)') AS first_touch_medium,
    COALESCE(f.device_category, '(missing)') AS device_category,
    f.ordered_core_value,
    f.ordered_high_intent
  FROM `growth_core.conversion_funnel_session` AS f
  INNER JOIN `growth_core.user_first_session` AS u
    ON f.session_key = u.first_session_key
  WHERE FORMAT_DATE('%Y-%m', u.cohort_date) IN ('2020-11', '2020-12')
),
month_strata AS (
  SELECT
    cohort_month,
    first_touch_source,
    first_touch_medium,
    device_category,
    COUNTIF(ordered_core_value) AS core_sessions,
    COUNTIF(ordered_high_intent) AS high_intent_sessions,
    SAFE_DIVIDE(COUNTIF(ordered_high_intent), COUNTIF(ordered_core_value)) AS core_to_high_intent_rate
  FROM session_base
  GROUP BY 1, 2, 3, 4
),
common_strata AS (
  SELECT first_touch_source, first_touch_medium, device_category
  FROM month_strata
  WHERE core_sessions >= 30
  GROUP BY 1, 2, 3
  HAVING COUNT(DISTINCT cohort_month) = 2
),
weighted AS (
  SELECT
    m.*,
    SUM(m.core_sessions) OVER (PARTITION BY m.first_touch_source, m.first_touch_medium, m.device_category) AS pooled_stratum_core_sessions
  FROM month_strata AS m
  INNER JOIN common_strata AS c
    USING (first_touch_source, first_touch_medium, device_category)
),
weights AS (
  SELECT
    *,
    SAFE_DIVIDE(
      pooled_stratum_core_sessions,
      SUM(pooled_stratum_core_sessions) OVER (PARTITION BY cohort_month)
    ) AS pooled_mix_weight
  FROM weighted
)
SELECT
  cohort_month,
  SUM(core_sessions) AS common_support_core_sessions,
  SAFE_DIVIDE(SUM(high_intent_sessions), SUM(core_sessions)) AS crude_common_support_rate,
  SUM(pooled_mix_weight * core_to_high_intent_rate) AS standardized_core_to_high_intent_rate,
  COUNT(*) AS common_support_strata
FROM weights
GROUP BY cohort_month
ORDER BY cohort_month;

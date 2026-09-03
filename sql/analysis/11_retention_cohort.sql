-- Grain: cohort date x exact calendar-day offset.
-- Eligible users are the only denominator for retention rates.

CREATE OR REPLACE VIEW `growth_core.retention_cohort` AS
SELECT
  cohort_date,
  day_offset,
  COUNT(*) AS cohort_users,
  COUNTIF(is_eligible) AS eligible_users,
  COUNTIF(product_returned) AS product_returned_users,
  SAFE_DIVIDE(COUNTIF(product_returned), COUNTIF(is_eligible)) AS product_return_rate,
  COUNTIF(core_behavior_returned) AS core_behavior_returned_users,
  SAFE_DIVIDE(COUNTIF(core_behavior_returned), COUNTIF(is_eligible)) AS core_behavior_return_rate,
  COUNTIF(is_eligible AND activated_primary) AS eligible_activated_users,
  SAFE_DIVIDE(
    COUNTIF(is_eligible AND activated_primary AND product_returned),
    COUNTIF(is_eligible AND activated_primary)
  ) AS activated_product_return_rate,
  SAFE_DIVIDE(
    COUNTIF(is_eligible AND NOT activated_primary AND product_returned),
    COUNTIF(is_eligible AND NOT activated_primary)
  ) AS nonactivated_product_return_rate
FROM `growth_core.retention_user`
GROUP BY cohort_date, day_offset;

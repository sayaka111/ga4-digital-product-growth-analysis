-- Read-only portfolio result extract from the contracted KPI view.

SELECT
  module,
  metric_name,
  numerator,
  denominator,
  metric_value,
  unit,
  scope
FROM `growth_core.portfolio_kpi_snapshot`
ORDER BY
  CASE module
    WHEN 'Acquisition' THEN 1
    WHEN 'Activation' THEN 2
    WHEN 'Conversion Funnel' THEN 3
    WHEN 'Conversion' THEN 4
    WHEN 'Retention' THEN 5
    WHEN 'Lifecycle' THEN 6
    WHEN 'User Value' THEN 7
    ELSE 99
  END,
  metric_name;

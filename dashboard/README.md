# 离线交互式分析看板

本看板围绕数字产品用户分析组织，而不是围绕商品销售报表组织。

## 已交付页面

1. 增长与获客：新用户、三层激活和渠道规模—质量矩阵。
2. 行为与漏斗：严格有序总体漏斗、实际日历月和首会话获客同期群诊断。
3. 留存与生命周期：精确日留存、全体互斥状态构成和不同成熟分母监控率。
4. 早期信号与价值：经验证的早期行为信号、固定窗口转化与价值结果。

粒度、口径、审计基线和限制收纳在页面底部的“方法与数据质量”折叠区，不占用业务页面。

## 页面与分析集市对应关系

| 页面 | 主要分析集市 | 必须展示的分母 |
|---|---|---|
| 用户增长与获客 | `acquisition_channel_quality` | 新用户数；第7日和第30日可观察用户数 |
| 行为与漏斗 | `activation_engagement_cohort`、`conversion_funnel_session` | 新用户数或到达上一阶段的实体数 |
| 留存与生命周期 | `retention_cohort`、`lifecycle_user_snapshot` | 可观察同期群用户数；已观察天数 |
| 早期信号与价值 | `early_behavior_user`、`user_value_user`、`order_fact` | 可观察用户数；固定窗口合格用户数；已识别订单数 |

所有留存图必须在提示或表格中展示可观察用户数。渠道排名不得隐藏小样本问题。

## 本地构建

```powershell
& '<Python路径>\python.exe' python/build_dashboard.py `
  --template dashboard/template.html `
  --kpis data/dashboard/dashboard_kpis.json `
  --effects outputs/early_behavior_effects.csv `
  --analysis-results data/dashboard/analysis_results.json `
  --uncertainty data/validation/channel_uncertainty.json `
  --standardized data/validation/early_behavior_standardized_rates.json `
  --funnel-standardization data/validation/funnel_cohort_standardization.json `
  --tests data/quality/analysis_mart_test_results.json
  --output dashboard/index.html
```

直接打开 `dashboard/index.html` 即可使用。该文件已经嵌入真实聚合结果，不包含 BigQuery 凭据，也不会发起网络请求。数据源为 Google 官方脱敏 GA4 样例，页面中的数值不代表真实商店生产经营指标。

静态预览位于 `dashboard/screenshots/page_1.png` 至 `page_4.png`；四页总览图为 `dashboard/screenshots/dashboard_overview.png`。

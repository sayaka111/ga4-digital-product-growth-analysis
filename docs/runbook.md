# 复现说明

## 1. 环境

- BigQuery Standard SQL；执行账户需要创建查询作业的权限，公共源数据保持只读。
- Python 3.11或更高版本；依赖见根目录 `requirements.txt`。
- Node.js 20或更高版本与 Playwright 用于生成看板截图。
- 浏览 `dashboard/index.html` 不需要联网或安装额外服务。

## 2. 数据源

源表为：

```text
bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*
```

首次运行时先执行 `sql/audit/01_data_availability_audit.sql`，确认日期范围、事件、用户、会话、来源、序列和电商字段仍与当前版本兼容。

## 3. BigQuery 环境

本项目使用 Google 官方公开 GA4 样例：

`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

分析模型默认写入当前 BigQuery 项目中的：

`growth_core`

运行 SQL 前，请先确认当前 BigQuery 执行项目具有创建 Dataset 和 Table 的权限。

SQL 中不固定具体 GCP Project ID，因此可以在不同 BigQuery 项目中复现。

## 4. SQL执行顺序

1. `sql/models/00_create_schema.sql`
2. `sql/models/staging/01_stg_ga4_events.sql`
3. `sql/models/core/02_session_fact.sql` 至 `08_early_behavior_features.sql`
4. `sql/analysis/09_acquisition_channel_quality.sql` 至 `20_channel_uncertainty.sql`
5. `sql/tests/01_foundation_checks.sql` 至 `03_analysis_mart_checks.sql`
6. `sql/audit/03_user_order_integrity_checks.sql`

按编号顺序运行，完成一层质量检查后再生成下一层。

## 5. Python处理

将 BigQuery 聚合结果按 `data/` 中现有 CSV/JSON 文件名导出，然后依次运行：

1. `python/early_behavior_validation.py`：从聚合计数生成统计效应文件。
2. `python/refresh_dashboard_data.py`：从聚合结果刷新 `data/dashboard/dashboard_kpis.json`。
3. `python/build_dashboard.py`：将结果嵌入离线看板。
4. `python/render_dashboard_previews.js`：生成四页看板截图。
5. `python/build_dashboard_contact_sheet.py`：生成看板总览图。

脚本参数可通过 `--help` 查看；以下示例均以项目根目录为当前工作目录，并使用相对路径传入脚本参数。Python 只处理聚合文件，不要求在本地保存用户级原始事件或 GCP 凭据。

## 6. Dashboard构建

看板模板位于 `dashboard/template.html`，构建输出为 `dashboard/index.html`。截图写入 `dashboard/screenshots/`：

- `page_1.png` 至 `page_4.png`
- `dashboard_overview.png`

构建后的 HTML 已嵌入聚合数据，不发起外部网络请求。

## 7. 最终输出

- `README.md`
- `docs/methodology.md`
- `docs/metric_definitions.md`
- `docs/data_quality_and_limitations.md`
- `docs/findings.md`
- `docs/strategy_hypotheses.md`
- `docs/technical_proof.md`
- `docs/runbook.md`
- `dashboard/index.html`
- `dashboard/screenshots/`
- `outputs/early_behavior_effects.csv`

若公共样例发生变化，应重新确认数据范围和字段支持，再重建全部下游输出；不要将当前数字手工复制到新版本。

# 聚合分析结果

本目录保存由 BigQuery SQL 与 Python 生成的聚合分析结果、统计验证结果和数据质量检查输出。
不包含 GA4 原始事件级数据。

## 目录结构

### `analysis/`
最终业务分析结果，包括：
- 激活
- 渠道质量
- 转化漏斗
- 生命周期
- 核心 KPI

### `validation/`
用于验证关键分析结论稳健性的统计输出，包括：
- 早期行为分组比较
- 渠道区间估计
- cohort / device / channel 标准化结果

### `quality/`
数据与模型质量检查结果，包括：
- 数据源可用性
- 模型粒度与唯一性
- 分析集市测试
- self-referral 检查
- 新用户首会话覆盖
- 订单唯一性与收入治理

### `dashboard/`
Dashboard 构建所需的 JSON 数据文件。

## 数据源

原始事件数据来自 Google 官方 BigQuery 公共样例：

`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

分析范围为 2020-11-01 至 2021-01-31。

本仓库不保存原始事件级数据。

核心指标定义见：
[`../docs/metric_definitions.md`](../docs/metric_definitions.md)

数据质量与分析限制见：
[`../docs/data_quality_and_limitations.md`](../docs/data_quality_and_limitations.md)
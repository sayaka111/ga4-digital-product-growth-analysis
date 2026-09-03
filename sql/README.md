# SQL 分析代码

本项目 SQL 按数据处理流程分为：

- `audit/`：数据可用性、母体和订单唯一性检查
- `models/staging/`：GA4 原始事件标准化
- `models/core/`：会话、首会话、用户日、留存、漏斗、早期行为与订单事实
- `analysis/`：获客、激活、漏斗、留存、生命周期、用户价值和统计输入
- `tests/`：事实层、核心模型和分析集市质量检查

执行顺序和依赖见 [`docs/runbook.md`](../docs/runbook.md)，模型职责见 [`docs/methodology.md`](../docs/methodology.md)。

项目内部模型统一使用 growth_core Dataset；具体 GCP Project 由运行环境决定。
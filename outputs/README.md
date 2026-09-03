# Python 统计验证

本模块用于验证“早期行为特征与后续用户质量之间的关联”，基于 BigQuery 输出的用户级/聚合结果进行统计比较。

主要输出包括：

- 分组样本量与目标事件发生率
- Wilson 95% 置信区间
- 风险差（Risk Difference）
- 风险比（Risk Ratio）
- 优势比（Odds Ratio）
- p 值与 Benjamini–Hochberg 多重检验校正 q 值

统计结果用于判断不同早期行为用户在后续留存、转化和用户价值上的差异强度，并作为策略假设的证据补充。所有结果均按描述性关联解释，不作因果推断。

主要输出文件：
- `early_behavior_effects.csv`
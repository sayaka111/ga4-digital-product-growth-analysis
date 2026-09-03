"""Refresh dashboard KPI JSON from executed BigQuery result files."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def as_number(value):
    if value in (None, ""):
        return None
    return float(value)


def normalize_portfolio_rows(rows):
    metric_names = {
        "Fixed-window recognized value per eligible user24h-to-30d":
            "Fixed-window recognized value per eligible user 24h-to-30d",
    }
    for row in rows:
        if row.get("module") == "UserValue":
            row["module"] = "User Value"
        row["metric_name"] = metric_names.get(row.get("metric_name"), row.get("metric_name"))
        row["metric_name"] = re.sub(r"^D(\d+)product", r"D\1 product", row["metric_name"])
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--portfolio", type=Path, required=True)
    parser.add_argument("--analysis-results", type=Path, required=True)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--user-order-integrity", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    dashboard = json.loads(args.base.read_text(encoding="utf-8"))
    portfolio_rows = normalize_portfolio_rows(json.loads(args.portfolio.read_text(encoding="utf-8")))
    analysis_rows = json.loads(args.analysis_results.read_text(encoding="utf-8"))
    audit_rows = json.loads(args.audit.read_text(encoding="utf-8"))
    audit_values = {row["metric"]: as_number(row["value"]) for row in audit_rows}
    user_order_integrity = json.loads(args.user_order_integrity.read_text(encoding="utf-8"))[0]
    qa = {key: as_number(value) if key not in ("qa1_status", "qa2_status") else value for key, value in user_order_integrity.items()}
    metrics = {row["metric_name"]: row for row in portfolio_rows}

    dashboard["meta"] = {
        "date_range": "2020-11-01 至 2021-01-31",
        "user_grain": "设备级用户（user_pseudo_id）",
        "calendar_day_semantics": "GA4 event_date（属性报表时区日期）",
        "rolling_window_semantics": "event_timestamp（协调世界时精确时间）",
        "source_disclaimer": "Google 官方脱敏 GA4 样例；结果用于验证分析方法，不代表商店真实生产经营指标。",
    }

    headline_contract = [
        ("新增设备用户", "New device users", "integer"),
        ("主激活率", "Primary activation rate", "percent"),
        ("有意义激活率", "Meaningful activation rate 24h", "percent"),
        ("第7日产品返回率", "D7 product return rate", "percent"),
    ]
    dashboard["headline"] = []
    for label, metric_name, value_format in headline_contract:
        row = metrics[metric_name]
        numerator = as_number(row["numerator"])
        denominator = as_number(row["denominator"])
        context = "发生 first_visit 的设备级用户" if denominator is None else f"{int(numerator):,} / {int(denominator):,}"
        dashboard["headline"].append(
            {
                "label": label,
                "value": as_number(row["metric_value"]),
                "format": value_format,
                "numerator": numerator,
                "denominator": denominator,
                "context": context,
            }
        )

    lifecycle_labels = {
        "Active": ("active", "活跃"),
        "Cooling": ("cooling", "近期未活跃"),
        "Dormant": ("dormant", "沉寂"),
        "Not Mature": ("not_mature", "未成熟"),
    }
    dashboard["lifecycle"] = []
    for row in analysis_rows:
        if row["section"] != "lifecycle":
            continue
        status_key, status_label = lifecycle_labels[row["dimension_1"]]
        dashboard["lifecycle"].append(
            {
                "status_key": status_key,
                "status_label": status_label,
                "users": int(as_number(row["n"])),
                "denominator": int(as_number(row["eligible_n"])),
                "share": as_number(row["metric_1"]),
            }
        )

    fixed_conversion = metrics["Fixed-window conversion rate 24h-to-30d"]
    fixed_positive = metrics["Fixed-window positive recognized value user rate 24h-to-30d"]
    fixed_value = metrics["Fixed-window recognized value per eligible user 24h-to-30d"]
    dashboard["fixed_window"] = {
        "label": "首访后24小时至第30日",
        "eligible_users": int(as_number(fixed_conversion["denominator"])),
        "converted_users": int(as_number(fixed_conversion["numerator"])),
        "conversion_rate": as_number(fixed_conversion["metric_value"]),
        "identifiable_order_users": int(audit_values["identifiable_order_users"]),
        "recognized_revenue_users": int(audit_values["recognized_revenue_users"]),
        "positive_recognized_value_users": int(as_number(fixed_positive["numerator"])),
        "positive_recognized_value_rate": as_number(fixed_positive["metric_value"]),
        "recognized_revenue_usd": as_number(fixed_value["numerator"]),
        "value_per_eligible_user_usd": as_number(fixed_value["metric_value"]),
    }

    identifiable = metrics["Identifiable order user rate"]
    positive = metrics["Positive recognized value user rate"]
    aov = metrics["Recognized AOV"]
    value_per_user = metrics["Recognized value per new user"]
    dashboard["value"] = {
        "identifiable_order_users": int(as_number(identifiable["numerator"])),
        "identifiable_order_user_rate": as_number(identifiable["metric_value"]),
        "positive_recognized_value_users": int(as_number(positive["numerator"])),
        "positive_recognized_value_user_rate": as_number(positive["metric_value"]),
        "identifiable_orders": int(qa["observed_canonical_orders"]),
        "revenue_recognized_orders": int(as_number(aov["denominator"])),
        "recognized_revenue_usd": as_number(aov["numerator"]),
        "value_per_new_user_usd": as_number(value_per_user["metric_value"]),
        "recognized_aov_usd": as_number(aov["metric_value"]),
    }

    funnel_metric_names = [
        ("核心价值", "Core to high-intent ordered rate", "denominator"),
        ("高意向", "Core to high-intent ordered rate", "numerator"),
        ("开始结账", "High-intent to checkout ordered rate", "numerator"),
        ("完成转化", "Checkout to conversion ordered rate", "numerator"),
    ]
    dashboard["funnel"] = [
        {"stage": label, "sessions": int(as_number(metrics[name][field]))}
        for label, name, field in funnel_metric_names
    ]
    dashboard["audit_populations"] = {
        "all_sample": {
            "canonical_orders": int(audit_values["canonical_orders_total"]),
            "revenue_recognized_orders": int(audit_values["canonical_orders_revenue_recognized"]),
            "revenue_null_orders": int(audit_values["canonical_orders_revenue_null"]),
            "zero_revenue_orders": int(audit_values["canonical_orders_zero_revenue"]),
            "revenue_conflict_orders": int(audit_values["canonical_orders_revenue_conflict"]),
            "recognized_revenue_usd": audit_values["recognized_revenue_usd"],
            "purchase_item_rows": int(audit_values["purchase_item_rows"]),
            "purchase_item_rows_quantity_nonnull": int(audit_values["purchase_item_rows_quantity_nonnull"]),
            "purchase_quantity_completeness": audit_values["purchase_item_rows_quantity_nonnull"] / audit_values["purchase_item_rows"],
            "core_high_intent_timestamp_ties": int(audit_values["core_high_intent_ties"]),
        },
        "new_user_observed_to_end": dashboard["value"],
        "user_order_integrity": {
            "first_visit_users": int(qa["all_first_visit_users"]),
            "first_session_users": int(qa["users_in_first_session_model"]),
            "first_session_coverage_rate": qa["first_session_coverage_rate"],
            "qa1_status": qa["qa1_status"],
            "sentinel_source_purchase_rows": int(qa["sentinel_source_purchase_rows"]),
            "sentinel_user_dates": int(qa["sentinel_user_dates"]),
            "sentinel_cross_day_pairs": int(qa["sentinel_cross_day_pairs"]),
            "valid_order_cross_day_pairs": int(qa["valid_order_cross_day_pairs"]),
            "qa2_status": qa["qa2_status"],
        },
    }

    args.output.write_text(json.dumps(dashboard, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Refreshed dashboard data at {args.output}")


if __name__ == "__main__":
    main()

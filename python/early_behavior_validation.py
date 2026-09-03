"""Validate associations between early behaviors and future user quality."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
import pandas as pd


def wilson_interval(positive: float, total: float, z: float = 1.959963984540054) -> tuple[float, float]:
    if total <= 0:
        return math.nan, math.nan
    rate = positive / total
    denominator = 1 + z * z / total
    center = (rate + z * z / (2 * total)) / denominator
    margin = z * math.sqrt(rate * (1 - rate) / total + z * z / (4 * total * total)) / denominator
    return max(0.0, center - margin), min(1.0, center + margin)


def two_proportion_p_value(x1: float, n1: float, x0: float, n0: float) -> float:
    if n1 <= 0 or n0 <= 0:
        return math.nan
    pooled = (x1 + x0) / (n1 + n0)
    standard_error = math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n0))
    if standard_error == 0:
        return 1.0
    z_score = (x1 / n1 - x0 / n0) / standard_error
    return max(math.erfc(abs(z_score) / math.sqrt(2)), sys.float_info.min)


def benjamini_hochberg(p_values: pd.Series) -> pd.Series:
    result = pd.Series(np.nan, index=p_values.index, dtype=float)
    valid = p_values.dropna().sort_values()
    if valid.empty:
        return result
    count = len(valid)
    adjusted = valid.to_numpy() * count / np.arange(1, count + 1)
    adjusted = np.minimum.accumulate(adjusted[::-1])[::-1]
    result.loc[valid.index] = np.minimum(adjusted, 1.0)
    return result


def parse_bool(value: object) -> bool:
    return str(value).strip().lower() in {"true", "1", "t", "yes"}


def build_effect_table(counts: pd.DataFrame) -> pd.DataFrame:
    required = {"feature_name", "feature_value", "outcome_name", "eligible_users", "positive_users"}
    missing = required.difference(counts.columns)
    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")

    frame = counts.copy()
    frame["feature_value"] = frame["feature_value"].map(parse_bool)
    frame["eligible_users"] = pd.to_numeric(frame["eligible_users"], errors="raise")
    frame["positive_users"] = pd.to_numeric(frame["positive_users"], errors="raise")

    records: list[dict[str, float | str]] = []
    for (feature, outcome), group in frame.groupby(["feature_name", "outcome_name"], sort=True):
        groups = group.set_index("feature_value")
        if True not in groups.index or False not in groups.index:
            raise ValueError(f"Both feature groups are required for {feature} / {outcome}")

        exposed = groups.loc[True]
        unexposed = groups.loc[False]
        n1, x1 = float(exposed["eligible_users"]), float(exposed["positive_users"])
        n0, x0 = float(unexposed["eligible_users"]), float(unexposed["positive_users"])
        r1 = x1 / n1 if n1 else math.nan
        r0 = x0 / n0 if n0 else math.nan
        ci1 = wilson_interval(x1, n1)
        ci0 = wilson_interval(x0, n0)

        risk_ratio = r1 / r0 if r0 > 0 else math.inf
        a, b, c, d = x1, n1 - x1, x0, n0 - x0
        if min(a, b, c, d) == 0:
            a, b, c, d = a + 0.5, b + 0.5, c + 0.5, d + 0.5
        odds_ratio = (a * d) / (b * c)

        records.append({
            "feature_name": feature,
            "outcome_name": outcome,
            "exposed_users": n1,
            "exposed_positive": x1,
            "exposed_rate": r1,
            "exposed_ci_low": ci1[0],
            "exposed_ci_high": ci1[1],
            "unexposed_users": n0,
            "unexposed_positive": x0,
            "unexposed_rate": r0,
            "unexposed_ci_low": ci0[0],
            "unexposed_ci_high": ci0[1],
            "risk_difference_pp": (r1 - r0) * 100,
            "risk_ratio": risk_ratio,
            "odds_ratio": odds_ratio,
            "p_value": two_proportion_p_value(x1, n1, x0, n0),
        })

    effects = pd.DataFrame.from_records(records)
    effects["q_value_bh"] = benjamini_hochberg(effects["p_value"])
    return effects.sort_values(["outcome_name", "feature_name"]).reset_index(drop=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    counts = pd.read_csv(args.input)
    effects = build_effect_table(counts)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    effects.to_csv(args.output, index=False, float_format="%.10g")
    print(f"Wrote {len(effects)} validated comparisons to {args.output}")


if __name__ == "__main__":
    main()

"""Build the standalone dashboard from validated local result files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--kpis", type=Path, required=True)
    parser.add_argument("--effects", type=Path, required=True)
    parser.add_argument("--analysis-results", type=Path, required=True)
    parser.add_argument("--uncertainty", type=Path, required=True)
    parser.add_argument("--standardized", type=Path, required=True)
    parser.add_argument("--funnel-standardization", type=Path, required=True)
    parser.add_argument("--tests", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    template = args.template.read_text(encoding="utf-8")
    kpis = json.loads(args.kpis.read_text(encoding="utf-8"))
    effects = pd.read_csv(args.effects).replace({float("inf"): None, float("-inf"): None})
    effect_records = effects.where(pd.notna(effects), None).to_dict(orient="records")
    analysis_results = json.loads(args.analysis_results.read_text(encoding="utf-8"))
    uncertainty = json.loads(args.uncertainty.read_text(encoding="utf-8"))
    standardized = json.loads(args.standardized.read_text(encoding="utf-8"))
    funnel_standardization = json.loads(args.funnel_standardization.read_text(encoding="utf-8"))
    tests = json.loads(args.tests.read_text(encoding="utf-8"))

    document = template.replace("__KPI_DATA__", json.dumps(kpis, ensure_ascii=False, separators=(",", ":")))
    document = document.replace("__EFFECT_DATA__", json.dumps(effect_records, ensure_ascii=False, separators=(",", ":")))
    document = document.replace("__ANALYSIS_DATA__", json.dumps(analysis_results, ensure_ascii=False, separators=(",", ":")))
    document = document.replace("__UNCERTAINTY_DATA__", json.dumps(uncertainty, ensure_ascii=False, separators=(",", ":")))
    document = document.replace("__STANDARDIZED_DATA__", json.dumps(standardized, ensure_ascii=False, separators=(",", ":")))
    document = document.replace("__FUNNEL_STANDARDIZATION_DATA__", json.dumps(funnel_standardization, ensure_ascii=False, separators=(",", ":")))
    document = document.replace("__TEST_DATA__", json.dumps(tests, ensure_ascii=False, separators=(",", ":")))
    placeholders = ("__KPI_DATA__", "__EFFECT_DATA__", "__ANALYSIS_DATA__", "__UNCERTAINTY_DATA__", "__STANDARDIZED_DATA__", "__FUNNEL_STANDARDIZATION_DATA__", "__TEST_DATA__")
    if any(token in document for token in placeholders):
        raise RuntimeError("Dashboard template placeholders were not fully replaced")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(document, encoding="utf-8")
    print(f"Built dashboard at {args.output}")


if __name__ == "__main__":
    main()

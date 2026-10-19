#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P6.1 - fail if any frozen P0/P0.1 baseline number goes up.

Reads `tmp/unhandled_baseline.json` (produced by
`scripts/tier_unhandled_manifest.py`) and compares it with the frozen values
below (mirrored in `docs/data-world-unhandled-baseline.zh-CN.md`).

Exit code is non-zero when a value exceeds its baseline, so this can be wired
into pre-commit / CI.

Usage:
    python scripts/assert_unhandled_baseline.py
"""
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
BASELINE_JSON = os.path.join(ROOT, "tmp", "unhandled_baseline.json")

# Frozen 2026-10-19 (P0 + P0.1).  Only lower these numbers, never raise them.
# Tier 0 / Tier 1 are informational: a better classifier may legitimately move
# records between tiers.  Only the Tier-2 backlog is asserted (it must shrink).
FROZEN = {
    "records_total": 11095,
    "function_records": 2136,
    "cond_branch_records": 8525,
    "function_name_distinct": 643,
    "branch_owner_functions": 442,
    "not_found_bodies": 32,
    "suppression_entries": 188,
    "tier_2_backlog": 9866,
}
INFO = {"tier_0": 188, "tier_1": 1041}


def main():
    if not os.path.isfile(BASELINE_JSON):
        print("missing %s - run scripts/tier_unhandled_manifest.py first" % BASELINE_JSON)
        return 2

    with open(BASELINE_JSON, encoding="utf-8") as fh:
        data = json.load(fh)
    c = data["counts"]
    d = data["distinct"]

    current = {
        "records_total": c["records_total"],
        "function_records": c["by_kind"].get("function", 0),
        "cond_branch_records": c["by_kind"].get("cond_branch", 0),
        "function_name_distinct": d["function_names"],
        "branch_owner_functions": c.get("branch_owner_functions", 0),
        "not_found_bodies": c["function_body_status"].get("not-found", 0),
        "suppression_entries": c["suppression_entries"],
        "tier_2_backlog": c["by_tier"].get("2", 0),
    }

    failures = []
    print("%-24s %8s %8s  %s" % ("metric", "frozen", "current", "status"))
    for key, frozen in FROZEN.items():
        cur = current[key]
        ok = cur <= frozen
        if not ok:
            failures.append(key)
        print("%-24s %8d %8d  %s" % (key, frozen, cur, "ok" if ok else "REGRESSION"))

    print("-" * 46)
    for key, frozen in INFO.items():
        cur = c["by_tier"].get(str(int(key[-1])), 0)
        print("%-24s %8d %8d  (info)" % (key, frozen, cur))

    if failures:
        print("\nbaseline regression: %s" % ", ".join(failures))
        return 1
    print("\nall baselines held")
    return 0


if __name__ == "__main__":
    sys.exit(main())

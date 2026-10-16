#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Inventory of data/world/*.comments.txt — what the LPC converter left unconverted.

Classifies every '#' line in the .comments.txt sidecar files into buckets so we can
see how much is pure provenance noise vs. real "not converted yet" payload.
"""
import os
import re
import sys
import json
from collections import Counter, defaultdict

WORLD = sys.argv[1] if len(sys.argv) > 1 else "data/world"

BUCKETS = [
    ("block_header",      re.compile(r"^# Generated from .* by LPCConverter\s*$")),
    ("zone_header",       re.compile(r"^# Zone: \S+\s*$")),
    ("inherit",           re.compile(r"^# inherit .*;\s*$")),
    ("sep",               re.compile(r"^# =+\s*$")),
    ("sec_header",        re.compile(r"^# UNHANDLED CONTENT \(for manual review\)\s*$")),
    ("sec_unhandled_fn",  re.compile(r"^# ==== UNHANDLED FUNCTIONS ====\s*$")),
    ("sec_unhandled_gl",  re.compile(r"^# ==== UNHANDLED GLOBAL VARIABLES ====\s*$")),
    ("sec_cond_br",       re.compile(r"^# ==== CONDITIONAL BRANCHES.*====\s*$")),
    ("sec_complex",       re.compile(r"^# ==== COMPLEX CONDITIONALS ====\s*$")),
    ("sec_switch_tbl",    re.compile(r"^# ==== SWITCH TABLES ====\s*$")),
    ("sec_switch_pool",   re.compile(r"^# ==== SWITCH POOLS ====\s*$")),
    ("sec_switch_stmt",   re.compile(r"^# ==== SWITCH STATEMENTS ====\s*$")),
    ("sec_raw",           re.compile(r"^# ==== RAW CODE BLOCKS ====\s*$")),
    ("sec_complex_map",   re.compile(r"^# ==== COMPLEX MAPPINGS ====\s*$")),
    ("it_unhandled_fn",   re.compile(r"^  # UNHANDLED FUNCTION: \S+")),
    ("it_unhandled_gl",   re.compile(r"^  # UNHANDLED GLOBAL: ")),
    ("it_cond_branch",    re.compile(r"^  # (else if \(.*\)|if \(.*\)|else)\s+→")),
    ("it_complex_if",     re.compile(r"^  # COMPLEX IF: ")),
    ("it_switch_table",   re.compile(r"^  # SWITCH TABLE \(expr: ")),
    ("it_switch_row",     re.compile(r"^  #   .*: .*=")),
    ("it_switch_pool",    re.compile(r"^  # SWITCH POOL: ")),
    ("it_switch_stmt",    re.compile(r"^  # SWITCH: ")),
    ("it_raw_block",      re.compile(r"^  # RAW BLOCK: ")),
    ("it_complex_map",    re.compile(r"^  # COMPLEX MAPPING: ")),
    ("it_skipped",        re.compile(r"^  # skipped ")),
    ("it_veto_cond",      re.compile(r"^    # 阻挡条件（原样保留）：")),
    ("it_vendor_goods",   re.compile(r"^  # (vendor_)?goods: \".*\" \(file not found\)")),
    ("it_inquiry",        re.compile(r"^  # skipped inquiry ")),
    ("it_river",          re.compile(r"^  # River actions: |^  # - ")),
    ("generic_marker",    re.compile(r"^# (Generic LPC file: |Requires manual conversion)")),
    ("it_other_hash",     re.compile(r"^  # ")),
    ("other_hash",        re.compile(r"^#")),
]

def classify(line):
    for name, rx in BUCKETS:
        if rx.match(line):
            return name
    return None

def main():
    files = sorted(f for f in os.listdir(WORLD) if f.endswith(".comments.txt"))
    total = Counter()
    per_zone = {}
    zones_with_payload = 0
    total_payload = 0
    empty_files = 0
    func_names = Counter()
    cond_conds = Counter()
    skipped_reasons = Counter()
    vendor_targets = Counter()

    for f in files:
        path = os.path.join(WORLD, f)
        zone = f[: -len(".comments.txt")]
        counts = Counter()
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if not line.strip():
                    continue
                b = classify(line)
                if b:
                    counts[b] += 1
                    total[b] += 1
                else:
                    counts["UNCLASSIFIED"] += 1
                    total["UNCLASSIFIED"] += 1
                    if total["UNCLASSIFIED"] <= 20:
                        print("UNCLASSIFIED:", f, repr(line[:160]))

                m = re.match(r"^  # UNHANDLED FUNCTION: (\S+)", line)
                if m:
                    func_names[m.group(1)] += 1
                m = re.match(r"^  # skipped (\S+)?", line)
                if m:
                    skipped_reasons[m.group(1) or "<none>"] += 1
                m = re.match(r'^  # (?:vendor_)?goods: "([^"]+)"', line)
                if m:
                    vendor_targets[m.group(1)] += 1

        per_zone[zone] = dict(counts)
        payload = sum(v for k, v in counts.items()
                      if k in ("it_unhandled_fn", "it_unhandled_gl", "it_cond_branch",
                               "it_complex_if", "it_switch_table", "it_switch_row",
                               "it_switch_pool", "it_switch_stmt", "it_raw_block",
                               "it_complex_map", "it_skipped", "it_vendor_goods",
                               "it_inquiry", "generic_marker"))
        total_payload += payload
        if payload:
            zones_with_payload += 1
        if sum(counts.values()) == 0:
            empty_files += 1

    provenance = total["block_header"] + total["zone_header"] + total["sep"] + \
        total["sec_header"] + total["inherit"] + total["it_veto_cond"] + total["it_river"] + \
        total["sec_unhandled_fn"] + total["sec_unhandled_gl"] + total["sec_cond_br"] + \
        total["sec_complex"] + total["sec_switch_tbl"] + total["sec_switch_pool"] + \
        total["sec_switch_stmt"] + total["sec_raw"] + total["sec_complex_map"] + \
        total["it_other_hash"] + total["other_hash"]

    print("=" * 78)
    print(f"files scanned: {len(files)}   (empty files: {empty_files})")
    print(f"total '#'-ish lines: {sum(total.values())}")
    print(f"payload (real unconverted) lines: {total_payload}")
    print(f"zones with payload: {zones_with_payload}/{len(files)}")
    print("=" * 78)
    for k, v in total.most_common():
        print(f"  {k:20s} {v:7d}")
    print("=" * 78)
    print("UNHANDLED FUNCTION names (top 40):")
    for n, c in func_names.most_common(40):
        print(f"  {n:32s} {c}")
    print(f"  ... distinct function names: {len(func_names)}")
    print("=" * 78)
    print("skipped reasons (top 20):")
    for n, c in skipped_reasons.most_common(20):
        print(f"  {n:40s} {c}")
    print("=" * 78)
    print("vendor_goods targets (top 25):")
    for n, c in vendor_targets.most_common(25):
        print(f"  {n:48s} {c}")
    print(f"  ... distinct targets: {len(vendor_targets)}")

    out_json = os.path.join("tmp", "comments_inventory.json")
    os.makedirs("tmp", exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump({"total": dict(total), "per_zone": per_zone,
                   "functions": dict(func_names), "skipped": dict(skipped_reasons),
                   "vendor_targets": dict(vendor_targets)},
                  fh, ensure_ascii=False, indent=1)
    print("\nwrote", out_json)

if __name__ == "__main__":
    main()

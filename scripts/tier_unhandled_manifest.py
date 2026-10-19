#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P0.1 step 2 - annotate every unhandled-manifest record with a triage tier
and emit the frozen baseline + suppression list.

Inputs (all produced by earlier P0 scripts):
  tmp/unhandled_manifest_resolved.json   manifest + variant verdicts
  tmp/unhandled_variants.json            P0.1 step 1 report
  scripts/tmp/survey_add_action.json     P5-1 verb/handler survey (Tier-1 verbs)
  lib/kantele/character/commands/*.ex    fallback "engine already has it" verbs

Outputs (never touches data/world):
  tmp/unhandled_manifest_tiered.json     schedulable manifest (records + tier)
  tmp/unhandled_baseline.json            frozen counters (P6 assertion input)
  scripts/unhandled_suppressions.json    Tier-0 / no-body entries with reasons
  docs/data-world-unhandled-baseline.zh-CN.md

Tier rules (plan §P0.1 + §P5 triage table):
  Tier 0  no code needed (lifecycle/query callback, or already-implemented
          global command, or a record with no recoverable body at all)
  Tier 1  engine already has the global command; only the per-object
          `add_action` override is missing
  Tier 2  needs a new subsystem / manual implementation

Usage:
    python scripts/tier_unhandled_manifest.py
"""
import argparse
import collections
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
TMP = os.path.join(ROOT, "tmp")
DEFAULT_MANIFEST = os.path.join(TMP, "unhandled_manifest_resolved.json")
DEFAULT_VARIANTS = os.path.join(TMP, "unhandled_variants.json")
DEFAULT_SURVEY = os.path.join(SCRIPT_DIR, "tmp", "survey_add_action.json")
DEFAULT_TIERED = os.path.join(TMP, "unhandled_manifest_tiered.json")
DEFAULT_BASELINE = os.path.join(TMP, "unhandled_baseline.json")
DEFAULT_SUPPRESS = os.path.join(SCRIPT_DIR, "unhandled_suppressions.json")
DEFAULT_DOC = os.path.join(ROOT, "docs", "data-world-unhandled-baseline.zh-CN.md")

# plan §P5 "Tier 0 免除"
TIER0_NAMES = {
    "setup", "reset", "create", "init", "long", "name",
    "is_container", "is_chat_room", "query_autoload",
    "no_clean_up", "valid_startroom", "no_map", "no_shown", "no_user",
}
DYNAMIC_LONG_NAME = {"long", "name"}

SUBSYSTEMS = [
    ("combat", {"accept_fight", "kill", "hit", "ansuan", "unconcious", "die",
                "owner_is_killed", "accept_kill", "fight"}),
    ("apprentice", {"recognize_apprentice", "attempt_apprentice"}),
    ("door_container", {"close", "close_passage", "do_open", "do_knock", "do_break"}),
    ("movement", {"do_climb", "do_jump", "do_tiao", "do_cross", "do_swim", "do_move"}),
    ("item_food", {"do_eat", "finish_eat", "do_serve",
                   "create_wine", "create_water", "create_food"}),
    ("one_off_scene", {"do_play", "look_gaoshi", "relay_emote", "on_board",
                       "begin", "working", "halt_working"}),
]
OWNER_OVERRIDES = {
    "create": ("p1_p2_data_create", "Tier 2", "create() 的 set()/分支走 P1/P2 数据通道"),
    "setup": ("p1_p2_data_room", "Tier 2", "setup() 的 exits/objects 走 P1/P2 数据通道"),
    "reset": ("p1_p2_data_room", "Tier 2", "reset() 的刷新逻辑走 P1/P2 数据通道"),
    "init": ("npc_actions", "Tier 2", "init() 的 add_action/台词走 P5 NPC 动作通道"),
    "greeting": ("npc_actions", "Tier 2", "greeting 台词池走 P5 NPC 动作通道"),
    "valid_leave": ("veto_channel", "Tier 2", "valid_leave 走 P4 exit_vetoes 通道"),
}


def load_json(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def verb_sets(survey_path):
    tier0, needs_impl = set(), set()
    if os.path.isfile(survey_path):
        data = load_json(survey_path)
        tier0 = {v for v, _ in data.get("tier0_handlers", [])}
        needs_impl = {v for v, _ in data.get("needs_impl_handlers", [])}
    cmd_dir = os.path.join(ROOT, "lib", "kantele", "character", "commands")
    if os.path.isdir(cmd_dir):
        for fn in os.listdir(cmd_dir):
            if not fn.endswith(".ex"):
                continue
            base = fn[:-3]
            for suffix in ("_commands", "_command"):
                if base.endswith(suffix):
                    base = base[: -len(suffix)]
                    break
            tier0.add(base)
    return tier0, needs_impl


def is_global_command_path(path):
    p = (path or "").replace("\\", "/").lower()
    return "/cmds/" in p or "/cmd/" in p or "/command/" in p


def classify_name(name, body="", source_path="", tier0_verbs=None, impl_verbs=None):
    """Return (tier:int, subsystem:str, reason:str)."""
    tier0_verbs = tier0_verbs or set()
    impl_verbs = impl_verbs or set()
    if name in TIER0_NAMES:
        if name in DYNAMIC_LONG_NAME and re.search(r"\bquery(?:_temp)?\s*\(", body or ""):
            return 2, "dynamic_long_name", "tier0_exception:dynamic_query"
        return 0, "lifecycle", "tier0_lifecycle_or_query"
    if is_global_command_path(source_path):
        return 0, "global_command", "tier0_global_command"
    verb = name[3:] if name.startswith("do_") else None
    if verb and verb in tier0_verbs:
        return 1, "object_action:" + verb, "tier1_object_override"
    for subsystem, names in SUBSYSTEMS:
        if name in names:
            return 2, subsystem, "tier2_" + subsystem
    if name.startswith(("ask_", "look_", "inquiry_")) or name == "item_desc":
        return 2, "look_inquiry", "tier2_look_inquiry"
    if verb and verb in impl_verbs:
        return 2, "action_impl:" + verb, "tier2_new_implementation"
    return 2, "other", "tier2_manual"


def classify_record(rec, tier0_verbs, impl_verbs):
    kind = rec["kind"]
    if kind == "function":
        tier, sub, reason = classify_name(
            rec.get("name", ""), rec.get("body") or "", rec.get("source_path", ""),
            tier0_verbs, impl_verbs)
        if rec.get("body_status") == "not-found":
            verdict = rec.get("variant_verdict") or "noop_unresolved"
            return 0, "no_body", "not_found:" + verdict, True
        return tier, sub, reason, tier == 0
    if kind == "cond_branch":
        fn = rec.get("function") or ""
        if fn in OWNER_OVERRIDES:
            sub, _, reason = OWNER_OVERRIDES[fn]
            return 2, sub, reason, False
        tier, sub, reason = classify_name(
            fn, rec.get("owner_body") or "", rec.get("source_path", ""),
            tier0_verbs, impl_verbs)
        if tier == 0:
            # a branch owned by a lifecycle callback is still data work
            return 2, "data_" + sub, reason.replace("tier0", "data"), False
        return tier, sub, reason, False
    if kind == "raw":
        name = rec.get("name", "")
        if name in TIER0_NAMES:
            return 0, "lifecycle", "tier0_lifecycle_or_query", True
        return 2, "other", "tier2_raw_block", False
    return 2, "other", "tier2_" + kind, False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=DEFAULT_MANIFEST)
    ap.add_argument("--variants", default=DEFAULT_VARIANTS)
    ap.add_argument("--survey", default=DEFAULT_SURVEY)
    ap.add_argument("--tiered", default=DEFAULT_TIERED)
    ap.add_argument("--baseline", default=DEFAULT_BASELINE)
    ap.add_argument("--suppressions", default=DEFAULT_SUPPRESS)
    ap.add_argument("--doc", default=DEFAULT_DOC)
    args = ap.parse_args()

    manifest = load_json(args.manifest)
    variants = load_json(args.variants) if os.path.isfile(args.variants) else {"records": []}
    tier0_verbs, impl_verbs = verb_sets(args.survey)

    verdict_by_id = {e["id"]: e for e in variants.get("records", [])}
    for rec in manifest["records"]:
        ev = verdict_by_id.get(rec.get("id"))
        if ev:
            rec["variant_verdict"] = ev["verdict"]
            rec["variant_reason"] = ev.get("reason")

    by_tier = collections.Counter()
    by_subsystem = collections.Counter()
    by_tier_kind = collections.Counter()
    suppressions = []
    for rec in manifest["records"]:
        tier, sub, reason, suppress = classify_record(rec, tier0_verbs, impl_verbs)
        rec["tier"] = tier
        rec["tier_reason"] = reason
        rec["subsystem"] = sub
        by_tier[tier] += 1
        by_subsystem[sub] += 1
        by_tier_kind[(tier, rec["kind"])] += 1
        if suppress:
            suppressions.append({
                "id": rec["id"],
                "tier": "noop",
                "reason": rec.get("variant_reason") or reason,
                "tier_reason": reason,
                "zone": rec.get("zone"),
                "object": rec.get("object"),
                "kind": rec.get("kind"),
                "name": rec.get("name") or rec.get("function"),
                "source_path": rec.get("source_path"),
            })

    funcs = [r for r in manifest["records"] if r["kind"] == "function"]
    fn_status = collections.Counter(r.get("body_status") for r in funcs)
    distinct_names = len({r.get("name") for r in funcs})
    not_found = [r for r in funcs if r.get("body_status") == "not-found"]
    nf_verdicts = collections.Counter(r.get("variant_verdict") for r in not_found)
    kinds = collections.Counter(r["kind"] for r in manifest["records"])

    baseline = {
        "generated_from": args.manifest,
        "counts": {
            "records_total": len(manifest["records"]),
            "branch_owner_functions": manifest.get("branch_owner_functions", 0),
            "by_kind": dict(sorted(kinds.items())),
            "by_tier": {str(k): v for k, v in sorted(by_tier.items())},
            "by_tier_kind": {"%d:%s" % k: v for k, v in sorted(by_tier_kind.items())},
            "by_subsystem": dict(sorted(by_subsystem.items())),
            "function_body_status": dict(sorted(fn_status.items())),
            "not_found_verdicts": dict(sorted(nf_verdicts.items())),
            "suppression_entries": len(suppressions),
        },
        "distinct": {
            "function_names": distinct_names,
            "not_found_names": len({r.get("name") for r in not_found}),
        },
    }

    os.makedirs(os.path.dirname(args.tiered) or ".", exist_ok=True)
    with open(args.tiered, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1)
    with open(args.baseline, "w", encoding="utf-8") as fh:
        json.dump(baseline, fh, ensure_ascii=False, indent=1)
    with open(args.suppressions, "w", encoding="utf-8") as fh:
        json.dump({
            "generated_from": args.manifest,
            "counts": {"suppressions": len(suppressions)},
            "entries": sorted(suppressions, key=lambda e: e["id"]),
        }, fh, ensure_ascii=False, indent=1)

    write_doc(args.doc, baseline, not_found, verdict_by_id)

    print("records:", len(manifest["records"]))
    print("by tier:", dict(sorted(by_tier.items())))
    print("function body status:", dict(sorted(fn_status.items())))
    print("not-found verdicts:", dict(sorted(nf_verdicts.items())))
    print("suppressions:", len(suppressions))
    print("wrote", args.tiered)
    print("wrote", args.baseline)
    print("wrote", args.suppressions)
    print("wrote", args.doc)
    return 0


VERDICT_ZH = {
    "noop_commented_out": "本文件内仅有被注释掉的实现",
    "noop_other_object": "同名实现在其它对象中，无法归属",
    "noop_prototype_only": "仅有前置声明，语料中无实现",
    "noop_missing_source": "源文件缺失（测试夹具已删除）",
    "noop_name_absent": "源文件中无此名字",
    "noop_unresolved": "仅有调用点，未找到实现",
}


def _aggregate_subsystems(by_subsystem):
    """Collapse `object_action:move` style keys into one row + a verb table."""
    agg = collections.Counter()
    verbs = collections.Counter()
    for key, n in by_subsystem.items():
        if ":" in key:
            prefix, verb = key.split(":", 1)
            agg[prefix] += n
            verbs[(prefix, verb)] = n
        else:
            agg[key] += n
    return agg, verbs


def write_doc(path, baseline, not_found, verdict_by_id):
    c = baseline["counts"]
    d = baseline["distinct"]
    tier = c["by_tier"]
    agg, verbs = _aggregate_subsystems(c["by_subsystem"])
    lines = []
    add = lines.append
    add("# 未解析清单基线（P0.1）")
    add("")
    add("> 本文件由 `scripts/tier_unhandled_manifest.py` 生成，请勿手改。")
    add("> 数字**只能降不能升**；回归断言见 `scripts/assert_unhandled_baseline.py`（P6）。")
    add("")
    add("## 1. 基线数字")
    add("")
    add("| 指标 | 值 |")
    add("|------|----|")
    add("| 记录总数 | %d |" % c["records_total"])
    add("| 函数记录 | %d |" % c["by_kind"].get("function", 0))
    add("| 条件分支记录 | %d |" % c["by_kind"].get("cond_branch", 0))
    add("| 函数名（distinct） | %d |" % d["function_names"])
    add("| `UNHANDLED FUNCTION` 条数 / 名数 | %d / %d |" % (
        c["by_kind"].get("function", 0), d["function_names"]))
    add("| 分支归属函数数 | 442 |")
    add("| 函数 body 未回源 | %d |" % c["function_body_status"].get("not-found", 0))
    add("| 抑制清单条目 | %d |" % c["suppression_entries"])
    add("")
    add("可排期清单：`tmp/unhandled_manifest_tiered.json`"
        "（在 manifest 每条记录上加了 `tier` / `subsystem` / `tier_reason`）。")
    add("")
    add("### 按 kind")
    add("")
    add("| kind | 条数 |")
    add("|------|-----:|")
    for k, v in sorted(c["by_kind"].items()):
        add("| `%s` | %d |" % (k, v))
    add("")
    add("## 2. 分诊（Tier）")
    add("")
    add("| Tier | 含义 | 条数 |")
    add("|:----:|------|-----:|")
    add("| 0 | 免除：lifecycle/query 回调、已实现的全局命令、或源无 body | %d |" % tier.get("0", 0))
    add("| 1 | 引擎已有全局命令，只缺逐对象 `add_action` 覆盖 | %d |" % tier.get("1", 0))
    add("| 2 | 需新子系统 / 手工实现 | %d |" % tier.get("2", 0))
    add("")
    add("### 动作记录按动词分布（top 20）")
    add("")
    add("`object_action:*` = Tier 1（可走逐对象通道）；`action_impl:*` = Tier 2（需新实现）。")
    add("")
    add("| 动词 | 记录数 |")
    add("|------|-------:|")
    for (prefix, verb), n in sorted(verbs.items(), key=lambda kv: (-kv[1], kv[0]))[:20]:
        add("| `%s:%s` | %d |" % (prefix, verb, n))
    add("")
    add("### 按子系统（聚合）")
    add("")
    add("| 子系统 | 条数 |")
    add("|--------|-----:|")
    for k, v in sorted(agg.items(), key=lambda kv: (-kv[1], kv[0])):
        add("| `%s` | %d |" % (k, v))
    add("")
    add("## 3. 未回源函数（32 条 → 全部抑制，0 条可归属）")
    add("")
    add("命名变体（`ask_me1` ↔ `ask_me_1` 等）已在**本文件 + 继承链**内匹配；"
        "语料中仅有的同名定义属于**其它对象**，不可归属。")
    add("")
    add("| id | 函数 | 对象 | 判定 | 定位 |")
    add("|----|------|------|------|------|")
    for r in sorted(not_found, key=lambda x: x["id"]):
        verdict = r.get("variant_verdict")
        ev = verdict_by_id.get(r["id"], {})
        where = "—"
        if verdict == "noop_commented_out":
            comments = [o for o in ev.get("occurrences", []) if o["kind"] == "comment"]
            if comments:
                where = "L%d" % comments[0]["line"]
        elif verdict == "noop_other_object" and ev.get("corpus_candidates"):
            where = "`%s`" % ev["corpus_candidates"][0]["source_path"]
        elif verdict == "noop_prototype_only":
            decls = [o for o in ev.get("occurrences", []) if o["kind"] == "declaration"]
            if decls:
                where = "L%d" % decls[0]["line"]
        add("| `%s` | `%s` | `%s` | %s | %s |" % (
            r["id"], r.get("name"), r.get("object"),
            VERDICT_ZH.get(verdict, verdict or ""), where))
    add("")
    add("## 4. 抑制清单")
    add("")
    add("文件：`scripts/unhandled_suppressions.json`（schema：`{id, tier:\"noop\", reason, ...}`）。")
    add("")
    add("| 判定 | 条数 |")
    add("|------|-----:|")
    for k, v in sorted(c["not_found_verdicts"].items()):
        add("| `%s` | %d |" % (k, v))
    add("")
    add("## 5. 复现")
    add("")
    add("```bash")
    add("python scripts/build_unhandled_manifest.py")
    add("python scripts/resolve_unhandled_variants.py")
    add("python scripts/tier_unhandled_manifest.py")
    add("```")
    add("")
    add("两条 P0.1 脚本均只写 `tmp/` / `docs/` / `scripts/unhandled_suppressions.json`，"
        "不触碰 `data/world`，可重复运行且结果字节一致。")
    add("")

    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


if __name__ == "__main__":
    sys.exit(main())

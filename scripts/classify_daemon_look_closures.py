# -*- coding: utf-8 -*-
"""
classify_daemon_look_closures.py — P5-4 续做：把 40 个 daemon/state item_desc 闭包
按「能否用现有 6 个 handler 表达」重新分类，界定下一批可落地的数据回填 vs 需要新子系统的项。

复用 backfill_static_look_text.scan_corpus()（只读 LPC 语料，零写入）。
输出：按桶分组的 (fn, rooms, keyword, 命中证据) 报告，落 tmp/daemon_look_classify.json。

分类桶：
  score_tiers        — body 含 query("score") 分档
  room_state_tiers   — body 含 query("status"/"book_count"/"marks/...") 等房间属性
  room_temp          — body 含 this_object()->query_temp(...) 房间 temp
  player_temp_branch — body 含 this_player()->query_temp(...) 玩家 temp
  room_occupancy     — body 含 present/find_player/find_npc/环境对象存在性
  gated_text         — body 仅查 this_player() 某开关/temp 二态
  daemon_new         — body 含 FINGER_D/CHANNEL_D/*_D-> 全局守护进程（需新子系统）
  game_state_new     — body 含拱猪/排行榜/小游戏态（需新子系统）
  unknown            — 未识别，需人工看
"""
import io
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import backfill_static_look_text as B   # noqa: E402

ROOT = B.ROOT
OUT = os.path.join(ROOT, "tmp", "daemon_look_classify.json")

# 复用扫描
closures, funcs = B.scan_corpus()


def classify(fn, body):
    if body is None:
        return "nodef", []
    ev = []
    # 守护进程
    if re.search(r'FINGER_D|CHANNEL_D|_[A-Z]+D\s*->', body):
        ev.append("daemon-call")
        return "daemon_new", ev
    # 排行榜 / 拱猪 / 小游戏态
    if re.search(r'scoreboard|rank|拱猪|zhug|pig|game_state|board_state', body):
        ev.append("game-state")
        return "game_state_new", ev
    # score 分档
    if re.search(r'query\(\s*"score"\s*\)', body):
        ev.append("query-score")
        return "score_tiers", ev
    # 房间属性（create 里 set 的，非 temp）
    if re.search(r'query\(\s*"status"\s*\)|query\(\s*"book_count"\s*\)|query\(\s*"marks/', body):
        ev.append("room-attr")
        return "room_state_tiers", ev
    # 玩家 temp
    if re.search(r'this_player\(\)\s*->\s*query_temp', body):
        ev.append("player-temp")
        return "player_temp_branch", ev
    # 房间 temp
    if re.search(r'this_object\(\)\s*->\s*query_temp|query_temp\(\s*"', body):
        ev.append("room-temp")
        return "room_temp", ev
    # 环境对象存在性
    if re.search(r'present\(|find_player|find_npc|environment\(|->is_character\(|->is_corpse', body):
        ev.append("object-presence")
        return "room_occupancy", ev
    # 其它玩家属性查询（qi/str/kee 等，视作 gated 二态先记 unknown 待定）
    if re.search(r'this_player\(\)\s*->\s*query\(\s*"(qi|str|kee|max_kee|combat_exp|age|gender)"', body):
        ev.append("player-attr")
        return "unknown", ev
    # 仅 this_player() 开关判断
    if re.search(r'this_player\(\)', body):
        ev.append("player-ref")
        return "unknown", ev
    # 任何 ->method 调用
    if re.search(r'->\w+\(', body):
        ev.append("method-call")
        return "unknown", ev
    # 兜底
    return "unknown", ev


# 只处理被 backfill 判为 daemon/state 的闭包
buckets = defaultdict(list)
room_index = defaultdict(list)  # fn -> list of (room_id, keyword, lpc_rel)
fn_bodies = {}

for lpc_rel, keyword, fn in closures:
    body = funcs.get(fn)
    if B.is_static(body):
        continue  # 已是 static，跳过
    bucket, ev = classify(fn, body)
    room_index[fn].append((keyword, lpc_rel))
    fn_bodies[fn] = body
    buckets[bucket].append((fn, ev))

print("=== 40 个 daemon/state 闭包重新分类 ===")
print("（注：含同名 fn 多处定义，按首次命中 body 分类；closure 数见每桶）\n")

summary = {}
for bucket in ["score_tiers", "room_state_tiers", "room_temp", "player_temp_branch",
               "room_occupancy", "gated_text", "daemon_new", "game_state_new", "unknown", "nodef"]:
    items = buckets.get(bucket, [])
    if not items:
        continue
    # 去重 fn，统计涉及的 closure 数
    fns = sorted(set(fn for fn, _ in items))
    closure_count = sum(len(room_index[fn]) for fn in fns)
    summary[bucket] = {"fns": fns, "closure_count": closure_count}
    print("\n### %s  (%d 个 fn / %d 处 closure)" % (bucket, len(fns), closure_count))
    for fn in fns:
        rooms = room_index[fn]
        body = fn_bodies.get(fn) or ""
        snippet = body.replace("\n", " ")[:140]
        print("  - %s  [%d 处]  body: %s" % (fn, len(rooms), snippet))
        for kw, rel in rooms:
            zone, stem = B.lpc_to_zone_room(rel)
            print("        room=%s/%s  kw=%s" % (zone, stem, kw))

# 写出 JSON 便于审计
out = {}
for bucket in summary:
    out[bucket] = {
        "closure_count": summary[bucket]["closure_count"],
        "fns": {fn: [{"keyword": kw, "lpc_rel": rel} for kw, rel in room_index[fn]]
                for fn in summary[bucket]["fns"]},
    }
with io.open(OUT, "w", encoding="utf-8") as f:
    import json
    json.dump(out, f, ensure_ascii=False, indent=1)
print("\nJSON -> %s" % OUT)

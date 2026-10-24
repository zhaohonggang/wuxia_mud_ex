#!/usr/bin/env python3
"""Survey LPC `set("inquiry", ...)` closures: classify by body complexity.

Output: tmp/inquiry_survey.json + a console summary.

Classification per closure body (heuristic):
  - text_only     : only returns/strings, no side effects
  - item_grant    : `new(` + `move(` pattern (give_item kind candidate)
  - perform_teach : sets can_perform / improve_skill (perform_id candidate)
  - state_change  : set/add/delete on this_object() or me
  - complex       : anything else (quest hooks, combat, random, etc.)
"""
import json
import re
import sys
from pathlib import Path

MUD = Path("C:/files/git/mud")
EX = Path("C:/files/git/wuxia_mud_ex/data/world")
OUT = Path("C:/files/git/wuxia_mud_ex/tmp/inquiry_survey.json")

# Elixir UCL 侧：`characters "<key>" { ... inquiries = [ {key=..} ] 或 {k=v} ... }`
UCL_CHAR = re.compile(r'characters\s+"([^"]+)"\s*\{')
UCL_INQ_ARRAY = re.compile(r'inquiries\s*=\s*\[(.*?)\]', re.S)
UCL_INQ_MAP = re.compile(r'inquiries\s*=\s*\{(.*?)\n\s*\}', re.S)
UCL_INQ_KEY = re.compile(r'key\s*=\s*"([^"]*)"')

INQUIRY_BLOCK = re.compile(r'set\(\s*"inquiry"\s*,\s*\(\[(.*?)\]\)\s*\)', re.S)
ENTRY = re.compile(r'"([^"]+)"\s*:\s*\(\s*:\s*([A-Za-z_0-9]+)\s*(?:,\s*"([^"]*)"\s*)?:\s*\)')
# 纯字符串条目："key" : "text"（可能跨行拼接）。lookahead 里必须带上 `\s*$`：
# INQUIRY_BLOCK 的捕获把结尾的 `]` 吃掉了，块内最后一条字符串条目后面只剩空白，
# 少了这条分支就会漏掉每个表的末条（如 miao.c 的「胡一刀」）。
STRING_ENTRY = re.compile(r'"([^"]+)"\s*:\s*((?:"(?:[^"\\]|\\.)*"\s*)+)\s*,\s*(?=\n\s*(?:"|\])|\s*$)', re.S)
FUNC_DEF = re.compile(r'(?:mixed|string|int|void)\s+([A-Za-z_0-9]+)\s*\(')
# LPC set_name("中文名", ({ "alias with space", "short" }))——别名里有空格才算可用标识
SET_NAME = re.compile(r'set_name\(\s*"([^"]+)"\s*,\s*\(\{\s*([^}]*?)\s*\}\)')


def brace_block(src, start):
    """src[start] 必须是 '{'；返回配平后的整块文本（含两端花括号）。"""
    i = src.index("{", start)
    depth = 0
    j = i
    while j < len(src):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    return src[i : j + 1]


def parse_c_string(raw):
    """Join C adjacent string literals and decode basic escapes."""
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', raw)
    joined = "".join(parts)
    return (
        joined.replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace('\\"', '"')
        .replace("\\'", "'")
    )


def extract_functions(src):
    """Return {func_name: body} by brace matching on function definitions."""
    funcs = {}
    for m in FUNC_DEF.finditer(src):
        name = m.group(1)
        if name in ("create", "init"):
            continue
        # find opening brace after the parameter list
        i = src.find("{", m.end())
        if i < 0:
            continue
        depth = 0
        j = i
        while j < len(src):
            c = src[j]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        body = src[i : j + 1]
        # keep the first (outermost) definition only
        if name not in funcs:
            funcs[name] = body
    return funcs


def extract_return_strings(body):
    """Best-effort: pull the literal strings a closure returns/replies."""
    texts = []
    # return "..." (possibly adjacent literals across lines)
    for m in re.finditer(r'\breturn\s+((?:"(?:[^"\\]|\\.)*"\s*)+)', body):
        texts.append(parse_c_string(m.group(1)))
    # tell_object/write("...") 形式（授招类常用）
    for m in re.finditer(r'\b(?:tell_object|write)\s*\(\s*[^,]+,\s*((?:"(?:[^"\\]|\\.)*"\s*)+)', body):
        texts.append(parse_c_string(m.group(1)))
    return [t for t in texts if t.strip()]


def classify(body):
    b = body
    has_new = bool(re.search(r"\bnew\s*\(", b))
    has_move = bool(re.search(r"->move\s*\(", b))
    has_can_perform = "can_perform" in b
    has_improve = "improve_skill" in b
    has_side_effect = bool(re.search(r"\b(this_object\(\)|ob|me)->(set|add|delete|set_temp|delete_temp)\s*\(", b))
    has_combat = bool(re.search(r"\b(kill_ob|fight_ob|command\s*\(\s*\"(kill|fight|exert|perform))", b))
    has_quest = bool(re.search(r"QUEST|ULTRA", b))
    has_random = "random(" in b

    if has_can_perform or has_improve:
        return "perform_teach"
    if has_new and has_move:
        return "item_grant"
    if has_quest:
        return "quest_hook"
    if has_combat:
        return "combat"
    if has_side_effect:
        return "state_change"
    if has_random:
        return "random_reply"
    # only string literals / returns?
    stripped = re.sub(r'"[^"]*"', "", b)
    stripped = re.sub(r"//[^\n]*", "", stripped)
    if not re.search(r"[A-Za-z_0-9]\)\s*\w+\s*\(", stripped):
        return "text_only"
    return "complex"


def elixir_inquiry_keys():
    """{zone: {char_key: set(inquiry keys)}} from the Elixir UCL world data."""
    out = {}
    for path in sorted(EX.glob("*.ucl")):
        zone = path.stem
        src = path.read_text(encoding="utf-8", errors="replace")
        chars = {}
        # 逐个 characters "key" { ... } 块（花括号配平）
        for m in UCL_CHAR.finditer(src):
            key = m.group(1)
            # 正则末尾已含 `{`，故开括号就在 m.end()-1
            i = m.end() - 1
            if src[i] != "{":
                continue
            depth, j = 0, i
            while j < len(src):
                if src[j] == "{":
                    depth += 1
                elif src[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            body = src[i : j + 1]
            keys = set()
            for blk in UCL_INQ_ARRAY.findall(body):
                keys.update(UCL_INQ_KEY.findall(blk))
            # inquiries = { ... }：花括号配平取整块，只收 depth=1 的顶层键。
            # （旧正则 `\{(.*?)\n\s*\}` 非贪婪，会停在第一个内层条目的收括号处。）
            for mm in re.finditer(r"inquiries\s*=\s*\{", body):
                s = mm.end() - 1
                d, k = 0, s
                while k < len(body):
                    if body[k] == "{":
                        d += 1
                    elif body[k] == "}":
                        d -= 1
                        if d == 0:
                            break
                    k += 1
                inner = body[s + 1 : k]
                # 逐行扫：先判深度再计数，只认花括号深度为 0 时的 `key =` 行
                # （inner 已剥掉最外层花括号，故条目键在深度 0，条目内字段在深度 1）
                d2 = 0
                for line in inner.split("\n"):
                    if d2 == 0:
                        mk = re.match(r'\s*("?[^"={}\s]+"?)\s*=', line)
                        if mk:
                            keys.add(mk.group(1).strip('"'))
                    d2 += line.count("{") - line.count("}")
            if keys:
                chars[key] = keys
        if chars:
            out[zone] = chars
    return out


def main():
    results = {}
    lpc_names = {}
    # 全库扫描：门派师父在 kungfu/class/**（张三丰等），系统 NPC 在 adm/**。
    # 只扫 d/ 与 clone/ 会漏掉 ~200 个带 inquiry 的文件（P5-4as 踩过）。
    # b/ 是备份目录，跳过。
    files = [
        p
        for p in sorted(MUD.glob("**/*.c"))
        if p.relative_to(MUD).parts[0] != "b"
    ]

    for path in files:
        try:
            src = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        blocks = INQUIRY_BLOCK.findall(src)
        if not blocks:
            continue

        funcs = extract_functions(src)
        entries = {}
        for blk in blocks:
            # 闭包形式
            for key, closure, arg in ENTRY.findall(blk):
                entries[key] = {"closure": closure, "arg": arg or None}
            # 纯字符串形式
            for key, raw in STRING_ENTRY.findall(blk):
                if key in entries:
                    continue
                entries[key] = {"closure": None, "text": parse_c_string(raw)}

        if not entries:
            continue

        detail = {}
        for key, info in entries.items():
            if info.get("closure") is None:
                detail[key] = {"class": "string_value", "text": info.get("text")}
                continue
            body = funcs.get(info["closure"])
            if body is None:
                detail[key] = {"closure": info["closure"], "class": "closure_not_found"}
            else:
                cls = classify(body)
                item = {
                    "closure": info["closure"],
                    "class": cls,
                    "lines": body.count("\n") + 1,
                }
                if cls == "text_only":
                    texts = extract_return_strings(body)
                    if texts:
                        item["texts"] = texts
                detail[key] = item

        f = str(path.relative_to(MUD)).replace("\\", "/")
        # 记下 LPC 角色中文名：缺口比对按名字解析 NPC（文件名 != UCL 角色键）
        nm = SET_NAME.search(src)
        lpc_names[f] = nm.group(1) if nm else None
        results[f] = detail

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")

    # summary
    from collections import Counter

    by_class = Counter()
    by_class_files = {}
    for f, entries in results.items():
        for key, d in entries.items():
            by_class[d["class"]] += 1
            by_class_files.setdefault(d["class"], set()).add(f)

    print(f"files with inquiry: {len(results)}")
    print(f"total inquiry keys: {sum(by_class.values())}")
    print()
    for cls, n in by_class.most_common():
        print(f"  {cls:20s} {n:5d} keys / {len(by_class_files[cls]):4d} files")

    # 每区缺口：LPC 有 inquiry 的 NPC 文件 vs Elixir UCL 是否有该区 inquiry 数据
    zones = Counter()
    for f in results:
        zone = f.split("/")[1] if f.startswith("d/") else f.split("/")[0]
        zones[zone] += 1
    print()
    print("per-zone LPC files with inquiry (top 20):")
    for z, n in zones.most_common(20):
        print(f"  {z:16s} {n:4d}")

    # ---- LPC vs Elixir 缺口 ----
    # NPC 定位不能只看「文件名 == 角色键」：LPC 文件名用连字符（a-xiu）、UCL 键
    # 用下划线（a_xiu），且 kungfu/class/<sect>/ji.c 这种短名会撞上别区的同名键
    # （shenfeng/ji、qingcheng/ji）。故按 中文名 → 含空格别名 → (区, 文件名) 逐级解析。
    elixir = elixir_inquiry_keys()

    # LPC 目录名 → Elixir UCL 区名（柳溪镇 dev-target 区在 Elixir 侧叫 liuxi）
    ZONE_ALIAS = {
        "minimal_world": "liuxi",
        "minimal_world_v2": "liuxi",
    }
    ELIXIR_ZONES = {p.stem for p in EX.glob("*.ucl")}

    # kungfu/class/<sect>/<npc>.c 是门派师父，本身不在世界里，靠各区练功房的
    #   CLASS_D("<sect>") + "/<npc>" : 1
    # 克隆进场；LPCConverter 把被克隆的 NPC **内联进宿主区**的 UCL（如
    # heimuya/chengdedian.c 克隆 riyue/ren → heimuya.ucl 的 characters "ren"）。
    # 本表由全库 CLASS_D 引用统计得出：多数门派主宿主区与区同名，少数散居多区，
    # 取主区；None = 该门派师父散落多区、无单一主区（按候选消歧）。
    SECT_ZONE_ALIAS = {
        "duan": "dali",          # dali / wanjiegu / xiaoyao
        "emei": "emei",
        "gaibang": "gaibang",    # beijing / city / gaibang
        "gumu": "gumu",
        "henshan": "hengyang",
        "honghua": "kaifeng",
        "hu": "guanwai",         # dali / guanwai / xiangyang
        "huashan": "huashan",
        "jueqing": "jueqing",
        "kunlun": "kunlun",
        "lingjiu": "lingjiu",
        "lingxiao": "lingxiao",  # kaifeng / lingxiao / zhongzhou
        "meizhuang": "meizhuang",
        "miao": "zhongzhou",     # 苗家只在 zhongzhou（miaojia_* 房）
        "mingjiao": "mingjiao",
        "murong": "yanziwu",     # guanwai / yanziwu
        "ouyang": "baituo",      # baituo / city
        "quanzhen": "quanzhen",  # gumu / quanzhen
        "riyue": "heimuya",      # heimuya / hengyang / quanzhou
        "shaolin": "shaolin",    # city / lanzhou / shaolin
        "shang": "shaolin",
        "shenlong": "shenlong",
        "songshan": "songshan",
        "taohua": "taohua",      # guiyun / huanghe / taohua / wuguan / xiangyang
        "tianlongsi": "tianlongsi",
        "tiezhang": "tiezhang",
        "ultra": None,           # beijing / dali / huashan / mingjiao / xiakedao
        "wudang": "wudang",
        "wudu": "wudu",
        "xiakedao": "xiakedao",  # city / xiakedao
        "xiaoyao": "xiaoyao",
        "xingxiu": "xiyu",
        "xuedao": "xuedao",
        "xueshan": "xueshan",
        "yunlong": "beijing",
        "zhenyuan": "beijing",
    }

    def lpc_zone(f):
        parts = f.split("/")
        if parts[0] == "d":
            return ZONE_ALIAS.get(parts[1], parts[1])
        if parts[:2] == ["kungfu", "class"]:
            # 区名与门派同名的直接认；否则查 SECT_ZONE_ALIAS 主宿主区
            if parts[2] in ELIXIR_ZONES:
                return parts[2]
            return SECT_ZONE_ALIAS.get(parts[2])
        return None

    # 索引：(区, 角色键) → inquiry 键集合；按 中文名/含空格别名 与 角色键 两路
    entries = {}          # (zone, key) -> frozenset(inquiry keys)
    by_key, by_name = {}, {}
    for zone, chars in elixir.items():
        for key, keys in chars.items():
            entries[(zone, key)] = frozenset(keys)
            for k in (key, key.replace("_", "-"), key.replace("-", "_")):
                by_key.setdefault(k, set()).add((zone, key))
    # by_name / all_* 需要角色中文名/别名：elixir_inquiry_keys 只回了 inquiry 键，
    # 另行建索引。all_* 收录**全部**角色（含没有 inquiry 块的）——门派师父克隆进
    # 世界后可能尚未回填问询表（如 zhongzhou/miao 苗人凤），此时应判「全部缺失」而
    # 非「角色未移植」，否则会拿同名的别处 NPC（shaolin/miao）顶包。
    by_name, all_by_key, all_by_name = {}, {}, {}
    for path in sorted(EX.glob("*.ucl")):
        zone = path.stem
        src = path.read_text(encoding="utf-8", errors="replace")
        for m in UCL_CHAR.finditer(src):
            key = m.group(1)
            body = brace_block(src, m.end() - 1)
            for k in (key, key.replace("_", "-"), key.replace("-", "_")):
                all_by_key.setdefault(k, set()).add((zone, key))
            nm = re.search(r'\bname\s*=\s*"([^"]*)"', body)
            al = re.search(r'\baliases\s*=\s*\[([^\]]*)\]', body)
            names = set()
            if nm:
                names.add(nm.group(1))
                names.add(nm.group(1).split()[0])
            if al:
                names.update(a for a in re.findall(r'"([^"]*)"', al.group(1)) if " " in a)
            for n in names:
                if n:
                    all_by_name.setdefault(n, set()).add((zone, key))
                    if (zone, key) in entries:
                        by_name.setdefault(n, set()).add((zone, key))

    def resolve(f, npc, chinese_name):
        """返回该 LPC NPC 在 Elixir 侧的 inquiry 键集合；解析不到返回 None。

        解析顺序（见下方策略注释）：
          1. 宿主区一致——门派师父走 SECT_ZONE_ALIAS 主宿主区，d/<zone>/ 走区名；
          2. 中文名/含空格别名唯一命中（仅当 LPC 区未知或无同区副本时）；
          3. LPC 区未知时（adm/、clone/）才允许文件名键唯一命中。
        """
        lz = lpc_zone(f)
        # 候选分两类：名字类（中文名/含空格别名，辨识度极高）与键类（LPC 文件名，
        # 可能是 "ji" 这种单字母短名，跨区撞车）。all_* 索引覆盖无 inquiry 块的角色。
        name_cands, key_cands, all_name_cands, all_key_cands = [], [], [], []
        if chinese_name:
            name_cands.append(by_name.get(chinese_name))
            all_name_cands.append(all_by_name.get(chinese_name))
            if " " in chinese_name:
                name_cands.append(by_name.get(chinese_name.split()[0]))
                all_name_cands.append(all_by_name.get(chinese_name.split()[0]))
        for cand_key in (npc, npc.replace("-", "_"), npc.replace("_", "-")):
            key_cands.append(by_key.get(cand_key))
            all_key_cands.append(all_by_key.get(cand_key))

        # 策略 1：宿主区一致（门派师父走 SECT_ZONE_ALIAS 主宿主区）。
        # `kungfu/class/emei/ji.c` 的短键 "ji" 会撞上 shenfeng/ji、qingcheng/ji，
        # 靠区名排除；riyue/ren 则靠 alias 把 meizhuang/ren 排除、认 heimuya/ren。
        if lz is not None:
            stem_variants = {npc, npc.replace("-", "_"), npc.replace("_", "-")}
            # clone_lib 是主定义库：同名角色在 clone_lib 的副本即权威来源，与 LPC
            # 宿主区同等对待（商剑鸣/桑三娘/刘处玄 等门派师父均 clone_lib-inlined）。
            # 否则策略 1 的 all_* 回退会在「宿主区存在同名但无 inquiry 块的角色」时
            # 误判「全部缺失」（如 shaolin:shang_jianming 顶替 clone_lib:shang_ming）。
            zones = {lz, "clone_lib"}
            # 名字确认集：与 LPC 中文名（含首词）相同的所有 (区,键)——即「确实是同一
            # 个 NPC」的候选。用于把 by_stem 限定为「文件名 stem 命中且确为同人」，避免
            # 误把同区同名异人（如 taohua:huang 黄伯流）当成本 NPC。
            name_zks = set()
            if chinese_name:
                name_zks |= by_name.get(chinese_name, set())
                if " " in chinese_name:
                    name_zks |= by_name.get(chinese_name.split()[0], set())
            for hit in name_cands + key_cands:
                if not hit:
                    continue
                same = [zk for zk in hit if zk[0] in zones]
                if not same:
                    continue
                # 优先有 inquiry 块的（clone_lib 主定义，或同区有问询的副本）
                have_hit = [zk for zk in same if zk in entries]
                pool = have_hit or same
                # by_stem：文件名 stem 精确对应宿主区 UCL 角色键，且**确为同人**（在
                # name_zks 内）。这是最精确的「文件即此 NPC」证据：
                #   xiaofan→fuzhou:xiaofan、chuanfu→taohua:chuanfu 因此胜过 clone_lib
                #   里的异区同名副本（quanzhen_seller / shenlong_chuanfu）。
                # 门派师父（黄药师/张三丰/商剑鸣）的 clone_lib 键是 huang_yaoshi /
                # zhang_sanfeng / shang_ming，不等于裸文件名，by_stem 为空 → 不触发，
                # 仍走 clone_hit 认 clone_lib 权威副本（其数据最完整，loader 亦以
                # clone_lib 副本为权威）。
                by_stem = [zk for zk in pool if zk[1] in stem_variants and zk in name_zks]
                clone_hit = [zk for zk in pool if zk[0] == "clone_lib"]
                in_zone = [zk for zk in pool if zk[0] == lz]
                # 决定性挑选（Python set 迭代顺序随机，不能靠 pool[0]）：
                # 1) by_stem（同人+文件名精确命中，优先本区数据）；2) clone_lib 主定义；
                # 3) 同宿主区副本；4) 兜底首条。
                pick = (
                    by_stem[0]
                    if by_stem
                    else clone_hit[0]
                    if clone_hit
                    else in_zone[0]
                    if in_zone
                    else pool[0]
                )
                return entries.get(pick, frozenset())
            # 同区（含 clone_lib）角色存在但**没有** inquiry 块（如 zhongzhou/miao 苗人凤）：
            # 判「全部缺失」而不是回退到别的区的同名 NPC。
            for hit in all_name_cands + all_key_cands:
                if not hit:
                    continue
                if any(zk[0] in zones for zk in hit):
                    return frozenset()

        # 策略 2：名字类唯一命中即认（中文名/别名跨区重名极少，且此时 LPC 区未知
        # 或无同区副本）。**键类不享受此策略**——"ji" 会单点命中 shenfeng/ji 而
        # LPC 文件其实是 emei/ji，必须等策略 1 的区名背书；LPC 区未知时（adm/、
        # clone/ 下的系统 NPC）才允许键类唯一命中。
        for hit in name_cands:
            if not hit:
                continue
            real = [zk for zk in hit if zk[0] != "clone_lib"]
            pool = real if real else list(hit)
            if len(pool) == 1:
                return entries[pool[0]]
            if len(pool) > 1:
                # 多区歧义（如 苗人凤 的 shaolin / zhongzhou 两份）无法自动判定，
                # 交给策略 1 的区名；这里放弃以免误报。
                continue
        if lz is None:
            for hit in key_cands:
                if not hit:
                    continue
                real = [zk for zk in hit if zk[0] != "clone_lib"]
                pool = real if real else list(hit)
                if len(pool) == 1:
                    return entries[pool[0]]
        return None

    # 已知 LPC 自身缺陷/死代码（非移植缺口），列出以免反复误报
    KNOWN_LPC_DEAD = {
        # set("inquiry", ...) 被第二次调用整体覆盖（dbase.c set() 是覆盖语义）
        ("xiangyang", "wuxiuwen"): "LPC set(\"inquiry\") 二次调用覆盖首表",
        # new("/d/lingxiao/obj/yupai") 指向不存在的文件，运行期即报错
        ("lingxiao", "cheng"): "LPC new(/d/lingxiao/obj/yupai) 目标文件不存在",
    }

    # 柳溪镇 dev-target 区在 Elixir 侧叫 liuxi，且内容已演化（quest/turn_in 取代
    # 部分问询）；v2 是平行开发靶，未移植。
    DIVERGED_ZONES = {"minimal_world", "minimal_world_v2"}

    gap_keys = 0
    gap_npcs = 0
    text_backfill = 0
    absent_npcs = 0
    print()
    print("per-file GAP (LPC keys missing from Elixir UCL):")
    trace = set(a for a in sys.argv[1:] if not a.startswith("-"))
    for f in sorted(results):
        zone = f.split("/")[1] if f.startswith("d/") else f.split("/")[0]
        npc = Path(f).stem
        lpc_entries = results[f]
        have = resolve(f, npc, lpc_names.get(f))
        if f in trace:
            # 调试单个文件的 NPC 解析路径：区、候选、解析结果
            lz = lpc_zone(f)
            cands = []
            cn = lpc_names.get(f)
            if cn:
                cands.append(("name", cn, by_name.get(cn)))
                if " " in cn:
                    cands.append(("name[0]", cn.split()[0], by_name.get(cn.split()[0])))
            for ck in (npc, npc.replace("-", "_"), npc.replace("_", "-")):
                cands.append(("key", ck, by_key.get(ck)))
            print(f"  [trace] {f}: zone={zone} lpc_zone={lz} name={cn}")
            for how, k, hit in cands:
                if hit:
                    print(f"  [trace]   {how} {k!r} -> {sorted(hit)}")
            print(f"  [trace]   resolved={'None' if have is None else len(have)} keys")
        if have is None:
            # NPC 本身不在 Elixir 数据里（如 ultra/huang 黄裳、emei/ji 纪晓芙）
            if not f.startswith("d/") or zone not in DIVERGED_ZONES:
                absent_npcs += 1
                print(f"  [NPC absent] {f}: 角色未移植，{len(lpc_entries)} 个问询键随之缺失")
            continue
        # 柳溪镇 dev-target 区内容已演化（玉佩问询变成 quest/turn_in、店小二
        # 文案重写），LPC minimal_world 的问询不再逐条对应，整区跳过。
        if zone in DIVERGED_ZONES:
            continue
        miss = [k for k in lpc_entries if k not in have]
        if not miss:
            continue
        miss_text = sum(
            1
            for k in miss
            if lpc_entries[k]["class"] in ("string_value", "text_only")
            and (lpc_entries[k].get("text") or lpc_entries[k].get("texts"))
        )
        gap_keys += len(miss)
        gap_npcs += 1
        text_backfill += miss_text
        print(f"  {f:44s} missing {len(miss):3d} (text-backfillable {miss_text:3d})")

    for (zone, npc), note in sorted(KNOWN_LPC_DEAD.items()):
        print(f"  [known LPC defect] {zone}/{npc}: {note}")

    print()
    print(
        f"TOTAL missing keys: {gap_keys} across {gap_npcs} NPCs "
        f"(text-backfillable {text_backfill}); NPC-absent files: {absent_npcs}"
    )


if __name__ == "__main__":
    main()

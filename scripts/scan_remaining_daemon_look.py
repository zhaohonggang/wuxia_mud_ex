#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-4 剩余 daemon/state 闭包可行性扫描（只读、可重跑）。

目标：把 40 个 daemon/state 闭包里还「未回填」的 5 类找出来，并定位每个用法
对应的真实函数体（不依赖 survey 的「首次命中」归因，逐房解析继承 + 本文件优先），
判断能否用既有 8 个 handler 表达，或必须新建子系统。

输出：stdout 人类可读报告；可选落 tmp/remaining_daemon_look.json。
"""
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
MUD_ROOT = "C:/files/git/mud"
OUT_JSON = os.path.join(SCRIPT_DIR, "tmp", "remaining_daemon_look.json")

TARGETS = ["look_board", "look_pet", "look_tiaofu", "look_gaoshi", "look_table"]

ITEM_DESC_CLOSURE_RE = re.compile(
    r'set\s*\(\s*["\']item_desc["\']\s*,\s*\(\[\s*(.*?)\s*\]\s*\)\s*\)', re.DOTALL)


def split_top_level(text):
    items = []
    depth = 0
    cur = []
    in_str = False
    esc = False
    for ch in text:
        if in_str:
            cur.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
            cur.append(ch)
            continue
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            items.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    last = "".join(cur).strip()
    if last:
        items.append(last)
    return items


PAIR_RE = re.compile(r'"([^"]*)"\s*:\s*\(:\s*([A-Za-z_]\w*)\s*:\s*\)', re.DOTALL)
FUNC_RE = re.compile(
    r"(?m)^[ \t]*(?:[\w\*]+[ \t]+)+(?P<name>[A-Za-z_]\w*)[ \t]*\((?P<args>[^)]*)\)[ \t]*\n?[ \t]*\{")
INHERIT_RE = re.compile(r'inherit\s+"([^"]+)"')
SET_TERM_RE = re.compile(r"set_temp\s*\(\s*['\"]([^'\"]+)['\"]")
QUERY_TERM_RE = re.compile(r"query_temp\s*\(\s*['\"]([^'\"]+)['\"]")

STRIP_STR_RE = re.compile(r'"(\\.|[^"\\])*"')
STRIP_COMMENT_RE = re.compile(r"/\*.*?\*/|//[^\n]*", re.DOTALL)
COND_RE = re.compile(
    r"\b(if|else|for|while|switch|case|query|query_temp|set|set_temp|random|"
    r"objectp|this_player|find_object|load_object|call_other|me->|this_object)\b|->")


def read(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            return fh.read()
    except OSError:
        return ""


def extract_functions(text):
    funcs = {}
    for m in FUNC_RE.finditer(text):
        name = m.group("name")
        brace = text.find("{", m.end() - 1)
        if brace < 0:
            continue
        depth = 0
        i = brace
        while i < len(text):
            c = text[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        funcs[name] = text[m.start():i + 1]
    return funcs


def classify(body):
    if not body:
        return "unknown"
    code = STRIP_COMMENT_RE.sub(" ", body)
    code = STRIP_STR_RE.sub('""', code)
    brace = code.find("{")
    inner = code[brace + 1:] if brace >= 0 else code
    if COND_RE.search(inner):
        return "conditional"
    if re.search(r"\b[A-Za-z_]\w*\s*\(", inner):
        return "conditional"
    return "static"


def resolve_inherits(text, base_dir):
    """返回继承文件的绝对路径候选列表（尽力解析，解析不了就跳过）。"""
    out = []
    for m in INHERIT_RE.finditer(text):
        spec = m.group(1)
        cand = None
        if spec.startswith("/"):
            cand = os.path.join("C:/files/git/mud", spec.lstrip("/"))
        elif spec.startswith("__DIR__"):
            rel = spec[len("__DIR__"):].strip().strip('"')
            cand = os.path.join(base_dir, rel)
        else:
            # 相对 inherit "sub/room" 或宏
            cand = os.path.join(base_dir, spec)
        if cand and cand.endswith(".c") is False:
            cand = cand + ".c"
        if cand:
            out.append(cand.replace("\\", "/"))
    return out


def find_body(fn, file_path, file_cache):
    """本文件优先，再走继承链（BFS），最后全库首命中。"""
    searched = set()
    queue = [file_path]
    while queue:
        fp = queue.pop(0)
        fp = fp.replace("\\", "/")
        if fp in searched:
            continue
        searched.add(fp)
        text = file_cache.get(fp)
        if text is None:
            text = read(fp)
            file_cache[fp] = text
        funcs = extract_functions(text)
        if fn in funcs:
            return funcs[fn], fp
        for inh in resolve_inherits(text, os.path.dirname(fp)):
            if inh not in searched:
                queue.append(inh)
    return None, None


def main():
    if not os.path.isdir(MUD_ROOT):
        print("MUD_ROOT 不存在: %s" % MUD_ROOT, file=sys.stderr)
        sys.exit(1)

    # 第一轮：收集所有用法（房间文件 + keyword + fn）
    usages = {t: [] for t in TARGETS}
    file_cache = {}
    for dirpath, _d, filenames in os.walk(MUD_ROOT):
        for fn in filenames:
            if not fn.endswith(".c"):
                continue
            full = os.path.join(dirpath, fn).replace("\\", "/")
            text = read(full)
            if not text:
                continue
            file_cache.setdefault(full, text)
            for m in ITEM_DESC_CLOSURE_RE.finditer(text):
                body = m.group(1)
                for item in split_top_level(body):
                    pm = PAIR_RE.search(item)
                    if not pm:
                        continue
                    kw = pm.group(1)
                    called = pm.group(2)
                    if called in TARGETS:
                        # 计算房间 zone/stem
                        rel = full.split("/d/")[-1]
                        parts = rel.split("/")
                        zone = parts[0] if parts else "?"
                        stem = parts[-1][:-2] if parts[-1].endswith(".c") else parts[-1]
                        usages[called].append((full, zone, stem, kw))

    # 第二轮：逐用法解析函数体
    report = {}
    for t in TARGETS:
        entries = []
        for (full, zone, stem, kw) in usages[t]:
            body, src = find_body(t, full, file_cache)
            cls = classify(body) if body else "not_found"
            snippet = (body or "")[:500]
            entries.append({
                "usage": "%s:%s" % (zone, stem),
                "keyword": kw,
                "source_file": src.split("/d/")[-1] if src else None,
                "class": cls,
                "snippet": snippet,
                "set_term": sorted(set(SET_TERM_RE.findall(snippet))),
                "query_term": sorted(set(QUERY_TERM_RE.findall(snippet))),
            })
        report[t] = entries

    # 输出
    for t in TARGETS:
        print("=" * 70)
        print("TARGET: %s  (%d 处用法)" % (t, len(usages[t])))
        print("=" * 70)
        # 按 source_file 聚类
        by_src = {}
        for e in report[t]:
            by_src.setdefault(e["source_file"], []).append(e)
        for src, es in sorted(by_src.items(), key=lambda x: str(x[0])):
            cls = es[0]["class"]
            print("\n  [定义源] %s  (class=%s, %d 处)" % (src, cls, len(es)))
            for e in es:
                print("    - 用法 %s  kw=%-10s  set_temp=%s query_temp=%s"
                      % (e["usage"], e["keyword"], e["set_term"], e["query_term"]))
            if es[0]["snippet"]:
                sn = es[0]["snippet"]
                sn = sn.replace("\t", "  ")
                print("      函数体前 500 字:")
                for line in sn.splitlines()[:25]:
                    print("        | " + line.rstrip())
        print("")

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)
    print("完整结果 → %s" % OUT_JSON)


if __name__ == "__main__":
    main()

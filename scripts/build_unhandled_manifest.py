#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P0 — turn data/world/*.comments.txt into a structured, actionable work list.

Why this exists
---------------
`data/world/<zone>.comments.txt` is the converter's own record of what it could
NOT convert.  As shipped it is human-readable text only: no ids, no de-dup, no
priority, no source line numbers.  That makes it impossible to schedule, verify
or regression-test.  Worse, 83.2% of its `if (...) ->` lines carry an EMPTY
action, because the converter's `_BRANCH_ACTION` regex only recognises
command/say/tell_object/message_vision/write -- so the branch body is not
recorded anywhere.

This script fixes both problems WITHOUT touching the converter:

  1. It parses the sidecars into records with stable ids
     (`<zone>:<object>#<kind>#<name>`).
  2. For every unhandled function it goes back to the authoritative LPC source
     (`C:\\files\\git\\mud`) and extracts the FULL function body, recovering the
     information the sidecar dropped.

It is strictly read-only: it never writes into data/world, and it never calls
into scripts/lpc_converter.py.  The converter stays frozen.

Usage:
    python scripts/build_unhandled_manifest.py [--world data/world]
                                               [--out tmp/unhandled_manifest.json]
"""
import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict

from lpc_paths import resolve_source_path

# --- sidecar grammar --------------------------------------------------------

GEN_RE = re.compile(r"^# Generated from (\S+) by LPCConverter\s*$")
ZONE_RE = re.compile(r"^# Zone: (\S+)\s*$")
INHERIT_RE = re.compile(r"^# inherit (.+);\s*$")
GENERIC_RE = re.compile(r"^# Generic LPC file: (\S+)\s*$")

FN_ITEM_RE = re.compile(r"^  # UNHANDLED FUNCTION: (\S+)\s*$")
GLOBAL_ITEM_RE = re.compile(r"^  # UNHANDLED GLOBAL: (\S+) (\S+)\s*$")
BRANCH_RE = re.compile(r"^  # (else if \(.*\)|if \(.*\)|else)\s+→\s*(.*)$")
COMPLEX_IF_RE = re.compile(r"^  # COMPLEX IF: (.*)$")
SWITCH_POOL_RE = re.compile(r"^  # SWITCH POOL: (.*)$")
SWITCH_STMT_RE = re.compile(r"^  # SWITCH: (.*)$")
SWITCH_TBL_RE = re.compile(r"^  # SWITCH TABLE \(expr: (.*)\)\s*$")
SWITCH_ROW_RE = re.compile(r"^  #   (.*?): (.*)$")
RAW_RE = re.compile(r"^  # RAW BLOCK: (\S+)\s*$")
COMPLEX_MAP_RE = re.compile(r"^  # COMPLEX MAPPING: (.*)$")

# Section headers are emitted AFTER their content (the converter reverses the
# whole block), so we buffer items and flush them when the header arrives.
HDR_FUNCS = re.compile(r"^# ==== UNHANDLED FUNCTIONS ====\s*$")
HDR_GLOBALS = re.compile(r"^# ==== UNHANDLED GLOBAL VARIABLES ====\s*$")
HDR_COND = re.compile(r"^# ==== CONDITIONAL BRANCHES(?:\s*\((.*?)\))?\s*====\s*$")
HDR_COMPLEX = re.compile(r"^# ==== COMPLEX CONDITIONALS ====\s*$")
HDR_SWITCH_POOL = re.compile(r"^# ==== SWITCH POOLS ====\s*$")
HDR_SWITCH_STMT = re.compile(r"^# ==== SWITCH STATEMENTS ====\s*$")
HDR_SWITCH_TBL = re.compile(r"^# ==== SWITCH TABLES ====\s*$")
HDR_RAW = re.compile(r"^# ==== RAW CODE BLOCKS ====\s*$")
HDR_COMPLEX_MAP = re.compile(r"^# ==== COMPLEX MAPPINGS ====\s*$")
ANY_HDR = re.compile(r"^# ==== .*====\s*$")


# --- LPC source helpers (self-contained; converter is NOT imported) ---------

def decode(raw: bytes) -> str:
    """LPC corpus is mostly GBK/GB2312; keep already-valid UTF-8 as-is."""
    for enc in ("utf-8", "gbk", "gb18030", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace")


def strip_noise(text: str) -> str:
    """Blank out strings, char literals and comments so brace matching is safe."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            i += 2
            out.append("  ")
            continue
        if c in "\"'":
            q = c
            out.append(" ")
            i += 1
            while i < n and text[i] != q:
                if text[i] == "\\":
                    out.append(" ")
                    i += 1
                    if i < n:
                        out.append(" ")
                        i += 1
                    continue
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            if i < n:
                out.append(" ")
                i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def heredoc_spans(text: str):
    """Return [(start, end)] of @LONG ... LONG bodies, so we can skip them."""
    spans = []
    for m in re.finditer(r"@([A-Za-z_][A-Za-z0-9_]*)\s*\n", text):
        tag = m.group(1)
        end = re.compile(r"^\s*" + re.escape(tag) + r"\s*\)?", re.M).search(text, m.end())
        if end:
            spans.append((m.start(), end.end()))
    return spans


def find_function_body(text: str, name: str):
    """Extract `name(...) { ... }` from LPC source, or None.

    Skips forward declarations (`string look_hua();`) and heredoc bodies.
    """
    clean = strip_noise(text)
    spans = heredoc_spans(text)
    pat = re.compile(r"(?<![\w>])" + re.escape(name) + r"\s*\(")
    for m in pat.finditer(clean):
        # skip if inside a heredoc body
        if any(s <= m.start() < e for s, e in spans):
            continue
        # find the closing paren of the parameter list
        i = clean.index("(", m.end() - 1)
        depth = 0
        while i < len(clean):
            if clean[i] == "(":
                depth += 1
            elif clean[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        j = i + 1
        while j < len(clean) and clean[j] in " \t\r\n":
            j += 1
        if j >= len(clean) or clean[j] == ";":
            continue  # forward declaration
        if clean[j] != "{":
            continue
        depth = 0
        k = j
        while k < len(clean):
            if clean[k] == "{":
                depth += 1
            elif clean[k] == "}":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        # slice the ORIGINAL text so strings/comments stay readable
        return text[m.start(): k + 1].strip()
    return None


def object_id_of(source_path: str) -> str:
    base = os.path.basename(source_path)
    if base.endswith(".c"):
        base = base[:-2]
    return base.replace("-", "_")


DEF_RE = re.compile(
    r"^[ \t]*(?:int|void|string|object|mixed|mapping|float|int\s*\*|string\s*\*)"
    r"[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(",
    re.M,
)


def build_corpus_index(corpus: str, cache_path: str):
    """name -> [source paths] for every .c under `corpus`.

    68 of the 2136 `UNHANDLED FUNCTION` entries are not defined in their own
    file: the converter computed them over the MERGED inherit chain, so they
    live in a base class (`drool`, `end_working`, ...).  Indexing the corpus
    lets us point at the real definition instead of leaving a dead end.
    """
    if os.path.isfile(cache_path):
        try:
            with open(cache_path, encoding="utf-8") as fh:
                return json.load(fh)
        except Exception:
            pass
    index = defaultdict(list)
    for root, _, files in os.walk(corpus):
        for fn in files:
            if not fn.endswith(".c"):
                continue
            p = os.path.join(root, fn)
            try:
                txt = decode(open(p, "rb").read())
            except Exception:
                continue
            for m in DEF_RE.finditer(txt):
                index[m.group(1)].append(p)
    index = {k: v for k, v in index.items()}
    os.makedirs(os.path.dirname(cache_path) or ".", exist_ok=True)
    with open(cache_path, "w", encoding="utf-8") as fh:
        json.dump(index, fh)
    return index


# --- sidecar parsing --------------------------------------------------------

def parse_sidecar(path: str, zone: str):
    """Yield one record per `# Generated from` block."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = [ln.rstrip("\n") for ln in fh]

    blocks = []
    cur = None
    # pending buffers, flushed when their section header shows up
    pend = defaultdict(list)

    def flush(kind, owner=None):
        items = pend.pop(kind, [])
        if not items:
            return
        cur["items"].append({"kind": kind, "owner": owner, "entries": items})

    for ln in lines:
        m = GEN_RE.match(ln)
        if m:
            if cur is not None:
                for k in list(pend):
                    flush(k)
                blocks.append(cur)
            cur = {"source_path": m.group(1), "zone": zone, "items": [],
                   "generic": False, "inherits": []}
            pend = defaultdict(list)
            continue
        if cur is None:
            continue
        if ZONE_RE.match(ln):
            continue
        m = GENERIC_RE.match(ln)
        if m:
            cur["generic"] = True
            continue
        m = INHERIT_RE.match(ln)
        if m:
            cur["inherits"].append(m.group(1))
            continue

        m = FN_ITEM_RE.match(ln)
        if m:
            pend["function"].append({"name": m.group(1)})
            continue
        m = GLOBAL_ITEM_RE.match(ln)
        if m:
            pend["global"].append({"type": m.group(1), "name": m.group(2)})
            continue
        m = BRANCH_RE.match(ln)
        if m:
            pend["cond_branch"].append(
                {"condition": m.group(1), "action": m.group(2).strip()})
            continue
        m = COMPLEX_IF_RE.match(ln)
        if m:
            pend["complex_if"].append({"code": m.group(1).strip()})
            continue
        m = SWITCH_POOL_RE.match(ln)
        if m:
            pend["switch_pool"].append({"code": m.group(1).strip()})
            continue
        m = SWITCH_STMT_RE.match(ln)
        if m:
            pend["switch_stmt"].append({"code": m.group(1).strip()})
            continue
        m = SWITCH_TBL_RE.match(ln)
        if m:
            pend["switch_table"].append({"expr": m.group(1).strip(), "rows": []})
            continue
        m = SWITCH_ROW_RE.match(ln)
        if m and pend["switch_table"]:
            pend["switch_table"][-1]["rows"].append(
                {"key": m.group(1).strip(), "cols": m.group(2).strip()})
            continue
        m = RAW_RE.match(ln)
        if m:
            pend["raw"].append({"name": m.group(1), "body": ""})
            continue
        m = COMPLEX_MAP_RE.match(ln)
        if m:
            pend["complex_map"].append({"code": m.group(1).strip()})
            continue

        # section headers -> flush the buffer that belongs to them
        if HDR_FUNCS.match(ln):
            flush("function"); continue
        if HDR_GLOBALS.match(ln):
            flush("global"); continue
        if HDR_COMPLEX.match(ln):
            flush("complex_if"); continue
        if HDR_SWITCH_POOL.match(ln):
            flush("switch_pool"); continue
        if HDR_SWITCH_STMT.match(ln):
            flush("switch_stmt"); continue
        if HDR_SWITCH_TBL.match(ln):
            flush("switch_table"); continue
        if HDR_RAW.match(ln):
            flush("raw"); continue
        if HDR_COMPLEX_MAP.match(ln):
            flush("complex_map"); continue
        m = HDR_COND.match(ln)
        if m:
            flush("cond_branch", owner=m.group(1))
            continue
        if ANY_HDR.match(ln):
            # unknown header: keep the buffer rather than lose it
            continue

    if cur is not None:
        for k in list(pend):
            flush(k)
        blocks.append(cur)
    return blocks


# --- main -------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--world", default=os.path.join("data", "world"))
    ap.add_argument("--out", default=os.path.join("tmp", "unhandled_manifest.json"))
    ap.add_argument("--corpus", default=r"C:\files\git\mud")
    args = ap.parse_args()

    files = sorted(f for f in os.listdir(args.world) if f.endswith(".comments.txt"))
    records = []
    body_cache = {}
    src_cache = {}
    stats = Counter()

    for fn in files:
        zone = fn[: -len(".comments.txt")]
        blocks = parse_sidecar(os.path.join(args.world, fn), zone)
        for blk in blocks:
            sp = blk["source_path"].replace("\\", "/")
            oid = object_id_of(sp)
            base_id = f"{zone}:{oid}"
            if blk["generic"]:
                records.append({"id": f"{base_id}#generic", "kind": "generic",
                                "zone": zone, "object": oid, "source_path": sp})
                stats["generic"] += 1

            for section in blk["items"]:
                kind, owner, entries = section["kind"], section["owner"], section["entries"]
                if kind == "cond_branch":
                    for e in entries:
                        rec = {"id": f"{base_id}#cond#{owner or '?'}",
                               "kind": "cond_branch", "zone": zone, "object": oid,
                               "source_path": sp, "function": owner,
                               "condition": e["condition"], "action": e["action"]}
                        records.append(rec)
                        stats["cond_branch"] += 1
                        if not e["action"]:
                            stats["cond_branch_bare"] += 1
                    continue
                for e in entries:
                    name = e.get("name") or e.get("expr") or e.get("type") or "?"
                    rec = {"id": f"{base_id}#{kind}#{name}", "kind": kind,
                           "zone": zone, "object": oid, "source_path": sp}
                    rec.update(e)
                    records.append(rec)
                    stats[kind] += 1

    # --- recover function bodies from the authoritative LPC source ---------
    recovered = 0
    missing_src = 0
    for rec in records:
        if rec["kind"] != "function":
            continue
        sp = resolve_source_path(rec["source_path"], args.corpus)
        if sp not in src_cache:
            if os.path.isfile(sp):
                src_cache[sp] = decode(open(sp, "rb").read())
            else:
                src_cache[sp] = None
                missing_src += 1
        text = src_cache[sp]
        if text is None:
            rec["body"] = None
            rec["body_status"] = "source-missing"
            continue
        key = (sp, rec["name"])
        if key not in body_cache:
            body_cache[key] = find_function_body(text, rec["name"])
        body = body_cache[key]
        rec["body"] = body
        rec["body_status"] = "recovered" if body else "not-found"
        if body:
            recovered += 1
        # source line number, for jump-to-source
        if body:
            idx = text.find(body[:60])
            rec["lpc_line"] = text[:idx].count("\n") + 1 if idx >= 0 else None

    # --- fallback: inherited definitions (search the whole corpus once) -----
    unresolved = [r for r in records
                  if r["kind"] == "function" and r["body_status"] == "not-found"]
    if unresolved:
        index = build_corpus_index(args.corpus, os.path.join("tmp", "lpc_function_index.json"))
        for rec in unresolved:
            for p in index.get(rec["name"], []):
                if os.path.normpath(p) == os.path.normpath(
                        resolve_source_path(rec["source_path"], args.corpus)):
                    continue
                try:
                    text = decode(open(p, "rb").read())
                except Exception:
                    continue
                body = find_function_body(text, rec["name"])
                if body:
                    rec["body"] = body
                    rec["body_status"] = "recovered-from-inherit"
                    rec["defined_in"] = p.replace("\\", "/")
                    rec["lpc_line"] = text.find(body[:60])
                    rec["lpc_line"] = (text[: rec["lpc_line"]].count("\n") + 1
                                       if rec["lpc_line"] >= 0 else None)
                    recovered += 1
                    break

    # --- also recover bodies for functions that own conditional branches ----
    owners = {r["function"] for r in records
              if r["kind"] == "cond_branch" and r["function"]}
    owner_bodies = {}
    for rec in records:
        if rec["kind"] == "cond_branch" and rec["function"]:
            key = (rec["source_path"], rec["function"])
            if key in owner_bodies:
                continue
            sp = resolve_source_path(rec["source_path"], args.corpus)
            if sp not in src_cache:
                src_cache[sp] = decode(open(sp, "rb").read()) if os.path.isfile(sp) else None
            text = src_cache[sp]
            owner_bodies[key] = find_function_body(text, rec["function"]) if text else None
            rec["owner_body"] = owner_bodies[key]

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    out = {
        "generated_from": args.world,
        "stats": dict(stats),
        "recovered_bodies": recovered,
        "source_missing": missing_src,
        "branch_owner_functions": len(owners),
        "records": records,
    }
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)

    # --- report ------------------------------------------------------------
    print("=" * 70)
    print(f"sidecars parsed        : {len(files)}")
    print(f"records emitted        : {len(records)}")
    print(f"function bodies recovered from LPC source: {recovered}"
          f"  (source files missing: {missing_src})")
    print(f"distinct branch-owner functions: {len(owners)}")
    print("-" * 70)
    for k, v in stats.most_common():
        print(f"  {k:22s} {v:7d}")
    print("=" * 70)
    print("wrote", args.out)
    print("\nnext: python scripts/analyze_comments_txt.py  (cross-check the counts)")


if __name__ == "__main__":
    main()

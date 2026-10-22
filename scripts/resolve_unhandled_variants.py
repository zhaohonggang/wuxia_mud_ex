#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P0.1 step 1 - re-run the 32 unresolved `UNHANDLED FUNCTION` records through a
naming-variant resolver, and record *why* each one still has no body.

Context
-------
`build_unhandled_manifest.py` looks a function name up verbatim in its own
source file, then in the whole corpus.  For the 32 records that still have
`body_status == "not-found"` the plan asks for a naming-variant pass
(`ask_me1` vs `ask_me_1`).  This script:

  1. tries the exact name and a small set of spelling variants in
     (a) the record's own source file,
     (b) its recursive `inherit` chain (macros expanded through
         `include/globals.h`);
  2. if nothing is attributable, classifies the record as one of
     `noop_commented_out` / `noop_prototype_only` / `noop_other_object`
     / `noop_missing_source` / `noop_unresolved`, with the evidence.

It is strictly read-only for the LPC corpus and never touches `data/world`.
Only `tmp/` is written.  Re-runnable; the second run produces byte-identical
JSON.

Usage:
    python scripts/resolve_unhandled_variants.py [--manifest ...] [--out ...]
"""
import argparse
import collections
import importlib.util
import json
import os
import re
import sys

from lpc_paths import resolve_source_path

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)
MUD_ROOT = os.environ.get("LPC_CORPUS", "C:/files/git/mud")
DEFAULT_MANIFEST = os.path.join(ROOT, "tmp", "unhandled_manifest.json")
DEFAULT_OUT = os.path.join(ROOT, "tmp", "unhandled_variants.json")
DEFAULT_RESOLVED = os.path.join(ROOT, "tmp", "unhandled_manifest_resolved.json")

TYPE_WORDS = (
    "int|void|string|object|mixed|mapping|float|varargs|private|public|static|nomask"
)
DECL_PREFIX_RE = re.compile(r"\b(?:%s)\s+$" % TYPE_WORDS)
INHERIT_RE = re.compile(r"^\s*inherit\s+([^;]+);", re.M)
IDENT_RE = re.compile(r"(?<![\w>])([A-Za-z_][A-Za-z0-9_]*)\s*\(")


def _load_helpers():
    spec = importlib.util.spec_from_file_location(
        "bum", os.path.join(SCRIPT_DIR, "build_unhandled_manifest.py")
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


BUM = _load_helpers()
decode = BUM.decode
find_function_body = BUM.find_function_body
strip_noise = BUM.strip_noise


# --------------------------------------------------------------------------
# name variants
# --------------------------------------------------------------------------

def name_variants(name):
    """Return spelling variants of a function name (never the name itself)."""
    out = set()

    m = re.match(r"^(.*?)(\d+)$", name)
    if m and m.group(1) and not m.group(1).endswith("_"):
        out.add(m.group(1) + "_" + m.group(2))

    out.add(re.sub(r"(?<=[A-Za-z])(?=\d)", "_", name))
    out.add(re.sub(r"(?<=\d)(?=[A-Za-z])", "_", name))
    out.add(name.replace("_", ""))

    out.discard(name)
    out.discard("")
    return sorted(out)


# --------------------------------------------------------------------------
# comments / occurrences
# --------------------------------------------------------------------------

def comment_spans(text):
    """Spans of `//` and `/* */` comments (strings are skipped)."""
    spans = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            j = n if j < 0 else j
            spans.append((i, j))
            i = j
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            spans.append((i, j))
            i = j
            continue
        if c in "\"'":
            q = c
            i += 1
            while i < n and text[i] != q:
                i += 2 if text[i] == "\\" else 1
            i += 1
            continue
        i += 1
    return spans


def in_spans(pos, spans):
    return any(s <= pos < e for s, e in spans)


def _closing_paren(text, open_pos):
    depth = 0
    i = open_pos
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def occurrence_kind(text, start, spans):
    """comment | declaration | definition | call"""
    if in_spans(start, spans):
        return "comment"
    open_pos = text.find("(", start)
    close = _closing_paren(text, open_pos) if open_pos >= 0 else -1
    if close < 0:
        return "call"
    j = close + 1
    while j < len(text) and text[j] in " \t\r\n":
        j += 1
    nxt = text[j] if j < len(text) else ""
    if nxt == "{":
        return "definition"
    line_start = text.rfind("\n", 0, start) + 1
    prefix = text[line_start:start]
    if nxt == ";" and DECL_PREFIX_RE.search(prefix):
        return "declaration"
    return "call"


def collect_occurrences(text, name):
    spans = comment_spans(text)
    pat = re.compile(r"(?<![\w>])" + re.escape(name) + r"\s*\(")
    out = []
    for m in pat.finditer(text):
        out.append({
            "line": text.count("\n", 0, m.start()) + 1,
            "kind": occurrence_kind(text, m.start(), spans),
            "snippet": text[m.start():m.start() + 120].splitlines()[0].strip(),
        })
    return out


# --------------------------------------------------------------------------
# inherit chain
# --------------------------------------------------------------------------

def load_macros():
    path = os.path.join(MUD_ROOT, "include", "globals.h")
    macros = {}
    if not os.path.isfile(path):
        return macros
    text = decode(open(path, "rb").read())
    for m in re.finditer(r'^\s*#define\s+([A-Za-z_]\w*)\s+"([^"]+)"', text, re.M):
        macros[m.group(1)] = m.group(2)
    return macros


MACROS = load_macros()


def resolve_inherit(token, source_path):
    t = token.strip().strip('"')
    t = MACROS.get(t, t)
    if not t:
        return None
    if t.startswith("/"):
        base = os.path.join(MUD_ROOT, t.lstrip("/"))
    else:
        base = os.path.join(os.path.dirname(source_path), t)
    cands = [base] if base.endswith((".c", ".h")) else [base + ".c", base + ".h", base]
    for cand in cands:
        if os.path.isfile(cand):
            return os.path.normpath(cand)
    return None


def inherit_chain(source_path, _cache=None, depth=8):
    _cache = {} if _cache is None else _cache
    seen = set()
    queue = [(os.path.normpath(source_path), 0)]
    while queue:
        cur, d = queue.pop()
        if d >= depth or cur in seen or not os.path.isfile(cur):
            continue
        seen.add(cur)
        text = _cache.get(cur)
        if text is None:
            text = decode(open(cur, "rb").read())
            _cache[cur] = text
        clean = strip_noise(text)
        for m in INHERIT_RE.finditer(clean):
            child = resolve_inherit(m.group(1), cur)
            if child and child not in seen:
                queue.append((child, d + 1))
    seen.discard(os.path.normpath(source_path))
    return seen


# --------------------------------------------------------------------------
# corpus scan (exact names + variants, one pass)
# --------------------------------------------------------------------------

def corpus_files():
    out = []
    for dp, _, fs in os.walk(MUD_ROOT):
        for fn in fs:
            if fn.endswith((".c", ".h")):
                out.append(os.path.join(dp, fn))
    out.sort()
    return out


def scan_corpus(names):
    want = set()
    for n in names:
        want.add(n)
        want.update(name_variants(n))

    hits = collections.defaultdict(list)
    for path in corpus_files():
        try:
            text = decode(open(path, "rb").read())
        except OSError:
            continue
        present = {m.group(1) for m in IDENT_RE.finditer(text)} & want
        for n in present:
            body = find_function_body(text, n)
            if body:
                hits[n].append(os.path.normpath(path))
    return hits


# --------------------------------------------------------------------------
# resolution
# --------------------------------------------------------------------------

def read_text(path, cache):
    if path not in cache:
        cache[path] = decode(open(path, "rb").read()) if os.path.isfile(path) else None
    return cache[path]


def resolve_record(rec, corpus_hits, cache):
    name = rec["name"]
    sp = os.path.normpath(
        resolve_source_path(rec["source_path"], MUD_ROOT)) if rec.get("source_path") else None
    ev = {
        "id": rec["id"],
        "zone": rec["zone"],
        "object": rec["object"],
        "name": name,
        "source_path": rec.get("source_path"),
        "occurrences": [],
        "variants_tried": name_variants(name),
        "inherit_chain": [],
        "corpus_candidates": [],
        "verdict": None,
        "reason": None,
        "resolved_from": None,
        "body": None,
    }

    text = read_text(sp, cache) if sp else None
    if text is None:
        ev["verdict"] = "noop_missing_source"
        ev["reason"] = "source file does not exist (test fixture removed)"
        return ev

    ev["occurrences"] = collect_occurrences(text, name)
    chain = sorted(inherit_chain(sp, cache))
    ev["inherit_chain"] = chain

    # 1. own file, exact then variants
    body = find_function_body(text, name)
    if body:
        ev.update(verdict="recovered_same_file", resolved_from=name, body=body)
        return ev
    for v in ev["variants_tried"]:
        body = find_function_body(text, v)
        if body:
            ev.update(verdict="recovered_variant_same_file", resolved_from=v, body=body)
            return ev

    # 2. inherit chain, exact then variants
    for anc in chain:
        atext = read_text(anc, cache)
        if not atext:
            continue
        body = find_function_body(atext, name)
        if body:
            ev.update(verdict="recovered_inherit", resolved_from=name, resolved_in=anc, body=body)
            return ev
        for v in ev["variants_tried"]:
            body = find_function_body(atext, v)
            if body:
                ev.update(verdict="recovered_variant_inherit", resolved_from=v,
                          resolved_in=anc, body=body)
                return ev

    # 3. anywhere in the corpus (exact + variants) - not attributable
    cands = []
    for n in [name] + ev["variants_tried"]:
        for p in corpus_hits.get(n, []):
            if p != sp:
                cands.append({"name": n, "source_path": p})
    ev["corpus_candidates"] = cands

    kinds = [o["kind"] for o in ev["occurrences"]]
    if "comment" in kinds:
        ev["verdict"] = "noop_commented_out"
        ev["reason"] = "the only definition in this file is inside a comment"
        if cands:
            ev["reason"] += " (a same-named body exists in a different object: %s)" % (
                cands[0]["source_path"])
    elif cands:
        ev["verdict"] = "noop_other_object"
        ev["reason"] = ("definition exists only in a different object "
                        "(%s); not attributable via inherit chain" % cands[0]["source_path"])
    elif kinds and all(k == "declaration" for k in kinds):
        ev["verdict"] = "noop_prototype_only"
        ev["reason"] = "forward declaration only; no definition in the corpus"
    elif not kinds:
        ev["verdict"] = "noop_name_absent"
        ev["reason"] = "name does not occur in the source file"
    else:
        ev["verdict"] = "noop_unresolved"
        ev["reason"] = "call sites only; definition not found in corpus"
    return ev


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=DEFAULT_MANIFEST)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--resolved", default=DEFAULT_RESOLVED)
    args = ap.parse_args()

    with open(args.manifest, encoding="utf-8") as fh:
        manifest = json.load(fh)

    targets = [r for r in manifest["records"]
               if r["kind"] == "function" and r.get("body_status") == "not-found"]
    names = sorted({r["name"] for r in targets})
    print("not-found function records:", len(targets))
    print("distinct names             :", len(names))
    print("scanning corpus for variants ...")
    hits = scan_corpus(names)

    cache = {}
    events = [resolve_record(r, hits, cache) for r in targets]

    resolved = 0
    for rec, ev in zip(targets, events):
        if ev["verdict"].startswith("recovered"):
            rec["body"] = ev["body"]
            rec["body_status"] = "recovered-from-variant"
            rec["resolved_from"] = ev["resolved_from"]
            rec["defined_in"] = ev.get("resolved_in") or rec.get("source_path")
            resolved += 1

    verdicts = collections.Counter(e["verdict"] for e in events)
    report = {
        "generated_from": args.manifest,
        "not_found_total": len(targets),
        "distinct_names": len(names),
        "resolved_total": resolved,
        "verdicts": dict(sorted(verdicts.items())),
        "corpus_definitions": {k: v for k, v in sorted(hits.items()) if v},
        "records": sorted(events, key=lambda e: e["id"]),
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=1)
    with open(args.resolved, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1)

    print("-" * 60)
    for k, v in sorted(verdicts.items()):
        print("  %-28s %3d" % (k, v))
    print("-" * 60)
    print("resolved:", resolved)
    print("wrote", args.out)
    print("wrote", args.resolved)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit regression for the lpc_converter path-classification helpers.

These lock the three fixes made after the cross-zone rewiring:

  A-1  "<path>" + random(n)   -> the literal path plus every random(n) candidate,
         instead of being dropped because it contains a parenthesis.
         `"d/shaolin/obj/fojing1" + random(2)` names fojing10 / fojing11,
         because LPC concatenates str(random(2)) onto the string.
  A-2  "subdir/room"           -> same-zone reference (take the basename), instead
         of being rejected as an "unrecognised relative path".
  A-3  "d/<zone>/room"         -> cross-zone reference even without the leading
         slash (a known data bug in tiezhang/hunanroad1.c).

Run:
  python scripts/test_lpc_path_rules.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import lpc_converter as C  # noqa: E402


FAILURES = []


def check(label, got, want):
    if got != want:
        FAILURES.append("%s\n     got  %r\n     want %r" % (label, got, want))
        print("  FAIL  %s" % label)
    else:
        print("  ok    %s" % label)


# ---------------------------------------------------------------- A-1
print("A-1  \"<path>\" + random(n)")

for src, want_cands in [
    ('"/d/shaolin/obj/fojing1" + random(2)',
     ["/d/shaolin/obj/fojing10", "/d/shaolin/obj/fojing11"]),
    ('"d/shaolin/obj/fojing2"+random(2)',
     ["d/shaolin/obj/fojing20", "d/shaolin/obj/fojing21"]),
    ('__DIR__"npc/x" + random(3)',
     ['__DIR__npc/x0', '__DIR__npc/x1', '__DIR__npc/x2']),
    ('"/d/a" + random(1)', ["/d/a0"]),
]:
    literal, cands = C._split_runtime_suffix(src)
    check("cands(%s)" % src, cands, want_cands)
    check("not dynamic(%s)" % src, C._is_dynamic_expr(src), False)

# an operand that names no determinate file must still be rejected
for src in [
    '"/clone/book/" + books[random(sizeof(books))]',
    'CLASS_D("shaolin") + books[1]',
]:
    check("dynamic(%s)" % src, C._is_dynamic_expr(src), True)

# CLASS_D(...) + "/literal" is the common room-object idiom: the class prefix
# only supplies the directory, so the right-hand literal decides the id.
literal, cands = C._split_runtime_suffix('CLASS_D("shaolin") + "/dao-yi"')
check("CLASS_D literal", literal, "/dao-yi")
check("CLASS_D not dynamic", C._is_dynamic_expr('CLASS_D("shaolin") + "/dao-yi"'), False)

# a plain path is untouched
literal, cands = C._split_runtime_suffix('"/d/city/guangchang"')
check("plain path literal", literal, '"/d/city/guangchang"')
check("plain path no cands", cands, None)

# random(0) names nothing
check("random(0)", C._random_candidates("/d/a", "random(0)"), None)


# ---------------------------------------------------------------- A-2
print("\nA-2  same-zone subdirectory references")

for zone, src, want in [
    ("city", '__DIR__ "qiyuan/qiyuan1"', "qiyuan1"),
    ("room", '__DIR__"panlong/dayuan"', "dayuan"),
    ("room", '__DIR__"dule/xiaoyuan"', "xiaoyuan"),
    ("room", '__DIR__"caihong/xiaoyuan"', "xiaoyuan"),
    ("death", "heisenlin/entry", "entry"),
    ("city", '"qiyuan/qiyuan1"', "qiyuan1"),
]:
    kind, *rest = C._classify_exit_path(src, zone)
    check("classify(%s, %s)" % (zone, src), (kind, rest[0] if rest else None),
          ("local", want))


# ---------------------------------------------------------------- A-3
print("\nA-3  d/<zone>/... without the leading slash")

kind, *rest = C._classify_exit_path('"d/xiangyang/caodi6"', "tiezhang")
check("classify(tiezhang, d/xiangyang/caodi6)", (kind, rest[0] if rest else None),
      ("cross", "xiangyang"))

# the well-formed spelling must keep working
kind, *rest = C._classify_exit_path('"/d/shaolin/yidao"', "city")
check("classify(city, /d/shaolin/yidao)", (kind, rest[0] if rest else None),
      ("cross", "shaolin"))

# same-zone absolute path stays local
kind, *rest = C._classify_exit_path('"/d/city/guangchang"', "city")
check("classify(city, /d/city/guangchang)", (kind, rest[0] if rest else None),
      ("local", "guangchang"))


# ---------------------------------------------------------------- regression
print("\nRegression: previously-correct behaviour must be unchanged")

# cross-zone
kind, *rest = C._classify_exit_path('"/d/huanghe/caodi1"', "city")
check("cross-zone", (kind, rest[0], rest[1]), ("cross", "huanghe", "caodi1"))

# outside d/ stays unlinkable
for src in ['"/clone/shop/yangzhou_shop"', '"/b/tulong/haigang"', '"../room_above"']:
    kind, *rest = C._classify_exit_path(src, "city")
    check("unlinkable(%s)" % src, kind, "skip")

# __FILE__ names the room itself: it must resolve to a self-loop, not be dropped.
# 50 rooms / 137 exits across 11 zones rely on this (baituo/cao1.c has both
# "west" : __FILE__ and "south": __FILE__).
check("classify __FILE__", C._classify_exit_path('__FILE__', "baituo"), ("self", None))
check("resolve __FILE__ -> self",
      C._resolve_exit_target(("var", "__FILE__"), "baituo", "cao1"),
      ("rooms.cao1.id", None))
check("resolve __FILE__ without room id",
      C._resolve_exit_target(("var", "__FILE__"), "baituo", None),
      (None, "self-referential (__FILE__) with unknown room id"))

# bare name in the same zone
kind, *rest = C._classify_exit_path('"guangchang"', "city")
check("bare name", (kind, rest[0]), ("local", "guangchang"))


print("")
if FAILURES:
    print("FAILED: %d" % len(FAILURES))
    for f in FAILURES:
        print("  " + f)
    sys.exit(1)

print("all checks passed")

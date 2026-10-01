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


# ---------------------------------------------------------------- C
print("\nC  runtime-picked exits: __DIR__\"x\" + (random(n) + k)")

for src, want in [
    ('__DIR__"shulin" + (random(8) + 6)',
     ["shulin6", "shulin7", "shulin8", "shulin9",
      "shulin10", "shulin11", "shulin12", "shulin13"]),
    ('"shulin" + (random(10) + 2)',
     ["shulin2", "shulin3", "shulin4", "shulin5", "shulin6",
      "shulin7", "shulin8", "shulin9", "shulin10", "shulin11"]),
]:
    kind, *rest = C._classify_exit_path(src, "gaochang")
    check("classify(%s)" % src, (kind, rest[0]), ("random", want))

# The LPC value must survive parsing as one unit.  Before the fix
# _parse_lpc_value saw the leading __DIR__" and _parse_lpc_string kept only
# the quoted part, silently turning the exit into a reference to a room named
# `shulin` - which does not exist.
check("parse keeps whole expression",
      C._parse_lpc_value('__DIR__"shulin" + (random(8) + 6)'),
      ("var", '__DIR__"shulin" + (random(8) + 6)'))

# elias only accepts the bracket form WITHOUT spaces between elements.
check("render bracketed, no spaces",
      C._resolve_exit_target(("var", '__DIR__"shulin" + (random(2) + 6)'),
                            "gaochang", "shulin1")[0],
      "[rooms.shulin6.id,rooms.shulin7.id]")

check("plain path is still local",
      C._classify_exit_path('__DIR__"shulin"', "gaochang"),
      ("local", "shulin"))
# All three spellings of the runtime pick must resolve.  shaolin/rukou.c writes
# the bare form with no spaces and no parentheses:
#     "south" : __DIR__"wuxing"+random(5),
# An earlier pattern required both the parentheses and the `+ k` offset, so this
# one fell through and emitted `rooms.wuxing+random(5).id` into the UCL verbatim.
for src, want in [
    ('__DIR__"wuxing"+random(5)',
     ["wuxing0", "wuxing1", "wuxing2", "wuxing3", "wuxing4"]),
    ('__DIR__"wuxing" + random(5)',
     ["wuxing0", "wuxing1", "wuxing2", "wuxing3", "wuxing4"]),
    ('__DIR__"shulin" + (random(8) + 6)',
     ["shulin6", "shulin7", "shulin8", "shulin9",
      "shulin10", "shulin11", "shulin12", "shulin13"]),
]:
    kind, *rest = C._classify_exit_path(src, "shaolin")
    check("pick(%s)" % src, (kind, rest[0]), ("random", want))

# A variable concatenation is NOT a runtime pick and must not become one.
check("variable concat is not a pick",
      C._classify_exit_path('__DIR__"obj/" + weapon_file', "shaolin")[0],
      "local")

# No exit target may leak a raw runtime expression any more.
check("no leak: rukou south",
      C._resolve_exit_target(("var", '__DIR__"wuxing"+random(5)'),
                             "shaolin", "rukou")[0],
      "[rooms.wuxing0.id,rooms.wuxing1.id,rooms.wuxing2.id,"
      "rooms.wuxing3.id,rooms.wuxing4.id]")


# ---------------------------------------------------------------- D
print("\nD  exit-direction skip reasons must name the real cause")


# A valid direction is not skipped at all.
for ok in ("north", "south", "east", "west", "up", "down", "in", "out",
           "northeast", "northup", "eastdown", "go_in", "climb"):
    check("accepted(%s)" % ok, C._exit_dir_skip_reason(ok), None)

# Three distinct causes, three distinct messages - the old code claimed all of
# them were "C comment artefact", which is wrong for the last two.
check("empty (C comment stripped)",
      C._exit_dir_skip_reason(""),
      "direction became empty after stripping a C comment")
check("CJK (shaolin bagua)",
      C._exit_dir_skip_reason("乾"),
      "direction is not ASCII; elias's Word token is ASCII-only, "
      "so this key cannot be lexed")
check("digit (huashan hole6)",
      C._exit_dir_skip_reason("hole6"),
      "direction contains a digit; elias lexes Digit as a separate "
      "token, so the assignment cannot close")
check("punctuation",
      C._exit_dir_skip_reason("a-b"),
      "direction is not a bare identifier")

# No message may claim "C comment artefact" for a non-empty direction.
for d in ("乾", "hole6", "a-b"):
    reason = C._exit_dir_skip_reason(d)
    check("no false C-comment claim(%s)" % d, "C comment" in reason, False)


# ---------------------------------------------------------------- E
# A /d/<dir>/ exit whose LPC directory was never converted.  One city square
# links out to another town under that town's name:
#     "liuxi" : "/d/minimal_world/guangchang",
# but that directory has no data/world zone, so the literal reference resolves to
# nothing and the loader drops the exit.  LPC names the exit after the place it
# leads to, and "liuxi" is the installed zone id of 柳溪镇, so the direction is the
# recoverable signal.  Room-name matching is not: "guangchang" is a town square in
# a dozen zones.
print("\nE  unconverted cross-zone directory recovered from the direction")

C._INSTALLED_ZONE_IDS = {"city", "liuxi", "shaolin", "xiangyang", "tiezhang"}

check("direction names the installed zone",
      C._classify_exit_path("/d/minimal_world/guangchang", "city", "liuxi"),
      ("cross", "liuxi", "guangchang"))
check("installed directory is untouched",
      C._classify_exit_path("/d/shaolin/yidao", "city", "in"),
      ("cross", "shaolin", "yidao"))
check("no direction and no installed zone -> dropped",
      C._classify_exit_path("/d/minimal_world/guangchang", "city"),
      ("skip", "no installed zone 'minimal_world' for this room"))
check("direction that is not a zone does not rescue it",
      C._classify_exit_path("/d/minimal_world/guangchang", "city", "east"),
      ("skip", "no installed zone 'minimal_world' for this room"))
check("room name alone must not pick a zone",
      C._classify_exit_path("/d/minimal_world/guangchang", "shaolin", "liuxi"),
      ("cross", "liuxi", "guangchang"))
check("ordinary slashless form still resolves",
      C._classify_exit_path("d/xiangyang/caodi6", "tiezhang", "east"),
      ("cross", "xiangyang", "caodi6"))
check("installed-zone scan", "liuxi" in C.note_installed_zones("data/world"), True)


print("")
if FAILURES:
    print("FAILED: %d" % len(FAILURES))
    for f in FAILURES:
        print("  " + f)
    sys.exit(1)

print("all checks passed")

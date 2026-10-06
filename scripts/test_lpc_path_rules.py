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
#
# CRITICAL: the direction only ever *overrides* the zone, it never gates it.  When
# this was written as a gate ("if the target zone is not installed, skip"), the
# output depended on whatever happened to be in --output: converting into a fresh
# or partial directory dropped EVERY cross-zone exit.  city lost -north-> shaolin,
# -in-> gaibang and -liuxi-> liuxi, replaced by `# skipped exit ...` comments.  So
# the cases below pin both halves: the override fires when the direction names an
# installed zone, and a plain cross-zone reference survives with no knowledge at all.
print("\nE  unconverted cross-zone directory recovered from the direction")

C._INSTALLED_ZONE_IDS = {"city", "liuxi", "shaolin", "xiangyang", "tiezhang"}

check("direction names the installed zone",
      C._classify_exit_path("/d/minimal_world/guangchang", "city", "liuxi"),
      ("cross", "liuxi", "guangchang"))
check("installed directory is untouched",
      C._classify_exit_path("/d/shaolin/yidao", "city", "in"),
      ("cross", "shaolin", "yidao"))
check("room name alone must not pick a zone",
      C._classify_exit_path("/d/minimal_world/guangchang", "shaolin", "liuxi"),
      ("cross", "liuxi", "guangchang"))
check("ordinary slashless form still resolves",
      C._classify_exit_path("d/xiangyang/caodi6", "tiezhang", "east"),
      ("cross", "xiangyang", "caodi6"))

# Nothing is known about the output directory (fresh/partial --output): an ordinary
# cross-zone reference must still be emitted rather than skipped.
_saved = C._INSTALLED_ZONE_IDS
try:
    C._INSTALLED_ZONE_IDS = set()
    check("empty installed set keeps a plain cross-zone exit",
          C._classify_exit_path("/d/shaolin/yidao", "city", "north"),
          ("cross", "shaolin", "yidao"))
    check("empty installed set keeps the in-> gaibang style reference",
          C._classify_exit_path("/d/gaibang/inhole", "city", "in"),
          ("cross", "gaibang", "inhole"))
    check("empty installed set falls back to the literal zone",
          C._classify_exit_path("/d/minimal_world/guangchang", "city", "liuxi"),
          ("cross", "minimal_world", "guangchang"))
finally:
    C._INSTALLED_ZONE_IDS = _saved

check("installed-zone scan", "liuxi" in C.note_installed_zones("data/world"), True)


# ---------------------------------------------------------------- F
# `set("exits", ...)` written outside create().  Measured over the 4287 corpus
# files that contain one, only 4 put it elsewhere and just 2 of those are rooms:
#     death/god1.c      void reset()
#     death/lunhuisi.c  void recreate()   (its create() deliberately seals the room)
#     taohua/obj/bagua.c, taohua/obj/xiang.c   items, so no room_exits is emitted
# create() stays authoritative; the fallback only applies when it declares no exits.
print("\nF  set(\"exits\") outside create()")

_IN_RESET = """
inherit ROOM;
void create()
{
    set("short", HIY"天堂"NOR);
    set("long", @LONG这里就是天堂。LONG NOR );
    setup();
}
void reset()
{
    ::reset();
    set("exits", ([ /* sizeof() == 2 */
        "up" : __DIR__"god2",
        "down": "/d/city/wumiao",
    ]));
}
"""

_SEALED_CREATE = """
inherit ROOM;
void create()
{
    set("short", HIB "轮回司" NOR);
    setup();
}
void recreate()
{
    set("exits", ([ "out" : __DIR__ "lunhuisi_road1", ]));
}
"""

_IN_CREATE = """
inherit ROOM;
void create()
{
    set("short", "北路" NOR);
    set("exits", ([ "south" : __DIR__"street", ]));
}
void reset()
{
    set("exits", ([ "north" : "/d/city/beimen", ]));
}
"""

_NO_EXITS_ANYWHERE = """
inherit ROOM;
void create()
{
    set("short", "空房" NOR);
    setup();
}
"""


def _parse(src):
    return C._parse_lpc(src.encode("utf-8"), "t.c", ".")


def _exits(src):
    ast = _parse(src)
    return ast.create_fn.get("sets", {}).get("exits")


check("exits in reset() are recovered",
      _exits(_IN_RESET),
      ("mapping", [(("string", "up"), ("string", "god2")),
                   (("string", "down"), ("string", "/d/city/wumiao"))]))
check("a recovered exit still resolves cross-zone",
      C._resolve_exit_target(("string", "/d/city/wumiao"), "death"),
      ("city.rooms.wumiao.id", None))
check("create() wins when both declare exits",
      _exits(_IN_CREATE),
      ("mapping", [(("string", "south"), ("string", "street"))]))
check("no exits anywhere stays absent", _exits(_NO_EXITS_ANYWHERE), None)
check("sealed create() picks up recreate()'s exits",
      _exits(_SEALED_CREATE),
      ("mapping", [(("string", "out"), ("string", "lunhuisi_road1"))]))


# ---------------------------------------------------------------- G
# `/* ... */` inside create() must not leak into parsed values.
#
# create_body is cut out of the RAW source, so before this only `//` line comments
# were stripped from it.  The corpus writes an object count as a block comment
# immediately before the list:
#     set("objects", ([ /* sizeof() == 5 */ __DIR__"npc/fujiang" : 1, ...
# so the path arrived as '/* sizeof() == 5 */\n  __DIR__"npc/fujiang"', had no
# determinate object id, and the whole entry was dropped.  That silently emptied
# six changan barracks (bingying1..6 lost their 府兵 and 4 卫兵 each), plus
# dangpu's shopkeeper and kezhan's page -- 19 objects in 6 zones.
print("\nG  block comments inside create() are stripped")


_BLOCK_COMMENT = """
inherit ROOM;
void create()
{
    set("short", "兵营" NOR);
    set("objects", ([ /* sizeof() == 5 */
                     __DIR__"npc/fujiang" : 1,
                     __DIR__"npc/guanbing" : 4,
    ]));
    setup();
}
"""


def _objects(src):
    ast = _parse(src)
    merged = C._merge_inherit_chain(ast)
    return merged.create_fn.get("sets", {}).get("objects")


check("object path is recovered despite the leading block comment",
      _objects(_BLOCK_COMMENT),
      ("mapping", [(("string", "npc/fujiang"), ("int", 1)),
                   (("string", "npc/guanbing"), ("int", 4))]))

_uct = _objects(_BLOCK_COMMENT)
check("no '/*' survives into the parsed path",
      "/*" in repr(_uct),
      False)


# ---------------------------------------------------------------- H
# "Is this set("objects") entry a person?" used to be answered by
# `"npc" in path`.  That sees the /d/<zone>/npc/*.c spelling and nothing else,
# so 431 references to real people were emitted as `items.<id>` and then dropped
# by the loader -- those rooms were empty at runtime and every valid_leave gate
# hanging off them never fired.  The verdict now comes from the LPC inherit
# chain, one hop up into mud/inherit/char/ where every base class says
# `inherit NPC;`.
print("\nH  person-vs-thing resolved by the inherit chain, not the path")

import tempfile  # noqa: E402

import lpc_paths as LP  # noqa: E402


def _tmp_lpc(body):
    fd, path = tempfile.mkstemp(suffix='.c')
    with os.fdopen(fd, 'wb') as f:
        f.write(body.encode('utf-8'))
    LP._type_cache.clear()
    return path


# A bare marker names no type of its own; the type is in the base class.
_QUARRY_ITEM = _tmp_lpc("""
inherit ITEM;
void create() { set("short", "石块"); }
""")
try:
    check("inherit ITEM stays an item", LP.resolve_type(_QUARRY_ITEM), 'item')
finally:
    os.unlink(_QUARRY_ITEM)

# The real base classes are the ground truth for the walk.
for name, want in [('quarry', 'npc'), ('worm', 'npc'), ('snake', 'npc'),
                   ('npc', 'npc')]:
    base = LP.find_inherit_file(name)
    if base is None:
        print("  skip  mud/inherit/char/%s.c (LPC corpus not present)" % name)
        continue
    check("base class %s" % name, LP.resolve_type(base), want)

# object_file/2 has to understand all three spellings, including the .c that
# every one of them omits.
check("object_file CLASS_D",
      os.path.basename(LP.object_file('CLASS_D("hu") + "/pingsi"', '/x')),
      'pingsi.c')
check("object_file __DIR__",
      os.path.basename(LP.object_file('__DIR__"npc/yahuan"', '/x')),
      'yahuan.c')
check("object_file absolute",
      os.path.basename(LP.object_file('"/d/city/npc/li"', '/x')),
      'li.c')
check("object_file keeps .c if written",
      os.path.basename(LP.object_file('"/d/city/npc/li.c"', '/x')),
      'li.c')
check("object_file rejects an expression",
      LP.object_file('CLASS_D("shaolin") + books[1]', '/x'), None)

# _object_is_npc/3 must not trust the spelling: both directions have to move.
_tmp = tempfile.mkdtemp()
try:
    for label, body, entry, want in [
        # an NPC whose path never says "npc" -- the case the old code missed,
        # and 431 of them: /kungfu/class/<sect>/*.c and /clone/{quarry,worm,
        # beast}/*.c are the bulk, /d/hangzhou/honghua/huo is the odd one out
        ('person without "npc" in the path', 'inherit NPC;\n',
         'obj/_person', True),
        # and the other direction: nothing may turn into a person by accident
        ('item without "npc" in the path', 'inherit ITEM;\n',
         'obj/_thing', False),
    ]:
        obj = os.path.join(_tmp, entry + '.c')
        os.makedirs(os.path.dirname(obj), exist_ok=True)
        with open(obj, 'w') as f:
            f.write(body)
        check(label,
              C._object_is_npc('__DIR__"%s"' % entry, entry, _tmp), want)

    # A file under an npc/ directory is taken as a person by _npc_subdir/1,
    # which predates this change.  Over the corpus that never lies: all 1155
    # files under d/<zone>/npc/ classify as npc, so the heuristic is kept and
    # only the checks above are new.
    npc_dir = os.path.join(_tmp, 'npc')
    os.makedirs(npc_dir)
    with open(os.path.join(npc_dir, 'y'), 'w') as f:
        f.write('void create() { set("short", "x"); }\n')
    check("npc/ directory still wins", LP.resolve_type(
        os.path.join(npc_dir, 'y')), 'npc')
finally:
    for dirpath, dirs, names in os.walk(_tmp, topdown=False):
        for n in names:
            os.unlink(os.path.join(dirpath, n))
        for d in dirs:
            os.rmdir(os.path.join(dirpath, d))
    os.rmdir(_tmp)

# With no source directory to resolve against, the old spelling guess stands in
# rather than silently dropping the reference to the floor.
check("fallback without src_dir",
      C._object_is_npc('__DIR__"npc/yahuan"', 'npc/yahuan', None), True)
check("fallback says no for a non-npc path",
      C._object_is_npc('__DIR__"obj/sword"', 'obj/sword', None), False)


print("")
if FAILURES:
    print("FAILED: %d" % len(FAILURES))
    for f in FAILURES:
        print("  " + f)
    sys.exit(1)

print("all checks passed")

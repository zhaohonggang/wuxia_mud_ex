#!/usr/bin/env python3
"""World-wide room reachability report for data/world.

`check_room_coords.py` proves every room of ONE zone is reachable from that zone's
pinned centre.  That says nothing about whether a zone can be reached from the rest
of the world at all, which is the question this script answers: BFS the whole world
graph from a start room and list everything that cannot be got to.

Exit targets in UCL come in four shapes (measured over the whole library):

    rooms.<id>.id              same zone
    <zone>.rooms.<id>.id      cross zone
    [rooms.a.id,rooms.b.id]   a runtime pick - the loader chooses ONE per room load,
                              so every candidate is listed as an edge (see below)
    rooms.<id with - .id      room ids may contain '-'

A `[list]` target is genuinely ambiguous: `gaochang:shulin1` loads as shulin2..shulin9
depending on a random number.  Treating the union as reachable is the optimistic
reading, so a room reported unreachable here is unreachable under *every* draw; a
room that only sometimes fails to be reached cannot show up in this report.

For each unreachable room the corresponding LPC source is located under
`mud/d/<zone>/` and its `set("exits", ...)` printed, because the interesting
question is not "is it reachable" but "did the source ever wire it up".

Usage:
    python scripts/world_reachability.py [--start city:guangchang] [--world DIR]
                                         [--lpc DIR] [--show-sources]
                                         [--zones] [--json OUT]
"""
import argparse
import collections
import json
import pathlib
import re
import sys

EXITS_BLOCK_RE = re.compile(r'^\s*room_exits\s+"([\w-]+)"\s*\{', re.MULTILINE)
ROOM_BLOCK_RE = re.compile(r'^\s*rooms\s+"([\w-]+)"\s*\{', re.MULTILINE)
ZONES_BLOCK_RE = re.compile(r'^\s*zones\s+"([\w-]+)"\s*\{', re.MULTILINE)
ROW_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", re.MULTILINE)

LOCAL_RE = re.compile(r"^rooms\.([\w-]+)\.id$")
# Zone ids may contain '-' (kissa-jarvi).  Loader.dereference/3 just splits on
# "." and looks the first segment up, so the parser has to accept them too.
CROSS_RE = re.compile(r"^([a-z][a-z0-9_-]*)\.rooms\.([\w-]+)\.id$")
LIST_RE = re.compile(r"^\[(.*)\]$")
QUOTED_RE = re.compile(r'^"(.*)"$')

DEFAULT_WORLD = "data/world"
DEFAULT_LPC = r"C:\files\git\mud\d"

# Zones whose UCL was not produced from mud/d/<zone>.  They are hand-authored or come
# from other corpora, so "unreachable" cannot be blamed on the LPC conversion.
NON_CORPUS_ZONES = {
    "test", "global", "kissa-jarvi", "sammatti", "signature", "lepakko-luola",
    "liuxi",
}

# Zones the corpus itself designs as sealed off (docs/mud-d-zone-connectivity.zh-CN.md
# §4.4 "6 孤立区").  taohua is a __FILE__ self-referential maze; special has no
# set("exits") at all; huanggong is an inner palace; sky/shenlong/tangmen are simply
# not wired into the main map (tangmen has no rooms, so it never appears here).
DESIGN_ISOLATED_ZONES = {"taohua", "special", "huanggong", "sky", "shenlong"}


def block_at(text, open_index):
    depth = 0
    for j in range(open_index, len(text)):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[open_index:j]
    return text[open_index:]


def resolve(value, zone_id):
    """Return the list of room ids this exit value can lead to."""
    v = value.strip()
    # Three hand-authored zones (liuxi, sammatti, kissa-jarvi) quote a handful of
    # cross-zone references:  south = "kissa-jarvi.rooms.gates.id".  Elias parses
    # that as a plain string and Loader.dereference/3 still resolves it, so the
    # quoting must not hide the edge here or those rooms look unreachable.
    q = QUOTED_RE.match(v)
    if q:
        v = q.group(1).strip()
    m = LOCAL_RE.match(v)
    if m:
        return ["%s:%s" % (zone_id, m.group(1))]
    m = CROSS_RE.match(v)
    if m:
        return ["%s:%s" % (m.group(1), m.group(2))]
    m = LIST_RE.match(v)
    if m:
        out = []
        for part in m.group(1).split(","):
            part = part.strip()
            if part:
                out.extend(resolve(part, zone_id))
        return out
    return []


def parse_zone(path):
    """Return (zone_id, {room_id: [target_room_id, ...]})."""
    text = path.read_text(encoding="utf-8", errors="replace")
    zm = ZONES_BLOCK_RE.search(text)
    zone_id = zm.group(1) if zm else path.stem

    rooms = []
    for m in ROOM_BLOCK_RE.finditer(text):
        rooms.append(m.group(1))

    exits = {}
    for m in EXITS_BLOCK_RE.finditer(text):
        rid = m.group(1)
        body = block_at(text, m.end() - 1)
        targets = []
        for r in ROW_RE.finditer(body):
            if r.group(1) == "room_id":
                continue
            targets.extend(resolve(r.group(2), zone_id))
        exits[rid] = targets

    return zone_id, rooms, exits


def lpc_source(lpc_root, zone_id, room_id):
    """Locate mud/d/<zone>/<room>.c.  The converter maps '-' in file names to '_'."""
    zdir = pathlib.Path(lpc_root) / zone_id
    if not zdir.is_dir():
        return None
    for cand in (room_id, room_id.replace("_", "-"), room_id.replace("-", "_")):
        for sub in ("", "room"):
            p = zdir / sub / (cand + ".c")
            if p.is_file():
                return p
    hits = sorted(zdir.rglob(room_id.replace("-", "_") + ".c"))
    return hits[0] if hits else None


def source_exits(src):
    if src is None:
        return ""
    text = src.read_text(encoding="utf-8", errors="replace")
    outs = []
    for m in re.finditer(r'set\(\s*"exits"\s*,.*?\]\s*\)', text, re.DOTALL):
        body = m.group(0)
        for line in body.splitlines():
            s = line.strip()
            if ":" in s and "set(" not in s:
                outs.append(s)
    return " | ".join(outs) if outs else "(no set(\"exits\") in source)"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", default="city:guangchang")
    ap.add_argument("--world", default=DEFAULT_WORLD)
    ap.add_argument("--lpc", default=DEFAULT_LPC)
    ap.add_argument("--show-sources", action="store_true",
                    help="print each unreachable room's LPC set(\"exits\")")
    ap.add_argument("--zones", action="store_true",
                    help="print the per-zone table as well as the totals")
    ap.add_argument("--json", help="also write the full result as JSON")
    args = ap.parse_args(argv)

    world = pathlib.Path(args.world)
    if not world.is_dir():
        print("no such world dir: %s" % world, file=sys.stderr)
        return 2

    zone_of = {}
    rooms_of = collections.defaultdict(list)
    adj = {}

    for path in sorted(world.glob("*.ucl")):
        zone_id, rooms, exits = parse_zone(path)
        if zone_id in rooms_of:
            print("warning: zone id %r declared by both %s and %s"
                  % (zone_id, path.name, zone_of.get(zone_id)), file=sys.stderr)
        zone_of[zone_id] = path.name
        for rid in rooms:
            rooms_of[zone_id].append(rid)
            adj["%s:%s" % (zone_id, rid)] = exits.get(rid, [])

    all_rooms = set(adj)
    start = args.start
    if start not in all_rooms:
        print("start room %r does not exist" % start, file=sys.stderr)
        return 2

    # Only follow edges that land on a room which exists.  58 exit rows name a room
    # that is not in the world (the registered dangling exits); the loader drops
    # those in parse_exits' `not is_nil` filter, so counting them would inflate the
    # reachable count.  Verified against Loader.load(): 4115/4455 either way.
    seen = {start}
    queue = collections.deque([start])
    while queue:
        cur = queue.popleft()
        for nxt in adj.get(cur, ()):
            if nxt in all_rooms and nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)

    unreachable = sorted(all_rooms - seen)

    # Group by zone, remembering whether the whole zone or only part of it is cut off.
    by_zone = collections.OrderedDict()
    for rid in unreachable:
        z, r = rid.split(":", 1)
        by_zone.setdefault(z, []).append(r)

    totally_cut = []
    partly = []
    for z, rs in sorted(by_zone.items()):
        if len(rs) == len(rooms_of[z]):
            totally_cut.append(z)
        else:
            partly.append(z)

    total = len(all_rooms)
    pct = 100.0 * len(seen) / total if total else 0.0
    print("reachable from %s: %d/%d rooms (%.1f%%)"
          % (start, len(seen), total, pct))
    print("unreachable: %d room(s) in %d zone(s)"
          % (len(unreachable), len(by_zone)))

    buckets = collections.OrderedDict()
    buckets["design-isolated zone"] = [z for z in totally_cut
                                       if z in DESIGN_ISOLATED_ZONES]
    buckets["non-corpus zone"] = [z for z in totally_cut
                                  if z not in DESIGN_ISOLATED_ZONES
                                  and z in NON_CORPUS_ZONES]
    buckets["whole zone cut off, unclassified"] = [
        z for z in totally_cut
        if z not in DESIGN_ISOLATED_ZONES and z not in NON_CORPUS_ZONES]
    buckets["zone reachable but has unreachable rooms"] = partly

    for label, zs in buckets.items():
        print()
        print("== %s: %d zone(s) ==" % (label, len(zs)))
        for z in zs:
            print("   %-12s %4d/%4d rooms unreachable%s"
                  % (z, len(by_zone[z]), len(rooms_of[z]),
                     "   (whole zone)" if z in totally_cut else ""))

    if args.zones:
        print()
        print("== per-zone reachability ==")
        print("%-14s %6s %6s %8s  %s" % ("zone", "total", "reach", "pct", "note"))
        for z in sorted(rooms_of):
            n = len(rooms_of[z])
            r = n - len(by_zone.get(z, ()))
            note = []
            if z in DESIGN_ISOLATED_ZONES:
                note.append("design-isolated")
            if z in NON_CORPUS_ZONES:
                note.append("non-corpus")
            if z in totally_cut:
                note.append("CUT OFF")
            elif z in partly:
                note.append("partly unreachable")
            print("%-14s %6d %6d %7.1f%%  %s"
                  % (z, n, r, 100.0 * r / n if n else 0.0, ", ".join(note)))

    if args.show_sources:
        print()
        print("== unreachable rooms and their LPC source exits ==")
        for z in sorted(by_zone):
            print()
            print("-- %s (%d) --" % (z, len(by_zone[z])))
            for r in sorted(by_zone[z]):
                src = lpc_source(args.lpc, z, r)
                outs = adj.get("%s:%s" % (z, r), [])
                print("  %-20s ucl-exits=%-2d src=%s"
                      % (r, len(outs), src if src else "(no .c found)"))
                print("      %s" % source_exits(src))

    if args.json:
        payload = {
            "start": start,
            "total_rooms": total,
            "reachable": len(seen),
            "unreachable": unreachable,
            "by_zone": by_zone,
            "totally_cut_zones": totally_cut,
            "partly_unreachable_zones": partly,
        }
        pathlib.Path(args.json).write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8")
        print()
        print("wrote %s" % args.json)

    return 0


if __name__ == "__main__":
    sys.exit(main())
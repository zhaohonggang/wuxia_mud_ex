"""Structural/coordinate checks for a converted zone UCL file.

`scripts/validate_ucl.py` is a *text-level* validator: it answers "can Elias parse
this, and will the loader survive it".  This script answers the separate
question the SOP's Step 4 asks: "is the geometry sane" —

  1. every room has x/y/z
  2. all rooms are reachable, following exit directions, from the room at the
     origin (the zone centre the coords script pins to (0,0,0))
  3. every room_exits block belongs to a room that exists

Plus two reported *warnings*, which are inherent to the source LPC graph and are
therefore not failures:

  W1  two rooms share a coordinate.  A diamond in the exit graph (A-north-B-east-D
      together with A-east-C-north-D) makes both paths compute the same delta, so
      two rooms land on one cell.  This is NOT fixed by displacement: moving one
      room breaks the direction/coord agreement of every exit that reached it and
      cascades through its subtree (measured: 13.0% -> 41.2% direction violations
      across the 13 zones).  See the assign_room_coords.py docstring.
  W2  an exit's direction disagrees with the two coordinates it joins.  Caused by
      pre-existing non-zero "anchor" coordinates and by orphan layers being
      pinned at (0,0,z).  Also a property of the source data.

It is deliberately dependency-free (stdlib only) so it runs on the host, same as
validate_ucl.py.  Exit codes: 0 no problems (warnings may be printed) /
1 problems found / 2 bad args.
"""

import collections
import pathlib
import re
import sys

ROOM_BLOCK_RE = re.compile(r'^\s*rooms\s+"(\w+)"\s*\{', re.MULTILINE)
EXITS_BLOCK_RE = re.compile(r'^\s*room_exits\s+"(\w+)"\s*\{', re.MULTILINE)
INT_RE = r"^\s*%s\s*=\s*(-?\d+)\s*$"
EXIT_ROW_RE = re.compile(r"^\s*(\w+)\s*=\s*rooms\.(\w+)\.id", re.MULTILINE)

# Must stay in sync with assign_room_coords.DIRS.
DIRS = {
    "north": (0, 1, 0), "south": (0, -1, 0), "east": (1, 0, 0),
    "west": (-1, 0, 0), "northeast": (1, 1, 0), "northwest": (-1, 1, 0),
    "southeast": (1, -1, 0), "southwest": (-1, -1, 0),
    "northup": (0, 1, 1), "southup": (0, -1, 1), "eastup": (1, 0, 1),
    "westup": (-1, 0, 1), "up": (0, 0, 1), "down": (0, 0, -1),
    "northdown": (0, 1, -1), "southdown": (0, -1, -1), "eastdown": (1, 0, -1),
    "westdown": (-1, 0, -1),
    "enter": (0, 0, 0), "out": (0, 0, 0), "in": (0, 0, 0), "go_in": (0, 0, 0),
    "climb": (0, 0, 1),
}


def _block_at(text, open_index):
    """Return the body between the brace at `open_index` and its match."""
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


def parse_rooms(text):
    rooms = {}
    for m in ROOM_BLOCK_RE.finditer(text):
        rid = m.group(1)
        body = _block_at(text, m.end() - 1)
        xyz = {}
        for axis in ("x", "y", "z"):
            mm = re.search(INT_RE % axis, body, re.MULTILINE)
            xyz[axis] = int(mm.group(1)) if mm else None
        rooms[rid] = xyz
    return rooms


def parse_exits(text):
    exits = {}
    for m in EXITS_BLOCK_RE.finditer(text):
        rid = m.group(1)
        body = _block_at(text, m.end() - 1)
        ex = {}
        for em in EXIT_ROW_RE.finditer(body):
            ex[em.group(1)] = em.group(2)
        exits[rid] = ex
    return exits


def check(path):
    text = pathlib.Path(path).read_text(encoding="utf-8")
    rooms = parse_rooms(text)
    exits = parse_exits(text)
    problems = []
    warnings = []

    if not rooms:
        return ["no rooms found"], warnings, rooms, exits

    # 1. every room has all three coordinates
    for rid, xyz in sorted(rooms.items()):
        if None in (xyz["x"], xyz["y"], xyz["z"]):
            problems.append("room %s is missing a coordinate: %s" % (rid, xyz))

    # 2. reachability from the origin room (the centre the coords script pins)
    origin = [rid for rid, xyz in rooms.items()
              if (xyz["x"], xyz["y"], xyz["z"]) == (0, 0, 0)]
    if not origin:
        problems.append("no room sits at the origin (0,0,0); cannot verify reachability")
    else:
        centre = origin[0]
        seen = {centre}
        queue = collections.deque([centre])
        while queue:
            cur = queue.popleft()
            for _dir, target in exits.get(cur, {}).items():
                if target in rooms and target not in seen:
                    seen.add(target)
                    queue.append(target)
        unreachable = sorted(set(rooms) - seen)
        if unreachable:
            problems.append("%d room(s) unreachable from centre %s: %s"
                            % (len(unreachable), centre, unreachable))

    # 3. no orphan room_exits blocks
    for rid in sorted(set(exits) - set(rooms)):
        problems.append("room_exits %s has no matching rooms block" % rid)

    # W1. stacked rooms (inherent to diamonds in the LPC exit graph)
    by_coord = collections.defaultdict(list)
    for rid, xyz in rooms.items():
        if None in (xyz["x"], xyz["y"], xyz["z"]):
            continue
        by_coord[(xyz["x"], xyz["y"], xyz["z"])].append(rid)
    stacked = {c: ids for c, ids in by_coord.items() if len(ids) > 1}
    for coord, ids in sorted(stacked.items()):
        warnings.append("coordinate %s shared by %d rooms: %s"
                        % (coord, len(ids), sorted(ids)))

    # W2. exits whose direction disagrees with the coordinates they join
    axes = ("x", "y", "z")
    mismatched = []
    for src, ex in sorted(exits.items()):
        if src not in rooms or None in rooms[src].values():
            continue
        for dir_, tgt in sorted(ex.items()):
            if dir_ not in DIRS or tgt not in rooms:
                continue
            if None in rooms[tgt].values():
                continue
            want = tuple(rooms[src][axis] + DIRS[dir_][i]
                         for i, axis in enumerate(axes))
            got = tuple(rooms[tgt][axis] for axis in axes)
            if want != got:
                mismatched.append("%s -%s-> %s (at %s, expected %s)"
                                  % (src, dir_, tgt, got, want))
    for msg in mismatched:
        warnings.append("direction/coord mismatch: %s" % msg)

    return problems, warnings, rooms, exits


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: python scripts/check_room_coords.py <file.ucl>\n")
        return 2

    path = argv[1]
    try:
        problems, warnings, rooms, exits = check(path)
    except OSError as exc:
        sys.stderr.write("cannot read %s: %s\n" % (path, exc))
        return 1
    except UnicodeDecodeError as exc:
        sys.stdout.write("Coords: file is not valid UTF-8: %s\n" % exc)
        return 1
    except Exception as exc:  # never leak a traceback to the caller
        sys.stdout.write("Coords: internal error while checking %s: %s: %s\n"
                         % (path, type(exc).__name__, exc))
        return 1

    for w in warnings:
        sys.stdout.write("Coords: WARNING: %s\n" % w)

    if problems:
        for p in problems:
            sys.stdout.write("Coords: %s\n" % p)
        return 1

    sys.stdout.write("OK: %s (%d rooms, %d room_exits, all reachable; "
                     "%d stacked cell(s), %d direction mismatch(es))\n"
                     % (path, len(rooms), len(exits),
                        len({w.split(" shared by")[0] for w in warnings
                             if " shared by " in w}),
                        len([w for w in warnings
                             if w.startswith("direction/coord mismatch")])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

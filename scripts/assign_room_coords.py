#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Assign coordinates to rooms in a zone UCL file
(Python port of scripts/assign_room_coords.exs).

Byte-exact port of the Elixir script (T1).  Rooms that already carry a
non-zero coordinate are left untouched but still used as anchors while walking
the exit graph.  Rooms with missing / all-zero coordinates are assigned
coordinates derived from neighbouring anchors via their exit directions.
Fully disconnected subgraphs are stacked above the origin on increasing z
levels, each orphan-rooted component at (0,0,level).

Usage:
  python scripts/assign_room_coords.py <zone.ucl> <start_room_id> \
      [--dry-run|--output <output_file>]

Options:
  --dry-run          Print the new content to stdout, don't write any file
  --output <file>    Write new content to <output_file> instead of overwriting input

Examples:
  python scripts/assign_room_coords.py data/world/test.ucl test_guangchang
  python scripts/assign_room_coords.py data/world/test.ucl test_guangchang --dry-run
  python scripts/assign_room_coords.py data/world/test.ucl test_guangchang --output /tmp/test_new.ucl
"""

import os
import re
import sys

# ---------------------------------------------------------------------------
# ASCII semantics: Elixir PCRE (no /u) treats \w \s \d as ASCII-only.  Python
# re treats them as Unicode by default.  All patterns here use re.ASCII.
# ---------------------------------------------------------------------------
_A = re.ASCII

# direction -> (dx, dy, dz); NB projected so minimap renders north-up
# (Elixir @dirs map; iteration order is never observable below).
DIRS = {
    "north": (0, 1, 0),
    "south": (0, -1, 0),
    "east": (1, 0, 0),
    "west": (-1, 0, 0),
    "northeast": (1, 1, 0),
    "northwest": (-1, 1, 0),
    "southeast": (1, -1, 0),
    "southwest": (-1, -1, 0),
    "northup": (0, 1, 1),
    "southup": (0, -1, 1),
    "eastup": (1, 0, 1),
    "westup": (-1, 0, 1),
    "up": (0, 0, 1),
    "down": (0, 0, -1),
    "northdown": (0, 1, -1),
    "southdown": (0, -1, -1),
    "eastdown": (1, 0, -1),
    "westdown": (-1, 0, -1),
    # Portal-like exits that don't change spatial coordinates
    "enter": (0, 0, 0),
    "out": (0, 0, 0),
    "in": (0, 0, 0),
    "go_in": (0, 0, 0),
    # climb acts like up
    "climb": (0, 0, 1),
}

# Non-geometric exit names that should be skipped for coordinate purposes
# (but they're still traversed for graph connectivity)
SKIP_DIRS = []

# ---------------------------------------------------------------------------
# Regexes (faithful to the Elixir regexes, all ASCII-flavoured)
# ---------------------------------------------------------------------------
_ROOM_RE = re.compile(r'^[ \t]*rooms "([^"]+)"[ \t]*\{', _A)
_EXITS_RE = re.compile(r'^[ \t]*room_exits "([^"]+)"[ \t]*\{', _A)

_X_RE = re.compile(r'^[ \t]*x[ \t]*=[ \t]*(-?\d+)', _A)
_Y_RE = re.compile(r'^[ \t]*y[ \t]*=[ \t]*(-?\d+)', _A)
_Z_RE = re.compile(r'^[ \t]*z[ \t]*=[ \t]*(-?\d+)', _A)

_EXIT_ROW_RE = re.compile(r'^[ \t]*(\w+)[ \t]*=[ \t]*(.+?)[ \t]*$', _A)
_TRAILING_BRACE_RE = re.compile(r'[ \t]+\}$', _A)
_QUOTE_TRIM_RE = re.compile(r'^"|"$', _A)
_LOCAL_TARGET_RE = re.compile(r'^rooms\.[a-z0-9_]+\.[iI][dD]$', _A)

_REPLACE_X_RE = re.compile(r'^([ \t]*)x[ \t]*=[ \t]*-?\d+', _A)
_REPLACE_Y_RE = re.compile(r'^([ \t]*)y[ \t]*=[ \t]*-?\d+', _A)
_REPLACE_Z_RE = re.compile(r'^([ \t]*)z[ \t]*=[ \t]*-?\d+', _A)

_NONBLANK_RE = re.compile(r'^[ \t]*\S', _A)
_INDENT_RE = re.compile(r'^([ \t]*)\S', _A)
_CLOSING_BRACE_RE = re.compile(r'^[ \t]*\}[ \t]*$', _A)

# exists?/2: String.match?(&1, ~r/^[ \t]*#{k}[ \t]*=/)
_EXISTS_RE = {
    "x": re.compile(r'^[ \t]*x[ \t]*=', _A),
    "y": re.compile(r'^[ \t]*y[ \t]*=', _A),
    "z": re.compile(r'^[ \t]*z[ \t]*=', _A),
}

# ---------------------------------------------------------------------------
# Tagged tuples mirroring Elixir values: ("local", id) / ("external", string)
# ---------------------------------------------------------------------------
LOCAL = "local"
EXTERNAL = "external"


def _current_coord(field_map):
    """current_coord/1: %{x: x, y: y, z: z} -> {x, y, z}; _ -> {0, 0, 0}."""
    if field_map is not None and "x" in field_map and "y" in field_map and "z" in field_map:
        return (field_map["x"], field_map["y"], field_map["z"])
    return (0, 0, 0)


# ---------------------------------------------------------------------------
# Scanning
# ---------------------------------------------------------------------------
def _brace_counts(line, in_multiline_comment=False):
    """Count { and } in a line, ignoring braces inside "..." and comments
    (// or /* */).  Faithful to the Elixir clause order, including its quirks:
    quote toggling ignores only the single-line flag, and * / start comments
    even inside strings."""
    o = 0
    c = 0
    q = False
    mlc = in_multiline_comment
    slc = False

    for ch in line:
        if ch == "/" and mlc:
            # End of multiline comment */
            q = q
            mlc = False
            slc = False
        elif ch == "*" and not mlc and not slc:
            # Potential start of multiline comment /*
            q = q
            mlc = True
            slc = False
        elif ch == "/" and not mlc and not slc:
            # Potential start of single-line comment //
            q = q
            mlc = False
            slc = True
        elif ch == "\n" and slc:
            # End of single-line comment at newline
            slc = False
        elif ch == '"' and not mlc and not slc:
            # Toggle string state (only when not in comment)
            q = not q
            mlc = mlc
            slc = False
        elif ch == "{" and not q and not mlc and not slc:
            # Only count braces when not in string or comment
            o += 1
            q = False
            mlc = False
            slc = False
        elif ch == "}" and not q and not mlc and not slc:
            c += 1
            q = False
            mlc = False
            slc = False
        # else: unchanged

    return (o, c)


def _parse_fields(acc):
    """parse_fields/1.  acc is newest-first; order only matters if a block has
    duplicate x/y/z lines (last one reduced wins)."""
    field_map = {}
    for line in acc:
        m = _X_RE.match(line)
        if m:
            field_map["x"] = int(m.group(1))
            continue
        m = _Y_RE.match(line)
        if m:
            field_map["y"] = int(m.group(1))
            continue
        m = _Z_RE.match(line)
        if m:
            field_map["z"] = int(m.group(1))
    return field_map


def _parse_exit_row(line):
    """parse_exit_row/1 -> (dir, ("local", id) | ("external", target)) | None."""
    line = _TRAILING_BRACE_RE.sub(" ", line)

    m = _EXIT_ROW_RE.match(line)
    if m is None:
        return None
    dir_ = m.group(1)
    raw = m.group(2)
    if dir_ == "room_id":
        # room_id = rooms.xxx.id is metadata, not an exit
        return None

    target = _QUOTE_TRIM_RE.sub("", raw.strip())
    if _LOCAL_TARGET_RE.match(target):
        # id = target |> String.replace(~r/^rooms\./, "") |> String.replace(~r/\.id$/, "")
        rid = re.sub(r'^rooms\.', "", target)
        rid = re.sub(r'\.id$', "", rid)
        return (dir_, (LOCAL, rid))
    return (dir_, (EXTERNAL, target))


def _scan(lines):
    """Returns (ordered_room_ids, fields, exits_map)."""
    room_ids = []
    fields = {}
    exits_map = {}
    state = None

    for line in lines:
        if state is None:
            room_ids, fields, exits_map, state = _scan_start(
                line, room_ids, fields, exits_map)
        elif state[0] == "room":
            room_ids, fields, exits_map, state = _in_room(
                line, state, room_ids, fields, exits_map)
        elif state[0] == "exits":
            room_ids, fields, exits_map, state = _in_exits(
                line, state, room_ids, fields, exits_map)
        else:
            state = None

    return (list(reversed(room_ids)), fields, exits_map)


def _scan_start(line, room_ids, fields, exits_map):
    m = _ROOM_RE.match(line)
    if m:
        return (room_ids, fields, exits_map, ("room", m.group(1), 1, []))
    m = _EXITS_RE.match(line)
    if m:
        return (room_ids, fields, exits_map, ("exits", m.group(1), 1, []))
    return (room_ids, fields, exits_map, None)


def _in_room(line, state, room_ids, fields, exits_map):
    _, rid, depth, acc = state
    open_, close = _brace_counts(line)
    depth2 = depth + open_ - close

    if depth2 == 0:
        fields[rid] = _parse_fields(acc)
        return ([rid] + room_ids, fields, exits_map, None)
    return (room_ids, fields, exits_map, ("room", rid, depth2, [line] + acc))


def _in_exits(line, state, room_ids, fields, exits_map):
    _, eid, edepth, eacc = state
    open_, close = _brace_counts(line)
    depth2 = edepth + open_ - close

    row = _parse_exit_row(line)
    eacc2 = eacc if row is None else [row] + eacc

    if depth2 == 0:
        exits_map[eid] = list(reversed(eacc2))
        return (room_ids, fields, exits_map, None)
    return (room_ids, fields, exits_map, ("exits", eid, depth2, eacc2))


# ---------------------------------------------------------------------------
# Coordinate assignment
# ---------------------------------------------------------------------------
def _assign_coords(room_ids, fields, exits_map, start_id):
    state = {
        "assigned": {start_id: (0, 0, 0)},
        "visited": {start_id},
        "layer": 1,
        "queue": [start_id],
        "fields": fields,
        "exits_map": exits_map,
        "layer_anchors": {0: start_id},  # z level -> room_id at that level
        "new_exits": {},  # room_id -> [(dir, target)] to add
    }

    _drain(state)
    _orphans(state, room_ids)

    # Merge new_exits into exits_map for writing
    final_exits_map = _merge_new_exits(state["exits_map"], state["new_exits"])

    # Ensure ALL rooms from room_ids are in the final exits_map, even with empty exits.
    # The validator requires every room to have a room_exits block.
    for rid in room_ids:
        if rid not in final_exits_map:
            final_exits_map[rid] = []

    return (state["assigned"], final_exits_map)


def _orphans(state, room_ids):
    """Rooms that already had a non-zero coordinate act as anchors and are
    simply visited (their coordinates are preserved).  Rooms left with only
    zeros get a fresh component root stacked at (0,0,layer).  When a new layer
    is created, connect it vertically to the previous layer's anchor."""
    for rid in room_ids:
        _process_orphan_room(rid, state)
    return state


def _process_orphan_room(id_, st):
    if id_ in st["visited"] or id_ in st["assigned"]:
        return st

    current = _current_coord(st["fields"].get(id_))

    if current != (0, 0, 0):
        st["assigned"][id_] = current
    else:
        # New orphan at new z layer
        new_z = st["layer"]
        prev_anchor = st["layer_anchors"].get(new_z - 1)

        st["assigned"][id_] = (0, 0, new_z)
        st["layer"] = st["layer"] + 1
        st["layer_anchors"][new_z] = id_

        # Add vertical connection: up from topmost of previous anchor's
        # up-chain, down from this orphan
        if prev_anchor is not None:
            topmost = _find_topmost_via_up(
                prev_anchor, st["exits_map"], st["new_exits"])
            _add_vertical_exits(st, topmost, id_)

    st["visited"].add(id_)
    st["queue"] = [id_]
    _drain(st)
    return st


def _add_vertical_exits(state, from_id, to_id):
    # Find the topmost room by following "up" exits from the previous anchor
    topmost = _find_topmost_via_up(
        from_id, state["exits_map"], state["new_exits"])

    # Find the bottommost room by following "down" exits from the new orphan
    bottommost = _find_bottommost_via_down(
        to_id, state["exits_map"], state["new_exits"])

    # Check if topmost already has an "up" exit (in original exits_map or new_exits)
    topmost_exits = list(state["exits_map"].get(topmost, [])) + list(state["new_exits"].get(topmost, []))
    has_up = any(dir_ == "up" for dir_, _ in topmost_exits)

    # Check if bottommost already has a "down" exit
    bottommost_exits = list(state["exits_map"].get(bottommost, [])) + list(state["new_exits"].get(bottommost, []))
    has_down = any(dir_ == "down" for dir_, _ in bottommost_exits)

    # Add up exit from topmost to new orphan (only if not already present)
    if not has_up:
        new_exits_from = state["new_exits"].get(topmost, []) + [("up", (LOCAL, to_id))]
        state["new_exits"][topmost] = new_exits_from

    # Add down exit from bottommost to topmost (only if not already present)
    if not has_down:
        new_exits_to = state["new_exits"].get(bottommost, []) + [("down", (LOCAL, topmost))]
        state["new_exits"][bottommost] = new_exits_to

    return state


def _find_topmost_via_up(start_id, exits_map, new_exits):
    return _find_topmost_via_up_rec(start_id, exits_map, new_exits, {start_id})


def _find_topmost_via_up_rec(current, exits_map, new_exits, visited):
    # Check both original exits_map and new_exits for "up" exits
    exits = list(exits_map.get(current, [])) + list(new_exits.get(current, []))

    up_exit = None
    for exit_row in exits:
        if exit_row[0] == "up":
            up_exit = exit_row
            break

    if up_exit is not None and up_exit[1][0] == LOCAL:
        next_id = up_exit[1][1]
        if next_id in visited or not _real_room(next_id, exits_map, new_exits):
            return current
        visited.add(next_id)
        return _find_topmost_via_up_rec(next_id, exits_map, new_exits, visited)
    return current


def _find_bottommost_via_down(start_id, exits_map, new_exits):
    return _find_bottommost_via_down_rec(start_id, exits_map, new_exits, {start_id})


def _find_bottommost_via_down_rec(current, exits_map, new_exits, visited):
    # Check both original exits_map and new_exits for "down" exits
    exits = list(exits_map.get(current, [])) + list(new_exits.get(current, []))

    down_exit = None
    for exit_row in exits:
        if exit_row[0] == "down":
            down_exit = exit_row
            break

    if down_exit is not None and down_exit[1][0] == LOCAL:
        next_id = down_exit[1][1]
        if next_id in visited or not _real_room(next_id, exits_map, new_exits):
            return current
        visited.add(next_id)
        return _find_bottommost_via_down_rec(next_id, exits_map, new_exits, visited)
    return current


def _real_room(id_, exits_map, new_exits):
    """A "real" room is one that either has an exit block in this zone
    (exits_map) or already received a new exit entry (new_exits)."""
    return id_ in exits_map or id_ in new_exits


def _drain(state):
    while state["queue"]:
        id_ = state["queue"][0]
        rest = state["queue"][1:]
        (cx, cy, cz) = state["assigned"][id_]
        exits = state["exits_map"].get(id_, [])

        q = []
        for (dir_, target) in exits:
            q = _visit_neighbour((cx, cy, cz), dir_, target, state, q)

        state["queue"] = rest + list(reversed(q))
    return state


def _visit_neighbour(from_, dir_, target, st, q):
    # `target == :external` in Elixir is a tuple-vs-atom comparison that is
    # never true; kept here as an always-false guard for fidelity.
    if dir_ in SKIP_DIRS or dir_ not in DIRS or target == "external":
        return q

    tid = target[1]

    if tid not in st["fields"] or tid in st["visited"]:
        return q

    (tdx, tdy, tdz) = DIRS[dir_]
    (cx, cy, cz) = from_
    candidate = (cx + tdx, cy + tdy, cz + tdz)
    current = _current_coord(st["fields"].get(tid))

    if candidate == (0, 0, 0):
        return q
    elif current == (0, 0, 0):
        st["assigned"][tid] = candidate
        st["visited"].add(tid)
        return [tid] + q
    else:
        st["assigned"][tid] = current
        st["visited"].add(tid)
        return [tid] + q


def _merge_new_exits(exits_map, new_exits):
    """Merge new_exits into the original exits_map."""
    acc = dict(exits_map)
    for room_id, new_exit_list in new_exits.items():
        existing = acc.get(room_id, [])
        # Avoid duplicates: only add if not already present
        merged = list(existing)
        for (dir_, target) in new_exit_list:
            if not any(d == dir_ and t == target for (d, t) in merged):
                merged.insert(0, (dir_, target))
        acc[room_id] = list(reversed(merged))
    return acc


# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------
def _rewrite(lines, fields, assigned, exits_map, room_set):
    out = []
    state = None
    for line in lines:
        out, state = _rewrite_line(
            line, out, state, fields, assigned, exits_map, room_set)
    return "\n".join(reversed(out))


def _rewrite_line(line, out, state, fields, assigned, exits_map, room_set):
    if state is None:
        m = _ROOM_RE.match(line)
        if m:
            return ([line] + out, ("room", m.group(1), 1, []))
        m = _EXITS_RE.match(line)
        if m:
            return ([line] + out, ("exits", m.group(1), 1, []))
        return ([line] + out, None)

    if state[0] == "room":
        _, id_, depth, acc = state
        open_, close = _brace_counts(line)
        depth2 = depth + open_ - close

        if depth2 == 0:
            # closing brace line of the room block
            block = list(reversed([line] + acc))
            new_block = _build_block(block, fields, assigned, id_)
            return (list(reversed(new_block)) + out, None)
        return (out, ("room", id_, depth2, [line] + acc))

    if state[0] == "exits":
        _, eid, edepth, eacc = state
        open_, close = _brace_counts(line)
        depth2 = edepth + open_ - close

        if depth2 == 0:
            # closing brace line of the exits block
            block = list(reversed([line] + eacc))
            new_block = _build_exits_block(block, eid, exits_map, room_set)
            return (list(reversed(new_block)) + out, None)
        return (out, ("exits", eid, depth2, [line] + eacc))

    return ([line] + out, None)


def _add_missing_exit_blocks(content, exits_map):
    """Generate a `room_exits` block for rooms that have exits in the final map
    but no `room_exits` block in the source file (their new vertical exits
    would otherwise be silently lost).  The block is placed right after the
    room's own `rooms "id"` block."""
    lines = content.split("\n")

    block_ids = set()
    for line in lines:
        m = _EXITS_RE.match(line)
        if m:
            block_ids.add(m.group(1))

    missing = {}
    for id_, exits in exits_map.items():
        # Always add missing exit blocks, even for rooms with no exits (empty list).
        # The validator requires every room to have a room_exits block.
        if id_ not in block_ids:
            missing[id_] = exits

    if len(missing) == 0:
        return content

    out = []
    state = None
    for line in lines:
        if state is None:
            m = _ROOM_RE.match(line)
            if m:
                out = [line] + out
                state = (m.group(1), 1)
            else:
                out = [line] + out
                state = None
        elif isinstance(state[1], int):
            id_, depth = state
            open_, close = _brace_counts(line)
            depth2 = depth + open_ - close

            if depth2 <= 0:
                if id_ in missing:
                    block_lines = _build_new_exits_block(id_, missing[id_])
                else:
                    block_lines = []
                out = list(reversed(block_lines)) + [line] + out
                state = None
            else:
                out = [line] + out
                state = (id_, depth2)
        else:
            out = [line] + out
            state = None

    return "\n".join(reversed(out))


def _build_new_exits_block(id_, exits):
    header = '  room_exits "%s" {' % id_
    room_id_line = "    room_id = rooms.%s.id" % id_

    exit_lines = []
    for (dir_, target) in exits:
        if target[0] == LOCAL:
            exit_lines.append("    %s = rooms.%s.id" % (dir_, target[1]))
        else:
            exit_lines.append("    %s = %s" % (dir_, target[1]))

    return [header, room_id_line] + exit_lines + ["    }"]


def _build_block(content, fields, assigned, id_):
    coord = assigned.get(id_)
    current = _current_coord(fields.get(id_))

    if coord is None:
        return content
    if coord == current:
        return content
    return _replace_or_insert(content, coord)


def _replace_or_insert(content, xyz):
    x, y, z = xyz
    replaced = []
    for line in content:
        m = _REPLACE_X_RE.match(line)
        if m:
            replaced.append(m.group(1) + "x = %d" % x)
            continue
        m = _REPLACE_Y_RE.match(line)
        if m:
            replaced.append(m.group(1) + "y = %d" % y)
            continue
        m = _REPLACE_Z_RE.match(line)
        if m:
            replaced.append(m.group(1) + "z = %d" % z)
            continue
        replaced.append(line)

    missing = []
    for k, v in [("x", x), ("y", y), ("z", z)]:
        if not _exists(replaced, k):
            missing.append("%s = %d" % (k, v))

    indent = _block_indent(content)
    inserted = [indent + item for item in missing]
    return inserted + replaced


def _exists(replaced, k):
    return any(_EXISTS_RE[k].match(line) for line in replaced)


def _block_indent(content):
    for line in content:
        if _NONBLANK_RE.match(line):
            return _INDENT_RE.match(line).group(1)
    return "  "


def _build_exits_block(content, eid, exits_map, room_set):
    new_exits = exits_map.get(eid)
    if new_exits is None:
        return content

    # Parse existing exits from content
    existing = []
    for line in content:
        row = _parse_exit_row(line)
        if row is not None:
            existing.append(row)
    existing = list(reversed(existing))

    # Merge new exits, avoiding duplicates
    merged = list(new_exits)
    for (dir_, target) in existing:
        if not any(d == dir_ and t == target for (d, t) in merged):
            merged.insert(0, (dir_, target))
    merged = list(reversed(merged))

    # Rebuild block: keep non-exit lines (like room_id = ...) and replace exit lines
    indent = _block_indent(content)

    # Keep non-exit lines (room_id = ...) and add merged exits
    # But EXCLUDE the closing brace from non_exit_lines since we'll add our own
    non_exit_lines = [line for line in content if _parse_exit_row(line) is None and not _CLOSING_BRACE_RE.match(line)]

    # Handle case where closing brace is on the same line as the last exit
    # e.g., "    exit = rooms.foo.id  }" -> remove trailing "  }"
    if non_exit_lines and non_exit_lines[-1].rstrip().endswith("}"):
        non_exit_lines[-1] = non_exit_lines[-1].rstrip()[:-1].rstrip()

    # An up/down exit whose target is a room not present in this zone is a
    # phantom reference (test data like room_above/room_below).  When the new
    # z-axis link replaces it with a real room, comment the phantom out.
    exit_lines = []
    for (dir_, target) in merged:
        comment = _phantom_updown((dir_, target), merged, room_set)
        exit_lines.append(_render_exit_row(dir_, target, indent, comment))

    # Add closing brace
    closing_brace = indent + "}"

    return non_exit_lines + exit_lines + [closing_brace]


def _render_exit_row(dir_, target, indent, comment):
    if target[0] == LOCAL:
        prefix = indent + "# " if comment else indent
        return prefix + dir_ + " = rooms." + target[1] + ".id"
    return indent + dir_ + " = " + target[1]


def _phantom_updown(row, merged, room_set):
    """True when (dir,target) is a phantom up/down (points to a room not in this
    zone) AND a real replacement exists for the same direction in merged."""
    dir_ = row[0]
    target = row[1]
    if dir_ in ("up", "down") and target[0] == LOCAL and target[1] not in room_set:
        target_id = target[1]
        for (d, t) in merged:
            if d == dir_ and t[0] == LOCAL and t[1] != target_id and t[1] in room_set:
                return True
        return False
    return False


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
def _out(text):
    """IO.puts equivalent: UTF-8 bytes plus a single LF (never CRLF)."""
    sys.stdout.buffer.write((text + "\n").encode("utf-8"))
    sys.stdout.buffer.flush()


def _report(fields, assigned, start_id, path):
    ids = list(fields.keys())
    _out("zone: %s  rooms: %d" % (os.path.basename(path), len(ids)))

    anchors = 0
    new_coords = 0
    for id_ in ids:
        current = _current_coord(fields.get(id_))
        assigned_coord = assigned.get(id_)

        if current != (0, 0, 0) and (assigned_coord is None or assigned_coord == current):
            anchors += 1
        elif current == (0, 0, 0) and not (assigned_coord is None or assigned_coord == (0, 0, 0)):
            new_coords += 1
        elif id_ != start_id and assigned_coord == current:
            pass
        else:
            pass

    _out("anchor rooms (kept non-zero): %d" % anchors)
    _out("rooms assigned new coords:    %d" % new_coords)
    _out("start room: %s -> (0,0,0)" % start_id)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def _read_text(path):
    with open(path, "rb") as f:
        data = f.read()
    return data.decode("utf-8")


def _write_text(path, content):
    with open(path, "wb") as f:
        f.write(content.encode("utf-8"))


def _parse_argv(args):
    """Mirror OptionParser.parse(args, switches: [dry_run: :boolean,
    output: :string], strict: false)."""
    opts = {}
    positionals = []
    i = 0
    while i < len(args):
        a = args[i]
        if a.startswith("--"):
            body = a[2:]
            if "=" in body:
                k, v = body.split("=", 1)
                opts["output" if k == "output" else k] = v
            elif body == "dry-run" or body == "dry_run":
                opts["dry_run"] = True
            elif body == "output":
                if i + 1 < len(args):
                    opts["output"] = args[i + 1]
                    i += 1
                else:
                    opts["output"] = None
            else:
                opts[body] = True
        else:
            positionals.append(a)
        i += 1
    return opts, positionals


def run(args):
    opts, positionals = _parse_argv(args)
    path = positionals[0]
    start_id = positionals[1]

    content = _read_text(path)
    lines = content.split("\n")

    room_ids, fields, exits_map = _scan(lines)

    if start_id not in room_ids:
        _out("ERROR: start room '%s' not found in %s" % (start_id, path))
        sys.exit(1)

    assigned, final_exits_map = _assign_coords(room_ids, fields, exits_map, start_id)
    room_set = set(room_ids)
    new_content = _rewrite(lines, fields, assigned, final_exits_map, room_set)
    new_content = _add_missing_exit_blocks(new_content, final_exits_map)
    _report(fields, assigned, start_id, path)

    if opts.get("dry_run"):
        _out(new_content)
    elif opts.get("output"):
        output = opts.get("output")
        _write_text(output, new_content)
        _out("Written to %s" % output)
    else:
        _write_text(path, new_content)


def main(argv):
    if len(argv) < 2:
        _out("usage: python scripts/assign_room_coords.py <zone.ucl> <start_room_id> "
             "[--dry-run|--output <output_file>]")
        _out("  --dry-run          Print new content to stdout")
        _out("  --output <file>    Write to output file instead of overwriting input")
        return 1

    run(argv)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

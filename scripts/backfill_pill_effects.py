#!/usr/bin/env python3
"""
Backfill LPC `do_effect(object me)` consumable hooks into the data-driven
`meta.effect = { kind = "pill", ... }` schema (P5-5).

For every regular (non-custom) `do_effect` in the LPC corpus we:
  1. extract heal (receive_curing/receive_heal/add of qi/jing/neili),
     cooldown (last_eat/X key + seconds), full-check vital, vision text,
     start_busy rounds, and the cooldown/full reject strings;
  2. locate the UCL item via the `# Generated from C:/files/git/mud/d/<relpath>`
     marker;
  3. inject `medicine = { ... }` + `effect = { ... }` into the item's `meta`
     block and add `"eat"` to its `verbs` list.

UCL constraints (see scripts/probe_elias_expressibility.exs):
  * nested map entries are WHITESPACE-separated, never comma;
  * string lists use comma+space (no trailing comma);
  * `\\n` inside a string is interpreted as a newline by elias.

Idempotent: skips items that already carry `effect = {`.
Safe: backs up each touched UCL to scripts/tmp/backup-pill-<ts>/ and runs
scripts/validate_ucl.py on every changed file (aborts + reverts on failure).

Usage:
  python3 scripts/backfill_pill_effects.py            # dry-run, prints table
  python3 scripts/backfill_pill_effects.py --apply    # write + validate
"""
import os, re, sys, glob, shutil, subprocess, datetime

ROOT = "C:/files/git/wuxia_mud_ex"
CORPUS = "C:/files/git/mud/d"
WORLD = os.path.join(ROOT, "data/world")
UCL_COMMENT_PREFIX = "C:/files/git/mud/d/"

COLOR_CODES = ["HIC", "HIR", "HIY", "HIG", "HIB", "HIW", "HIM", "RED", "YEL",
               "GRN", "CYN", "BLU", "MAG", "WHT", "NOR", "BOLD", "BLINK", "REV"]

CUSTOM_MARKERS = ["random", "water", "drunk", "exert", "mingji", "potent",
                  "gift", "call_out", "remove_call_out"]

# Heal/vital patterns that the data-driven `meta.effect` schema CANNOT faithfully
# express (it only restores qi/jing/neili up to max, and applies a fixed busy /
# cooldown / vision / stack). Anything touching these must be a custom handler or
# exempt — never force-fit, or we'd produce wrong in-game behaviour.
SPECIAL_MARKERS = [
    (r'jingli', "jingli-vital(unmodeled)"),
    (r'improve_\w+\s*\(', "improve-stat(permanent)"),
    (r'set\(\s*"(qi|jing|neili|eff_qi|eff_jing)"', "set-vital-to-value"),
    (r'set\(\s*"max_\w+"', "set-max-stat"),
    (r'add\(\s*"max_\w+"', "improve-stat(permanent)"),
    (r'\b(skill|mingji|potent|mingxiang)\b', "skill/potent"),
    (r'add\(\s*"(qi|jing|neili)"\s*,\s*(?![\d])', "dynamic-amount"),
    (r'query\(\s*"max_\w+"\s*\)\s*-\s*\d+', "dynamic-amount"),
    # cure / poison logic cannot be expressed by the heal-only pill schema
    (r'clear_condition|query_condition|set_poison|apply_poison|poison_type',
     "antidote/poison(custom)"),
]

VITAL_MAP = {"qi": "qi", "jing": "jing", "neili": "neili",
             "eff_qi": "qi", "eff_jing": "jing", "eff_neili": "neili"}


def strip_colors(s):
    for c in COLOR_CODES:
        s = s.replace(c, "")
    s = re.sub(r"\\e\[[0-9;]*m", "", s)
    return s.strip()


def extract_body(path):
    t = open(path, encoding="utf-8", errors="ignore").read()
    m = re.search(r"\bint\s+do_effect\s*\([^)]*\)\s*\{", t)
    if not m:
        return None
    i = m.end() - 1
    depth = 0
    start = i
    while i < len(t):
        if t[i] == "{":
            depth += 1
        elif t[i] == "}":
            depth -= 1
            if depth == 0:
                return t[start + 1:i]
        i += 1
    return None


def classify(body):
    reasons = []
    if re.search(r"random\s*\(", body):
        reasons.append("random")
    for mk in CUSTOM_MARKERS:
        if re.search(r"\b" + mk + r"\b", body, re.I):
            reasons.append(mk)
    for pat, label in SPECIAL_MARKERS:
        if re.search(pat, body, re.I):
            reasons.append(label)
    return reasons


def extract_write_text(arg, item_name):
    """Reconstruct a write()/message_vision() string literal, interleaving the
    item name wherever LPC calls name()/this_object()->name()."""
    tokens = []
    i = 0
    while i < len(arg):
        if arg[i] == '"':
            j = i + 1
            buf = ""
            while j < len(arg) and arg[j] != '"':
                if arg[j] == "\\":
                    buf += arg[j:j + 2]
                    j += 2
                else:
                    buf += arg[j]
                    j += 1
            tokens.append(("str", strip_colors(buf)))
            i = j + 1
        elif re.match(r"name\s*\(", arg[i:]):
            tokens.append(("name", None))
            p1 = arg.find("(", i)
            if p1 == -1:
                i += 4
            else:
                p2 = arg.find(")", p1 + 1)
                i = p2 + 1 if p2 != -1 else p1 + 1
        else:
            i += 1
    text = ""
    for t in tokens:
        if t[0] == "str":
            text += t[1]
        elif t[0] == "name":
            text += item_name or ""
    return text


def extract_effect(relpath, body, item_name):
    eff = {}

    # --- heal -------------------------------------------------------------
    heals = {}
    for kind in ("receive_curing", "receive_heal"):
        for mv in re.finditer(kind + r'\(\s*"(\w+)"\s*,\s*(\d+)\s*\)', body):
            vital, amt = mv.group(1), int(mv.group(2))
            if vital in VITAL_MAP:
                v = VITAL_MAP[vital]
                heals[v] = max(heals.get(v, 0), amt)
    for mv in re.finditer(r'add\(\s*"(\w+)"\s*,\s*(\d+)\s*\)', body):
        vital, amt = mv.group(1), int(mv.group(2))
        if vital in VITAL_MAP:
            v = VITAL_MAP[vital]
            heals[v] = max(heals.get(v, 0), amt)
    eff["heal"] = heals

    # --- cooldown ---------------------------------------------------------
    cm = re.search(r'query_temp\(\s*"last_eat/([^"]+)"\s*\)\s*<\s*=?\s*(\d+)', body)
    if cm:
        eff["cooldown_key"] = "last_eat/" + cm.group(1)
        eff["cooldown"] = int(cm.group(2))

    # --- full-check vital -------------------------------------------------
    fm = re.search(r'my\[\s*"(\w+)"\s*\]\s*==\s*my\[\s*"max_\1"\s*\]', body) or \
        re.search(r'query\(\s*"(\w+)"\s*\)\s*==\s*query\(\s*"max_\1"\)', body)
    if fm:
        eff["full_vital"] = fm.group(1)

    # --- busy -------------------------------------------------------------
    bm = re.search(r"start_busy\(\s*(\d+)\s*\)", body)
    if bm:
        eff["busy"] = int(bm.group(1))

    # --- branch text via line state machine -------------------------------
    branch = None
    for raw in body.splitlines():
        s = raw.strip()
        if re.search(r"time\(\)\s*-\s*query_temp\(\s*\"last_eat/", s):
            branch = "cooldown"
        elif re.search(r'my\[\s*"(\w+)"\s*\]\s*==\s*my\[\s*"max_\1"', s) or \
             re.search(r'query\(\s*"(\w+)"\s*\)\s*==\s*query\(\s*"max_\1"', s):
            branch = "full"
        elif re.match(r"^\}", s):
            branch = None

        wm = re.search(r'write\(', s)
        if wm:
            arg = s[wm.end():]
            arg = arg[:arg.find(")")] if ")" in arg else arg
            txt = extract_write_text(arg, item_name)
            if txt and branch == "cooldown" and "cooldown_text" not in eff:
                eff["cooldown_text"] = txt
            if txt and branch == "full" and "full_text" not in eff:
                eff["full_text"] = txt

        vm = re.search(r'message_vision\(', s)
        if vm and "vision_text" not in eff:
            arg = s[vm.end():]
            arg = arg[:arg.find(",")] if "," in arg else arg
            txt = extract_write_text(arg, item_name)
            if txt:
                eff["vision_text"] = txt

        # tell_object(me, "...") — self-only message (no room broadcast)
        tm = re.search(r'tell_object\(', s)
        if tm and "self_text" not in eff:
            q = s.find('"', tm.end())
            if q != -1:
                txt = extract_write_text(s[q:], item_name)
                if txt:
                    eff["self_text"] = txt

    return eff


def esc(s):
    return (s or "").replace('"', '\\"')


def build_effect_block(eff):
    L = ["        effect = {"]
    L.append('          kind = "pill"')
    if eff.get("cooldown"):
        L.append("          cooldown = %d" % eff["cooldown"])
        L.append('          cooldown_key = "%s"' % esc(eff.get("cooldown_key", "")))
    if eff.get("cooldown_text"):
        L.append('          cooldown_text = "%s"' % esc(eff["cooldown_text"]))
    if eff.get("full_vital"):
        L.append('          full_vital = "%s"' % eff["full_vital"])
        L.append('          full_text = "%s"' % esc(eff.get("full_text", "")))
    if eff.get("vision_text"):
        # UCL convention uses {npc} (not LPC's $N) as the actor placeholder.
        vt = eff["vision_text"].replace("$N", "{npc}").replace("$n", "{npc}")
        L.append('          vision_text = "%s"' % esc(vt))
    if eff.get("self_text"):
        L.append('          self_text = "%s"' % esc(eff["self_text"]))
    if eff.get("busy"):
        L.append("          busy = %d" % eff["busy"])
    L.append("          stack = true")
    L.append("        }")
    return "\n".join(L) + "\n"


def build_ucl_index():
    """Map LPC relpath -> UCL file path, built once by scanning every UCL file
    for its `# Generated from C:/files/git/mud/d/<relpath>` markers."""
    idx = {}
    cache = {}
    for ucl in glob.glob(os.path.join(WORLD, "*.ucl")):
        txt = open(ucl, encoding="utf-8").read()
        cache[ucl] = txt
        for m in re.finditer(r"# Generated from (C:/files/git/mud/d/[^ \n]+)", txt):
            rel = m.group(1)[len(UCL_COMMENT_PREFIX):]
            idx[rel] = ucl
    return idx, cache


def find_ucl(relpath, ucl_index):
    return ucl_index.get(relpath)


def apply_item(ucl_path, relpath, item_id, eff, dry_run, backup_dir, backed_up):
    text = open(ucl_path, encoding="utf-8").read()
    target = UCL_COMMENT_PREFIX + relpath
    idx = text.find(target)
    if idx < 0:
        return False, "no # Generated comment"
    # The UCL item id may differ from the LPC basename (e.g. hyphen<->underscore),
    # so try the derived id, its normalizations, then the first items block.
    candidates = [item_id, item_id.replace("-", "_"), item_id.replace("_", "-")]
    m = None
    for cand in candidates:
        m = re.search(r'items\s+"' + re.escape(cand) + r'"\s*\{', text[idx:])
        if m:
            break
    if not m:
        m = re.search(r'items\s+"([^"]+)"\s*\{', text[idx:])
    if not m:
        return False, "no items block after marker"
    block_start = idx + m.start()
    i = text.find("{", block_start)
    depth = 0
    j = i
    while j < len(text):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                block_end = j
                break
        j += 1
    block = text[block_start:block_end + 1]
    if "effect = {" in block:
        return False, "already backfilled"

    new_block = block

    # 1. verbs: add "eat"
    vm = re.search(r"verbs\s*=\s*\[(.*?)\]", new_block, re.S)
    if vm:
        entries = re.findall(r'"([^"]*)"', vm.group(1))
        if "eat" not in entries:
            entries.append("eat")
            new_verbs = "  verbs = [\n" + "".join(
                '    "%s",\n' % e for e in entries[:-1]) + \
                '    "%s"\n' % entries[-1] + "  ]"
            new_block = new_block[:vm.start()] + new_verbs + new_block[vm.end():]

    # 2. meta: insert medicine + effect before meta's closing }
    mm = re.search(r"meta\s*=\s*\{", new_block)
    if not mm:
        return False, "no meta block"
    open_pos = mm.end() - 1  # index of the opening '{'
    depth = 0
    close_pos = None
    j = open_pos
    while j < len(new_block):
        if new_block[j] == "{":
            depth += 1
        elif new_block[j] == "}":
            depth -= 1
            if depth == 0:
                close_pos = j
                break
        j += 1
    if close_pos is None:
        return False, "cannot find meta close"
    med_line = ""
    if eff.get("heal"):
        med = " ".join("%s = %d" % (k, v) for k, v in eff["heal"].items())
        med_line = "        medicine = { %s }\n" % med
    eff_lines = build_effect_block(eff)
    new_block = new_block[:close_pos] + "\n" + med_line + eff_lines + \
        new_block[close_pos:]

    if dry_run:
        return True, "dry-run"
    # backup ONCE per unique UCL file (pristine snapshot) so a failed validation
    # can be reverted fully; subsequent items in the same file skip re-backup.
    rel = os.path.relpath(ucl_path, ROOT).replace("\\", "/")
    os.makedirs(backup_dir, exist_ok=True)
    bak = os.path.join(backup_dir, rel.replace("/", "__"))
    if bak not in backed_up:
        shutil.copy2(ucl_path, bak)
        backed_up.add(bak)
    new_text = text[:block_start] + new_block + text[block_end + 1:]
    with open(ucl_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_text)
    return True, "applied"


def main():
    dry_run = "--apply" not in sys.argv
    bodies = {}
    for root, _, fs in os.walk(CORPUS):
        if "/.git" in root:
            continue
        for f in fs:
            if not f.endswith(".c"):
                continue
            p = os.path.join(root, f)
            b = extract_body(p)
            if b is not None:
                bodies[os.path.relpath(p, CORPUS)] = b

    rows = []
    skipped_custom = []
    ucl_index, ucl_cache = build_ucl_index()
    for relpath, body in sorted(bodies.items()):
        relpath = relpath.replace("\\", "/")
        reasons = classify(body)
        item_id = os.path.splitext(os.path.basename(relpath))[0]
        if reasons:
            skipped_custom.append((relpath, reasons))
            continue
        ucl = find_ucl(relpath, ucl_index)
        if not ucl:
            skipped_custom.append((relpath, ["no-ucl"]))
            continue
        # item name from UCL block
        target = UCL_COMMENT_PREFIX + relpath
        txt = ucl_cache[ucl]
        idx = txt.find(target)
        nm = re.search(r'name\s*=\s*"([^"]*)"', txt[idx:idx + 4000])
        item_name = nm.group(1) if nm else item_id
        eff = extract_effect(relpath, body, item_name)
        # Only items whose LPC do_effect maps to a modeled vital heal
        # (qi/jing/neili) are faithfully representable by the pill schema.
        # Everything else (potential gain, poison, antidote, max-stat boost,
        # no-op) is skipped — never force-fit or we'd produce wrong behaviour.
        if not eff.get("heal"):
            skipped_custom.append((relpath, ["no-modeled-heal"]))
            continue
        rows.append((relpath, item_id, ucl, eff))

    print("=== REGULAR do_effect items to backfill: %d ===" % len(rows))
    print("%-42s %-12s %-10s %-8s %-6s %-6s %s" %
          ("relpath", "id", "heal", "cd", "full", "busy", "ucl"))
    for relpath, item_id, ucl, eff in rows:
        heal = ",".join("%s:%d" % (k, v) for k, v in eff["heal"].items()) or "-"
        cd = "%s/%ds" % (eff.get("cooldown_key", "-"), eff.get("cooldown", 0)) \
            if eff.get("cooldown") else "-"
        full = eff.get("full_vital", "-")
        busy = eff.get("busy", "-")
        print("%-42s %-12s %-10s %-8s %-6s %-6s %s" %
              (relpath[-42:], item_id[:12], heal[:10], cd[:8], full[:6],
               str(busy)[:6], os.path.basename(ucl)))

    print("\n=== SKIPPED custom/non-regular: %d ===" % len(skipped_custom))
    for relpath, reasons in skipped_custom:
        print("  %-50s %s" % (relpath, ",".join(reasons)))

    if dry_run:
        print("\nDRY-RUN only. Re-run with --apply to write changes.")
        return

    # apply
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = os.path.join(ROOT, "scripts/tmp/backup-pill-%s" % ts)
    applied = []
    failed = []
    backed_up = set()
    for relpath, item_id, ucl, eff in rows:
        ok, msg = apply_item(ucl, relpath, item_id, eff, False, backup_dir, backed_up)
        if ok:
            applied.append((ucl, item_id, msg))
        else:
            failed.append((ucl, item_id, msg))
    print("\n=== APPLIED: %d | FAILED: %d ===" % (len(applied), len(failed)))
    for ucl, item_id, msg in failed:
        print("  FAIL %s %s: %s" % (ucl, item_id, msg))

    # validate every touched UCL
    touched = sorted(set(u for u, _, _ in applied))
    print("\n=== validate_ucl on %d touched files ===" % len(touched))
    bad = []
    for ucl in touched:
        r = subprocess.run(["python3", os.path.join(ROOT, "scripts/validate_ucl.py"), ucl],
                           capture_output=True, text=True)
        if r.returncode != 0:
            bad.append((ucl, r.stdout[-300:] + r.stderr[-300:]))
    if bad:
        print("VALIDATION FAILED — reverting from backup %s" % backup_dir)
        for ucl, _, _ in applied:
            bak = os.path.join(backup_dir,
                               os.path.relpath(ucl, ROOT).replace("\\", "/").replace("/", "__"))
            if os.path.exists(bak):
                shutil.copy2(bak, ucl)
        for ucl, err in bad:
            print("  INVALID", ucl, err)
        sys.exit(1)
    print("All touched UCL files pass validate_ucl.py. Backup at", backup_dir)


if __name__ == "__main__":
    main()

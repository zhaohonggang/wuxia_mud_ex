#!/usr/bin/env python3
"""Wire generated perform/exert modules into each skill's perform_list/0 / exert_list/0.

Walks the LPC source corpus (like translate_perform.py), classifies each move as
perform/exert, resolves the on-disk Elixir module name, then merges a
`"<move>" => <Module>` entry into the matching skill module's list function.
Existing entries (hand-written / protected) are never overwritten.

Used by the F4 skills/perform migration pipeline. Dry-run by default; pass
--apply to write changes.
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import translate_perform as tp  # noqa: E402

SKILLS_DIR = Path('lib/kantele/combat/skills')
PERFORMS_DIR = SKILLS_DIR / 'performs'

LIST_RE = r'[ \t]*def %s\(\) do\n(.*?)\n[ \t]*end\n'
PAIR_RE = re.compile(r'"([^"]+)"\s*=>\s*([A-Za-z0-9_.]+)')
MODULE_RE = re.compile(r'defmodule\s+([\w.]+)\s+do')


def collect_moves(tr, src_root):
    by_output = {}
    for skill_dir in sorted(src_root.iterdir()):
        if not skill_dir.is_dir():
            continue
        for c_file in sorted(skill_dir.rglob('*.c')):
            data = tr.extract(c_file)
            if data is None:
                continue
            rel = f"{tr.skill_dir(data['skill'])}/{data['move']}.ex"
            by_output.setdefault(rel, []).append((tr.source_rank(c_file), c_file, data))
    moves = []
    for rel, cands in by_output.items():
        cands.sort(key=lambda c: -c[0])
        moves.append((rel, cands[0][2]))
    return moves


def disk_module(rel):
    path = PERFORMS_DIR / rel
    if not path.exists():
        return None
    m = MODULE_RE.search(path.read_text(encoding='utf-8', errors='ignore'))
    return m.group(1) if m else None


def parse_pairs(txt, fn):
    m = re.search(LIST_RE % fn, txt, re.S)
    if not m:
        return None
    return m, PAIR_RE.findall(m.group(1))


def render_list(fn, pairs, with_impl):
    lines = []
    if with_impl:
        lines.append("  @impl true")
    lines.append("  def %s() do" % fn)
    lines.append("    %{")
    entries = [f'      "{key}" => {mod}' for key, mod in sorted(pairs)]
    lines.append(",\n".join(entries))
    lines.append("    }")
    lines.append("  end")
    return "\n".join(lines)


def merge_into(txt, fn, new_pairs):
    """Add missing entries to fn's list, creating the fn if absent."""
    if not new_pairs:
        return txt, 0
    found = parse_pairs(txt, fn)
    if found:
        m, pairs = found
        merged = dict(pairs)
        added = 0
        for key, mod in new_pairs:
            if key not in merged:
                merged[key] = mod
                added += 1
        if added == 0:
            return txt, 0
        block = render_list(fn, merged.items(), with_impl=False)
        return txt[:m.start()] + block + "\n" + txt[m.end():], added

    lines = txt.rstrip('\n').split('\n')
    if not lines or lines[-1].strip() != 'end':
        raise RuntimeError('module does not end with a bare `end`')
    block = render_list(fn, new_pairs, with_impl=True)
    new_txt = '\n'.join(lines[:-1]) + '\n\n' + block + '\n' + lines[-1] + '\n'
    return new_txt, len(new_pairs)


def main():
    apply = '--apply' in sys.argv
    tr = tp.TranslatePerform()
    src = Path(os.getenv('KUNGFU_SRC', 'kungfu_source/kungfu/skill'))
    moves = collect_moves(tr, src)

    per_skill = {}
    missing_mod = []
    for rel, data in moves:
        mod = disk_module(rel)
        if mod is None:
            missing_mod.append(rel)
            continue
        per_skill.setdefault(data['skill'], []).append((data['move'], data['kind'], mod))

    edited = 0
    added_total = 0
    skipped_skill = []
    for skill, entries in sorted(per_skill.items()):
        sk_file = SKILLS_DIR / (skill.replace('-', '_') + '.ex')
        if not sk_file.exists():
            skipped_skill.append(skill)
            continue
        txt = sk_file.read_text(encoding='utf-8')
        performs = [(mv, mod) for mv, kind, mod in entries if kind == 'perform']
        exerts = [(mv, mod) for mv, kind, mod in entries if kind == 'exert']
        txt2, a1 = merge_into(txt, 'perform_list', performs)
        txt2, a2 = merge_into(txt2, 'exert_list', exerts)
        added = a1 + a2
        if added:
            edited += 1
            added_total += added
            print(f"{'WRITE' if apply else 'WOULD'} {skill}: +{a1} perform, +{a2} exert")
            if apply:
                sk_file.write_text(txt2, encoding='utf-8', newline='')

    print()
    print(f"skills touched: {edited}, entries added: {added_total}")
    if skipped_skill:
        print(f"skills without module file (skipped): {sorted(skipped_skill)}")
    if missing_mod:
        print(f"moves without on-disk module (skipped): {sorted(missing_mod)}")


if __name__ == '__main__':
    main()

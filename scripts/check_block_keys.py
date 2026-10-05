"""Diff the top-level definition keys of a UCL file between HEAD and the worktree.

Usage: python check_block_keys.py data/world/clone_lib.ucl
"""
import io
import re
import subprocess
import sys

KEY = re.compile(r'^\s*(characters|items|rooms)\s+"([^"]+)"\s*\{', re.M)

path = sys.argv[1]
head = subprocess.check_output(['git', 'show', 'HEAD:' + path]).decode('utf-8')
work = io.open(path, encoding='utf-8').read()


def keys(text):
    out = []
    for m in KEY.finditer(text):
        out.append('%s "%s"' % (m.group(1), m.group(2)))
    return out


h, w = keys(head), keys(work)
hs, ws = set(h), set(w)

print('HEAD blocks   : %d' % len(h))
print('worktree blocks: %d' % len(w))
print()

lost = [k for k in h if k not in ws]
print('== LOST (in HEAD, gone from worktree): %d ==' % len(lost))
for k in lost:
    print('  ' + k)

added = [k for k in w if k not in hs]
print()
print('== ADDED (new in worktree): %d ==' % len(added))
for k in added:
    print('  ' + k)

dups = [k for k in ws if w.count(k) > 1]
print()
print('== DUPLICATED keys in worktree: %d ==' % len(dups))
for k in sorted(set(dups)):
    print('  %s  x%d' % (k, w.count(k)))
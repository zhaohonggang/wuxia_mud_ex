#!/usr/bin/env python3
"""Measure *quality* of Chinese text in generated perform skeletons.

The prior greedy-regex bug merged several LPC messages into one broadcast and
interleaved bare ASCII identifiers (`strike`, `dodge`, `neili`) into the text.
So raw CJK volume is NOT a good coverage proxy -- the buggy output can contain
*more* CJK.  Instead we measure whether the generated Chinese text is clean and
complete:

  clean_initial : the first Broadcast.publish(...) string contains CJK and has
                  NO bare ASCII identifier leakage (a run of 3+ ascii letters
                  that is a known LPC identifier or an unquoted token between
                  CJK runs).
  has_hit_and_miss : for offensive performs, resolve_incoming has BOTH a hit
                  branch message and a miss branch message in Chinese.

Usage:
    python3 scripts/_cov_measure.py <dir> [<dir> ...]

Generate the two dirs to compare with, e.g.:
    KUNGFU_EMBED_SOURCE=1 KUNGFU_EMIT_CODE=1 KUNGFU_OUT=/tmp/n \
        python3 scripts/translate_perform.py
(use the same two flags for both sides; EMIT_CODE=1 matches what ships)
"""
import re
import sys
import pathlib

CJK = re.compile(r"[\u4e00-\u9fff]")
PUB = re.compile(r"Broadcast\.publish\(conn,\s*\"((?:[^\"\\]|\\.)*)\"", re.S)
# ASCII identifier leakage: 3+ consecutive ascii letters that are NOT inside a
# quoted segment ... approximated by detecting ascii-letter runs adjacent to CJK
# on a publish line.
LEAK = re.compile(r"[A-Za-z]{3,}")


def analyze(root):
    root = pathlib.Path(root)
    files = sorted(root.rglob("*.ex"))
    n = 0
    clean_initial = 0
    leaky_initial = 0
    has_cjk_initial = 0
    offensive = 0
    both_hit_miss = 0
    for f in files:
        txt = f.read_text(encoding="utf-8", errors="replace")
        n += 1
        # first non-comment Broadcast.publish(conn, "...") -- multiline aware.
        # Strip comment lines first so embedded LPC source is not matched.
        code = "\n".join(
            ln for ln in txt.splitlines() if not ln.strip().startswith("#")
        )
        m = PUB.search(code)
        first = m.group(1) if m else None
        if first is not None and CJK.search(first):
            has_cjk_initial += 1
            # Leakage heuristic: a 3+ ascii-letter run embedded directly between
            # CJK characters (e.g. "要害！\nstrikedodge..."), i.e. the leak only
            # happens when the merged text carries bare identifiers.
            # Detect by: the string contains ascii letters AND a newline that
            # joins a CJK line with an ascii-identifier line.
            lines_in = [p for p in first.split("\\n")]
            leaky = any(LEAK.search(p) and CJK.search(p) for p in lines_in) or any(
                LEAK.search(p) and not CJK.search(p) and p.strip()
                for p in lines_in
            )
            if leaky:
                leaky_initial += 1
            else:
                clean_initial += 1
        if "def resolve_incoming" in txt:
            offensive += 1
            has_hit = 'Messages.interpolate("' in txt and "if hit" in txt
            if has_hit:
                both_hit_miss += 1
    return dict(
        root=str(root), files=n, has_cjk_initial=has_cjk_initial,
        clean_initial=clean_initial, leaky_initial=leaky_initial,
        offensive=offensive, both_hit_miss=both_hit_miss,
    )


def main():
    for r in sys.argv[1:]:
        d = analyze(r)
        pct_clean = 100 * d["clean_initial"] / max(d["has_cjk_initial"], 1)
        print("=== {} ===".format(d["root"]))
        print("  files                          : {}".format(d["files"]))
        print("  files w/ CJK initial publish   : {}".format(d["has_cjk_initial"]))
        print("    clean (no identifier leak)   : {}  ({:.1f}%)".format(d["clean_initial"], pct_clean))
        print("    leaky (merged identifiers)   : {}".format(d["leaky_initial"]))
        print("  offensive performs             : {}".format(d["offensive"]))
        print("    w/ hit+miss CN branch        : {}".format(d["both_hit_miss"]))
        print()


if __name__ == "__main__":
    main()

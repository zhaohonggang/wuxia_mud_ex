#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Regression runner for scripts/check_room_coords.py.

Mirrors the validate_ucl.py fixture discipline: test/fixtures/check_room_coords/
holds the inputs, expected.json holds the normative expectations (exact exit code
and the exact set of problem / warning messages), and this runner asserts the tool
matches.  The tool must never emit a traceback for any input.

Usage:
  python scripts/test_check_room_coords.py
  python scripts/test_check_room_coords.py data/world/city.ucl   # ad-hoc run
"""

import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
FIXTURES = ROOT / "test" / "fixtures" / "check_room_coords"
TOOL = HERE / "check_room_coords.py"
PROBLEM_PREFIX = "Coords: "
WARNING_PREFIX = "Coords: WARNING: "


def run_tool(path):
    """Invoke the tool in a subprocess and classify its stdout lines."""
    import subprocess
    proc = subprocess.run(
        [sys.executable, str(TOOL), str(path)],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    problems, warnings = [], []
    for line in proc.stdout.splitlines():
        if line.startswith(WARNING_PREFIX):
            warnings.append(line[len(WARNING_PREFIX):])
        elif line.startswith(PROBLEM_PREFIX):
            problems.append(line[len(PROBLEM_PREFIX):])
    return proc.returncode, problems, warnings, proc.stdout, proc.stderr


def check_case(case):
    """Return an error string for a mismatching case, or None when it passes."""
    path = FIXTURES / case["file"]
    if not path.exists():
        return "fixture is missing: %s" % path

    code, problems, warnings, out, err = run_tool(path)

    if "Traceback" in out or "Traceback" in err:
        return "traceback leaked:\n%s%s" % (out, err)

    if code != case["exit_code"]:
        return "exit code %d, expected %d\n    stdout=%s" % (
            code, case["exit_code"], out)

    def compare(kind, got, want):
        missing = [m for m in want if not any(m in g for g in got)]
        if missing:
            return "%s %s not reported; got %s" % (kind, missing, got)
        return None

    for kind, got, want in (("problem", problems, case.get("problems", [])),
                            ("warning", warnings, case.get("warnings", []))):
        bad = compare(kind, got, want)
        if bad:
            return bad + "\n    stdout=%s" % out

    # W1/W2 must never be escalated to problems.
    for problem in problems:
        if problem.startswith("direction/coord mismatch") or " shared by " in problem:
            return "warning was escalated to a problem: %s" % problem

    return None


def main(argv):
    if len(argv) > 1:
        # Ad-hoc mode: just run the tool and echo its verdict.
        for path in argv[1:]:
            code, problems, warnings, _out, _err = run_tool(path)
            print("%s: exit=%d problems=%d warnings=%d"
                  % (path, code, len(problems), len(warnings)))
        return 0

    spec = json.loads((FIXTURES / "expected.json").read_text(encoding="utf-8"))
    failures = 0
    for case in spec["cases"]:
        err = check_case(case)
        if err:
            failures += 1
            print("MISMATCH %s: %s" % (case["file"], err))
        else:
            print("ok  %s" % case["file"])

    total = len(spec["cases"])
    print()
    print("check_room_coords regression: %d cases, %d mismatches"
          % (total, failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

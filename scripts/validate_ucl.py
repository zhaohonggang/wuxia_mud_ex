#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UCL validator (Python port of scripts/validate_ucl.exs, with the three known
.exs defects fixed).

Runs five independent checks over a zone UCL file and reports every failure
(never short-circuits):

  1. Encoding   - raw bytes must be valid UTF-8, no UTF-8 BOM, no UTF-16LE BOM,
                  no CR byte (LF-only).
  2. Syntax     - a hand-written minimal recursive-descent parser covering the
                  subset emitted by scripts/lpc_converter.py.
  3. Structure  - `zones "..."`, `rooms "..."`, `room_exits "..."` must appear.
  4. Integrity  - number of `rooms "..."` must equal `room_exits "..."` and be > 0.
  5. Chars      - no `}` `}` on one line (horizontal whitespace only), no comma
                  before `}`, and an even number of `"` bytes.

Unlike scripts/validate_ucl.exs this never crashes on any input (invalid UTF-8,
truncated files, ...).

Usage:
  python scripts/validate_ucl.py <file.ucl>

Exit codes:
  0  all five checks passed
  1  at least one check failed, or the file could not be read
  2  wrong number of arguments (usage printed to stderr)
"""

import re
import sys

# ---------------------------------------------------------------------------
# Check names, in fixed report order.
# ---------------------------------------------------------------------------
CHECK_ORDER = ["Encoding", "Syntax", "Structure", "Integrity", "Chars"]

# ---------------------------------------------------------------------------
# Structure / Integrity / Chars work on the raw bytes (ASCII patterns), so they
# stay meaningful even when the file is not valid UTF-8.  For byte patterns
# `\s` / `\w` are ASCII-only, matching Elixir's PCRE without /u.
# ---------------------------------------------------------------------------
_STRUCT_ZONE_RE = re.compile(rb'^\s*zones\s+"\w+"', re.MULTILINE)
_STRUCT_ROOMS_RE = re.compile(rb'^\s*rooms\s+"\w+"', re.MULTILINE)
_STRUCT_EXITS_RE = re.compile(rb'^\s*room_exits\s+"\w+"', re.MULTILINE)

_INTEGRITY_ROOMS_RE = re.compile(rb'^\s*rooms\s+"(\w+)"', re.MULTILINE)
_INTEGRITY_EXITS_RE = re.compile(rb'^\s*room_exits\s+"(\w+)"', re.MULTILINE)

# Chars: horizontal whitespace [ \t], NOT \s (that was the .exs defect).
_CHARS_DOUBLE_BRACE_RE = re.compile(rb'^[ \t]*}[ \t]*}', re.MULTILINE)
_CHARS_TRAILING_COMMA_RE = re.compile(rb',[ \t]*}', re.MULTILINE)


# ---------------------------------------------------------------------------
# Output helpers: UTF-8 bytes plus a single LF (never CRLF on Windows).
# ---------------------------------------------------------------------------
def _out(text):
    sys.stdout.buffer.write((text + "\n").encode("utf-8"))
    sys.stdout.buffer.flush()


def _err(text):
    sys.stderr.buffer.write((text + "\n").encode("utf-8"))
    sys.stderr.buffer.flush()


# ---------------------------------------------------------------------------
# 1. Encoding
# ---------------------------------------------------------------------------
def check_encoding(data):
    violations = []
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        violations.append("not valid UTF-8")
    if data.startswith(b"\xef\xbb\xbf"):
        violations.append("UTF-8 BOM not allowed")
    if data.startswith(b"\xff\xfe"):
        violations.append("UTF-16LE BOM not allowed")
    if b"\r" in data:
        violations.append("CR found, LF-only required")

    if violations:
        return (False, "; ".join(violations))
    return (True, None)


# ---------------------------------------------------------------------------
# 2. Syntax: minimal recursive-descent UCL parser.
#
# Grammar subset (as emitted by scripts/lpc_converter.py):
#   document  := block*
#   block     := IDENT STRING? '{' members '}'
#   members   := ( IDENT '=' value )*
#   value     := STRING | NUMBER/bare-ident | array | inline-object
#   array     := '[' ( value (',' value)* ','? )? ']'
#   object    := '{' members '}'
# Comments are '#' to end of line.  A closing brace may be glued to a value.
# ---------------------------------------------------------------------------
class UCLSyntaxError(Exception):
    def __init__(self, line, message):
        super().__init__(message)
        self.line = line
        self.message = message


_WHITESPACE = " \t\r\f\v"
_SPECIAL = set('{}[]=,"#')


class _Scanner:
    def __init__(self, text):
        self.s = text
        self.i = 0
        self.n = len(text)
        self.line = 1

    def _skip_ws(self):
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\n":
                self.line += 1
                self.i += 1
            elif c in _WHITESPACE:
                self.i += 1
            elif c == "#":
                while self.i < self.n and self.s[self.i] != "\n":
                    self.i += 1
            else:
                return

    def peek(self):
        self._skip_ws()
        if self.i >= self.n:
            return None
        return self.s[self.i]

    def at_end(self):
        self._skip_ws()
        return self.i >= self.n

    def expect(self, ch):
        self._skip_ws()
        if self.i >= self.n or self.s[self.i] != ch:
            raise UCLSyntaxError(self.line, "expected '%s'" % ch)
        self.i += 1

    def read_bare(self, what):
        self._skip_ws()
        start = self.i
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\n" or c in _WHITESPACE or c in _SPECIAL:
                break
            self.i += 1
        if self.i == start:
            raise UCLSyntaxError(self.line, "expected %s" % what)
        return self.s[start:self.i]

    def read_string(self):
        self._skip_ws()
        if self.i >= self.n or self.s[self.i] != '"':
            raise UCLSyntaxError(self.line, "expected string")
        self.i += 1
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\":
                self.i += 1
                if self.i < self.n:
                    if self.s[self.i] == "\n":
                        self.line += 1
                    self.i += 1
                continue
            if c == '"':
                self.i += 1
                return
            if c == "\n":
                raise UCLSyntaxError(self.line, "unterminated string")
            self.i += 1
        raise UCLSyntaxError(self.line, "unterminated string")


def _parse_block(sc):
    sc.read_bare("block name")
    if sc.peek() == '"':
        sc.read_string()
    sc.expect("{")
    _parse_members(sc)
    sc.expect("}")


def _parse_members(sc):
    while True:
        ch = sc.peek()
        if ch is None:
            raise UCLSyntaxError(sc.line, "unexpected end of file, missing '}'")
        if ch == "}":
            return
        sc.read_bare("member key")
        sc.expect("=")
        _parse_value(sc)
        # Elias UCL does NOT accept commas between members of an inline mapping.
        # Only top-level block members and array elements may be comma-separated.
        # We deliberately do NOT consume a trailing ',' here.


def _parse_value(sc):
    ch = sc.peek()
    if ch is None:
        raise UCLSyntaxError(sc.line, "unexpected end of file, expected value")
    if ch == '"':
        sc.read_string()
    elif ch == "[":
        _parse_array(sc)
    elif ch == "{":
        sc.expect("{")
        _parse_members(sc)
        sc.expect("}")
    else:
        sc.read_bare("value")


def _parse_array(sc):
    sc.expect("[")
    while True:
        ch = sc.peek()
        if ch is None:
            raise UCLSyntaxError(sc.line, "unexpected end of file, missing ']'")
        if ch == "]":
            sc.expect("]")
            return
        _parse_value(sc)
        ch = sc.peek()
        if ch == ",":
            sc.expect(",")
        elif ch == "]":
            sc.expect("]")
            return
        else:
            raise UCLSyntaxError(sc.line, "expected ',' or ']'")


def _parse_document(text):
    sc = _Scanner(text)
    # A leading UTF-8 BOM decodes to U+FEFF; Elias parses such files, so accept it.
    if sc.i < sc.n and sc.s[sc.i] == "\ufeff":
        sc.i += 1
    while not sc.at_end():
        _parse_block(sc)


def _line_of_offset(data, offset):
    return data[:offset].count(b"\n") + 1


def check_syntax(data):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        line = _line_of_offset(data, exc.start)
        return (False, "cannot decode as UTF-8 (line %d)" % line)

    try:
        _parse_document(text)
    except UCLSyntaxError as exc:
        return (False, "%s (line %d)" % (exc.message, exc.line))
    except RecursionError:
        return (False, "nesting too deep (line 1)")
    except Exception as exc:  # never leak a traceback
        return (False, "parse error: %s" % exc)
    return (True, None)


# ---------------------------------------------------------------------------
# 3. Structure
# ---------------------------------------------------------------------------
def check_structure(data):
    missing = []
    if not _STRUCT_ZONE_RE.search(data):
        missing.append("zones")
    if not _STRUCT_ROOMS_RE.search(data):
        missing.append("rooms")
    if not _STRUCT_EXITS_RE.search(data):
        missing.append("room_exits")
    if missing:
        return (False, "missing " + ", ".join(missing))
    return (True, None)


# ---------------------------------------------------------------------------
# 4. Integrity
# ---------------------------------------------------------------------------
def check_integrity(data):
    rooms = len(_INTEGRITY_ROOMS_RE.findall(data))
    exits = len(_INTEGRITY_EXITS_RE.findall(data))
    if rooms == exits and rooms > 0:
        return (True, None)
    if rooms == 0:
        return (False, "no rooms defined")
    return (False, "rooms(%d) != room_exits(%d)" % (rooms, exits))


# ---------------------------------------------------------------------------
# 5. Chars
# ---------------------------------------------------------------------------
def check_chars(data):
    issues = []
    if _CHARS_DOUBLE_BRACE_RE.search(data):
        issues.append("double closing brace")
    if _CHARS_TRAILING_COMMA_RE.search(data):
        issues.append("trailing comma before }")
    if data.count(b'"') % 2 != 0:
        issues.append("unpaired double quote")
    if issues:
        return (False, "; ".join(issues))
    return (True, None)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
def _run_checks(data):
    # Structure/Integrity/Chars search line-anchored patterns; a leading UTF-8
    # BOM would sit before `zones` on line 1 and hide it.  The BOM itself is
    # still reported by the Encoding check, so strip it for the others.
    body = data[3:] if data.startswith(b"\xef\xbb\xbf") else data

    checks = [
        ("Encoding", check_encoding, data),
        ("Syntax", check_syntax, data),
        ("Structure", check_structure, body),
        ("Integrity", check_integrity, body),
        ("Chars", check_chars, body),
    ]
    failures = []
    for name, fn, payload in checks:
        try:
            ok, detail = fn(payload)
        except Exception as exc:  # a check must never crash the tool
            ok, detail = False, "internal error: %s" % exc
        if not ok:
            failures.append((name, detail))
    return failures


def main(argv):
    if len(argv) != 1:
        _err("usage: python scripts/validate_ucl.py <file.ucl>")
        return 2

    path = argv[0]
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        _err("\u274c IO: cannot read %s" % path)
        return 1

    failures = _run_checks(data)

    if not failures:
        _out("\u2705 All checks passed: %s" % path)
        return 0

    for name, detail in failures:
        _out("\u274c %s: %s" % (name, detail))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LPC -> UCL Converter (Python port of lib/kantele/world/lpc_converter.ex + mix task).

Byte-exact port of the Elixir implementation (T1). Converts LPC source files
(.c) to UCL format compatible with Kantele.World.Loader, preserving logic
content as comments.

Usage (mirrors the mix task recursive mode):
  python scripts/lpc_converter.py PATH [--zone ZONE] [--output DIR]
      PATH may be a single .c file or a directory (recursive, all **/*.c)
"""

import os
import re
import sys
from pathlib import Path

# lpc_paths holds the LPC ground-truth helpers (path expansion, and the
# authoritative npc-vs-item verdict).  It imports this module lazily inside
# resolve_type, so the dependency only ever runs one way at call time.  The
# sys.path line keeps that working when this file is loaded by absolute path
# from another script rather than run from scripts/.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpc_paths as LP  # noqa: E402

# ---------------------------------------------------------------------------
# ASCII semantics: Elixir PCRE (no /u) treats \w \s \d as ASCII-only.  Python
# re treats them as Unicode by default.  All patterns in this module use the
# re.ASCII flag unless they explicitly need Unicode (Chinese text).
# ---------------------------------------------------------------------------
_A = re.ASCII

# ---------------------------------------------------------------------------
# Regex helpers (faithful to the Elixir regexes, which are all ASCII-flavoured)
# ---------------------------------------------------------------------------

# strip_heredocs_for_brace: set("key", @DELIM ... DELIM); -> set("key", "");
_HEREDOC_PLACEHOLDER = re.compile(
    r'set\s*\(\s*(["\'])([^"\']+)\1\s*,\s*@(\w+)\s*\n[\s\S]*?\n\3\s*\)\s*;'
)

# parse_heredocs_from_raw: capture the heredoc content
_HEREDOC_RAW = re.compile(
    r'set\s*\(\s*(["\'])([^"\']+)\1\s*,\s*@(\w+)\s*\n([\s\S]*?)\n\3\s*\)\s*;'
)

_C_COMMENT = re.compile(r"/\*[\s\S]*?\*/")
_CPP_LINE_COMMENT = re.compile(r"//.*")

_CREATE_SIG = re.compile(r"void\s+create\s*\(\s*\)\s*\{")
# The operand may be a bare marker (ROOM), a quoted path ("/inherit/char/x.c"),
# or an expression that concatenates quoted parts:
#     __DIR__"underlt"                     (city/wudao1.c, macro-inherits a room)
#     CLASS_D("generate") + "/chinese"     (room/roomnpc/shouwei.c)
# The previous pattern used ([^;"']+) for the operand, which cannot match either
# expression form: it stops at the first quote, so `inherit __DIR__"underlt";`
# yielded an EMPTY inherit list, _determine_object_type/2 then saw no ROOM marker,
# classified the file as "generic" and emitted an empty .ucl - silently dropping
# the room from the zone (4 rooms in city, 1 in room; 11 files in total).
# The operand is therefore "the rest of the line", quotes included, and the
# leading quote group is kept so group(2) still addresses the operand.  It must
# not span newlines: an `inherit` with no terminating semicolon would otherwise
# make [^;]+ swallow the rest of the file and break parsing everywhere.
_INHERIT = re.compile(r'inherit\s+(["\']?)([^;\n]+)\1\s*;')
_DEFINE = re.compile(r"#\s*define\s+([A-Za-z_]\w*)\s+([^\s;()]+)")
_DIR_STR = re.compile(r'^\s*__DIR__\s*["\']([^"\']+)["\']\s*$')
_QUOTED_STR = re.compile(r'^["\']([^"\']+)["\']\s*$')

_SET_CALL = re.compile(r'set\s*\(\s*(["\'])([^"\']+)\1\s*,\s*([\s\S]*?)\s*\)\s*;', re.M)
_SET_NAME = re.compile(
    r'set_name\s*\(\s*(?:[A-Z_]+)?\s*(["\'])([^"\']+)\1\s*(?:[A-Z_]+)?\s*,\s*\(\s*\{([^}]+)\}\s*\)\s*\)\s*;'
)
# 宽松版：名字参数允许 `NOR + WHT "干粮" NOR` 这种 ANSI 常量拼接表达式。
# 第一组是名字表达式（到第一个顶层逗号），第二组是别名表内容。
_SET_NAME_LOOSE = re.compile(
    r'set_name\s*\(\s*((?:[A-Z_]+\s*\+?\s*)*(?:"[^"]*"|\'[^\']*\')(?:\s*\+?\s*(?:[A-Z_]+|"[^"]*"|\'[^\']*\'))*)\s*,\s*\(\s*\{([^}]+)\}\s*\)\s*\)\s*;'
)
_DIRECT_ASSIGN = re.compile(r"(\w+)\s*=\s*([^;]+);")
_FUNC_CALL = re.compile(r"(\w+)\s*\(([^)]*)\)\s*(?:->\s*\w+\s*\(\s*\))?\s*;")
_OTHER_FN = re.compile(r"(int|string|void|mapping|object)\s+(\w+)\s*\([^)]*\)")
_GLOBAL_DECL = re.compile(r"(int|string|mapping|object|mixed)\s+(\w+)\s*[=;]")
_COMPLEX_GLOBAL = re.compile(r"(int|string|mapping|object|mixed)\s+(\w+)\s*=\s*[^;]+;")
_COMPLEX_MAPPING = re.compile(r"\(\s*\[[^]]*\[[^]]*\]")
_SWITCH_STMT = re.compile(r'switch\s*\(\s*[^()]*(?:\([^()]*\)[^()]*)*\)\s*\{[\s\S]*?\}', re.M)
_SWITCH_TABLE_ROW = re.compile(r'case\s+["\']([^"\']+)["\']\s*:\s*([\s\S]*?)(?=case\s+["\']|default\s*:)')
_SWITCH_TABLE_COL = re.compile(r"(\w+)\s*=\s*([^;]+);")
_IF_ELSE_BLOCK = re.compile(r'if\s*\([^)]+\)\s*\{[\s\S]*?\}\s*else\s*\{[\s\S]*?\}', re.M)
_RAW_BLOCK = re.compile(r"(void|int)\s+(heart_beat|reset|clean_up)\s*\([^)]*\)\s*\{([\s\S]*?)\}", re.M)
_BODY_SIG = re.compile(r"(?:int|string|void|mixed|mapping|object|protected)\s+(\w+)\s*\([^)]*\)\s*\n*\s*\{")
_FN_SIG = re.compile(r"(?:int|string|void|mixed|mapping|object|protected)\s+{name}\s*\([^)]*\)\s*\n*\s*\{{")

_BRANCH_ACTION = re.compile(r"(command|say|tell_object|message_vision|write)\s*\([\s\S]*?\);")
_WS_RE = re.compile(r"\s+", _A)

# valid_leave
_VALID_LEAVE_SIG = re.compile(r"int\s+valid_leave\s*\([^)]*\)\s*\{")
_PRESENT = re.compile(r'present\s*\(\s*(["\'])([^"\']+)\1\s*,\s*this_object\s*\(\s*\)')
_DIR_EQ = re.compile(r'dir\s*==\s*(["\'])([^"\']+)\1')

# greeting / dialogue
_DIALOGUE_CALL = re.compile(r"(?:say|message_vision)\s*\(([\s\S]*?)\)\s*;", re.M)
_STR_TOKEN = re.compile(r'("(?:[^"\\]|\\.)*")')
_STR_LITERAL = re.compile(r'"((?:\\.|[^"\\])*)"')

# accept_object
_ACCEPT_DIALOGUE_TELL = re.compile(r"tell_object\s*\([^)]+\)")
_ACCEPT_CMD_SAY = re.compile(r'command\s*\(\s*["\']say\s+([^"\']+)["\']\s*\)')
_ACCEPT_CMD_OTHER = re.compile(r'command\s*\(\s*["\']([^"\']+)["\']\s*\)')
_MESSAGE_CALL = re.compile(r"message_(?:vision|sort)\s*\(")
_SAY_CALL = re.compile(r"(?<!\w)say\s*\(")
_NOTIFY_FAIL_CALL = re.compile(r"notify_fail\s*\(")
_WRITE_CALL = re.compile(r"write\s*\(")
_MONEY_ID = re.compile(r"->value\s*\(\s*\)\s*>=\s*(\d+)")
_ITEM_ID_QUERY = re.compile(r'(\w+->)?query\s*\(\s*["\']id["\']\s*\)\s*==\s*["\']([^"\']+)["\']')
_ITEM_NAME_QUERY = re.compile(r'(\w+->)?query\s*\(\s*["\']name["\']\s*\)\s*==\s*["\']([^"\']+)["\']')
_RETURN_01 = re.compile(r"return\s+([01])\s*;")

# engage
_ENGAGE_KIND = re.compile(r"::\s*accept_(fight|hit|kill)\s*\(")
_KILL_OB = re.compile(r"(?<!->)kill_ob\s*\(")
_SPAWN_NEW = re.compile(r'new\s*\(\s*(?:__DIR__)?\s*["\']([^"\']+)["\']\s*\)')
_CMD_SAY = re.compile(r'command\s*\(\s*["\']say\s+([^"\']+)["\']\s*\)')
_MESSAGE_VISION_LIT = re.compile(r'message_vision\s*\(\s*((?:"(?:\\.|[^"\\])*"\s*)+)')

# guard
_GUARD_FAMILY = re.compile(r'query\s*\(\s*["\']family/family_name["\']\s*\)\s*==\s*["\']([^"\']+)["\']')
_GUARD_REFUSE = re.compile(r'message_vision\s*\(\s*["\']([^"\']+)["\']')

# init
_ADD_ACTION = re.compile(r'add_action\s*\(\s*["\']([^"\']+)["\']\s*,\s*["\']([^"\']+)["\']\s*\)')
_CALL_OUT_GREET = re.compile(r'call_out\s*\(\s*["\']greeting["\']\s*,\s*(\d+)')
_HEARTBEAT = re.compile(r"set_heart_beat\s*\(\s*(\d+)")

# item_desc
_MACRO_STRING = re.compile(r'"((?:\\.|[^"\\])*)"')
_WS_COLLAPSE = re.compile(r"\s+", _A)

# exit veto / unhandled helpers
_NOTIFY_FAIL_WORD = re.compile(r"notify_fail")

# sanitize regexes
_ESC_SEQ = re.compile(r"\\([a-zA-Z])")
_TRAILING_QUOTE = re.compile(r"\\?[\"\']\s*$")
_TRAILING_SEMI = re.compile(r";+\s*$")

# LPC string/heredoc line continuation: a backslash at end of line means the
# string continues on the next line with no separator.
_LPC_CONTINUATION = re.compile(r"\\[ \t]*\r?\n")


def _ascii_ws_collapse(s):
    return _WS_RE.sub(" ", s)


def _trim(s):
    return s.strip() if s is not None else None


def _path_basename_rootname(p):
    """Path.basename |> Path.rootname (strip last extension)."""
    base = os.path.basename(p)
    return os.path.splitext(base)[0]


def _norm_id(s):
    """String.replace("-", "_")"""
    return s.replace("-", "_")


def _to_utf8(data: bytes) -> str:
    """Mirror :unicode.characters_to_binary GBK-first logic."""
    # GBK first
    try:
        return data.decode("gbk")
    except (UnicodeDecodeError, LookupError):
        pass
    # then UTF-8
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        pass
    # replacement fallback
    return data.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# AST representation (mirrors the Elixir maps)
# ---------------------------------------------------------------------------
class AST:
    def __init__(self, **kw):
        self.inherits = kw.get("inherits", [])
        self.inherit_files = kw.get("inherit_files", [])
        self.create_fn = kw.get("create_fn", {})
        self.other_fns = kw.get("other_fns", [])
        self.globals = kw.get("globals", {})
        self.heredocs = kw.get("heredocs", {})
        self.source_path = kw.get("source_path", "")
        self.base_path = kw.get("base_path", ".")
        self.valid_leave = kw.get("valid_leave", None)
        self.exit_vetoes = kw.get("exit_vetoes", [])
        self.function_calls = kw.get("function_calls", {})
        self.enter = kw.get("enter", None)
        self.greetings = kw.get("greetings", None)
        self.accept = kw.get("accept", None)
        self.guard = kw.get("guard", None)
        self.engage = kw.get("engage", None)
        self.unhandled = kw.get("unhandled", {
            "functions": [], "globals": [], "complex_mappings": [],
            "switch_tables": [], "switch_statements": [], "switch_pools": [],
            "conditional_branches": {}, "complex_conditionals": [],
            "raw_code_blocks": [],
        })

    def __repr__(self):
        return f"AST(source_path={self.source_path})"


# ---------------------------------------------------------------------------
# Low-level character-stream helpers (port of the Elixir char-list scanners)
# ---------------------------------------------------------------------------
def _is_ident(c):
    return c == "_" or ("a" <= c <= "z") or ("A" <= c <= "Z") or ("0" <= c <= "9")


def _word_at(chars, i, w):
    """True when w occurs as a whole word at index i."""
    wlen = len(w)
    if i < 0 or i + wlen > len(chars):
        return False
    if chars[i:i + wlen] != list(w):
        return False
    if i > 0 and _is_ident(chars[i - 1]):
        return False
    if i + wlen < len(chars) and _is_ident(chars[i + wlen]):
        return False
    return True


def _skip_string(chars, i):
    """Skip a double-quoted string (with escapes); return index after closing quote."""
    i = i + 1
    escaped = False
    while i < len(chars):
        c = chars[i]
        if c == "\\" and not escaped:
            escaped = True
        elif c == '"' and not escaped:
            return i + 1
        else:
            escaped = False
        i += 1
    return None


def _skip_line_comment(chars, i):
    while i < len(chars):
        if chars[i] == "\n":
            return i + 1
        i += 1
    return i


def _skip_block_comment(chars, i):
    while i < len(chars):
        if chars[i] == "*" and i + 1 < len(chars) and chars[i + 1] == "/":
            return i + 2
        i += 1
    return i


def _skip_trivia(chars, i):
    """Skip whitespace / // / /* */ ; return index of next substantive char."""
    while i < len(chars):
        c = chars[i]
        if c in " \t\n\r":
            i += 1
        elif c == "/":
            if i + 1 < len(chars) and chars[i + 1] == "/":
                i = _skip_line_comment(chars, i + 2)
            elif i + 1 < len(chars) and chars[i + 1] == "*":
                i = _skip_block_comment(chars, i + 2)
            else:
                return i
        else:
            return i
    return None


def _read_ident(chars, i):
    acc = []
    while i < len(chars):
        c = chars[i]
        if _is_ident(c):
            acc.append(c)
            i += 1
        else:
            break
    return "".join(acc), i


def _next_word(chars, i):
    """Return (word, start, end) or None."""
    j = _skip_trivia(chars, i)
    if j is None:
        return None
    c = chars[j]
    if c == '"':
        k = _skip_string(chars, j)
        if k is None:
            return None
        return ("<str>", j, k)
    if _is_ident(c):
        w, k = _read_ident(chars, j)
        return (w, j, k)
    return ("", j, j + 1)


def _match_delim(chars, i, open_c, close_c, depth):
    """Balance open/close, skipping strings/comments; return closing index."""
    while i < len(chars):
        c = chars[i]
        if c == '"':
            k = _skip_string(chars, i)
            if k is None:
                return None
            i = k
        elif c == "/":
            if i + 1 < len(chars) and chars[i + 1] == "/":
                i = _skip_line_comment(chars, i + 2)
            elif i + 1 < len(chars) and chars[i + 1] == "*":
                i = _skip_block_comment(chars, i + 2)
            else:
                i += 1
        elif c == open_c:
            depth += 1
            i += 1
        elif c == close_c:
            if depth == 1:
                return i
            depth -= 1
            i += 1
        else:
            i += 1
    return None


# ---------------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------------
def _strip_c_comments(text):
    return _C_COMMENT.sub("", text)


def _strip_cpp_comments(text):
    out = []
    for line in text.split("\n"):
        parts = _CPP_LINE_COMMENT.split(line, maxsplit=1)
        out.append(parts[0] if len(parts) > 1 else line)
    return "\n".join(out)


def _normalize_whitespace(text):
    return _WS_RE.sub(" ", text).strip()


def _preprocess(content):
    return _normalize_whitespace(_strip_c_comments(_strip_cpp_comments(content)))


def _strip_heredocs_for_brace(content):
    return _HEREDOC_PLACEHOLDER.sub(lambda m: f'set("{m.group(2)}", "");', content)


def _parse_heredocs_from_raw(content):
    heredocs = {}
    for m in _HEREDOC_RAW.finditer(content):
        key = m.group(2)
        delimiter = m.group(3)
        raw = m.group(4)
        # strip trailing quote / semicolon leaks
        cleaned = raw.strip()
        cleaned = _TRAILING_QUOTE.sub("", cleaned)
        cleaned = _TRAILING_SEMI.sub("", cleaned)
        cleaned = cleaned.strip()
        # LPC line continuation: a backslash at end of line joins the next line.
        # mingjiao/miaorenbuluo.c ends a @TEXT line with "口\" and continues on
        # the next line, so the backslash must go - leaving it in place yields
        # `口\ 中`, and elias cannot lex a backslash followed by whitespace
        # (elias_parser.yrl has only `words -> back_slash word words` and
        # `words -> back_slash quotes words`).
        cleaned = _LPC_CONTINUATION.sub("", cleaned)
        # literal " -> ' (elias safety)
        cleaned = cleaned.replace('"', "'")
        heredocs[key] = {"type": "heredoc", "delimiter": delimiter, "content": cleaned}
    return {"heredocs": heredocs}


# ---------------------------------------------------------------------------
# Brace matching
# ---------------------------------------------------------------------------
def _find_quote_end(content, start):
    i = start
    while i < len(content):
        c = content[i]
        if c == "\\":
            i += 2
        elif c == '"':
            return i + 1
        else:
            i += 1
    return None


def _find_matching_brace(content, start_index):
    """start_index = position of opening {. Returns body between braces or None."""
    i = start_index + 1
    brace_count = 1
    while i < len(content):
        c = content[i]
        if c == "{":
            brace_count += 1
            i += 1
        elif c == "}":
            brace_count -= 1
            if brace_count == 0:
                return content[start_index + 1:i]
            i += 1
        elif c == '"':
            new_i = _find_quote_end(content, i + 1)
            if new_i is None:
                return None
            i = new_i
        else:
            i += 1
    return None


def _extract_create_body(content):
    m = _CREATE_SIG.search(content)
    if m is None:
        return ""
    start_pos = m.end() - 1  # position of '{'
    body = _find_matching_brace(content, start_pos)
    return body if body is not None else ""


# ---------------------------------------------------------------------------
# Parse layer
# ---------------------------------------------------------------------------
def _parse_lpc_value(value_str):
    value_str = value_str.strip()

    # A runtime-picked path must survive as one unit.  `__DIR__"shulin" +
    # (random(8) + 6)` would otherwise be treated as a plain string by the
    # `__DIR__"..."` handling below, and _parse_lpc_string would keep only the
    # quoted part - silently turning the exit into a reference to a room named
    # `shulin`, which does not exist.  Hand the whole text to the caller as a var
    # so _classify_exit_path/_split_runtime_suffix can expand the candidates.
    #
    # Deliberately narrow: only concatenations naming `random(`, which have a
    # determinate candidate set.  A bare variable concatenation such as
    # changan/npc/fujiang.c's `carry_object(__DIR__"obj/" + weapon_file)` must
    # keep the previous behaviour (truncate to the quoted prefix, then skip the
    # unresolvable id) - letting it through would emit `items. + weapon_file.id`
    # into the UCL, which is not even valid syntax.
    if _RUNTIME_PATH_RE.match(value_str):
        return ("var", value_str)

    # color-macro wrapped string: HIW "δ����" NOR
    if re.match(r"^[A-Z_]+", value_str, _A):
        extracted = _extract_strings_from_macro_wrapped(value_str)
        if extracted != "":
            return ("string", extracted)

    if value_str.startswith('"') and value_str.endswith('"'):
        return ("string", _parse_lpc_string(value_str))

    if re.fullmatch(r"\d+", value_str, _A):
        return ("int", int(value_str))

    if re.fullmatch(r"\d+\.\d+", value_str, _A):
        return ("float", float(value_str))

    if value_str.startswith("({") and value_str.endswith("})"):
        inner = value_str[2:-2]
        return ("array", _parse_array_elements(inner))

    if value_str.startswith("([") and value_str.endswith("])"):
        inner = value_str[2:-2]
        return ("mapping", _parse_mapping_pairs(inner))

    if re.fullmatch(r"\w+\(.*\)", value_str, _A):
        return ("call", value_str)

    return ("var", value_str)


def _extract_strings_from_macro_wrapped(value_str):
    segs = [_process_lpc_escapes(m.group(1)) for m in _STR_LITERAL.finditer(value_str)]
    return _sanitize_ucl_sval("".join(segs))


def _parse_lpc_string(value_str):
    segs = [_process_lpc_escapes(m.group(1)) for m in _STR_LITERAL.finditer(value_str)]
    return "".join(segs)


def _process_lpc_escapes(s):
    s = s.replace("\\n", "\n")
    s = s.replace("\\t", "\t")
    s = s.replace("\\r", "\r")
    s = s.replace('\\"', '"')
    s = s.replace("\\'", "'")
    s = s.replace("\\\\", "\\")
    return s


def _process_literal_string(s):
    return _process_lpc_escapes(s).replace("$N", "{npc}").replace("$n", "{name}").strip()


def _parse_array_elements(inner):
    inner = _strip_cpp_comments(inner)
    out = []
    for part in _split_top_level(inner):
        out.append(_parse_lpc_value(part))
    return out


def _parse_mapping_pairs(inner):
    # C++ line comments inside a mapping (e.g. `d/jueqing/house.c`'s `//`) hang
    # around in the raw branch text and, because a comment can contain ":" --
    # `//...:) by xxx` -- they poisoned pair.split(":", 1) into bogus (var, var)
    # keys before the no-colon guard at the bottom got a chance to drop them.
    # Strip every line tail at the source so a comment never becomes a pair.
    inner = _strip_cpp_comments(inner)
    pairs = []
    for pair in _split_top_level(inner):
        parts = pair.split(":", 1)
        if len(parts) == 2:
            pairs.append((_parse_lpc_value(parts[0].strip()), _parse_lpc_value(parts[1].strip())))
            continue
        # No ":" at all.  A bare C comment left over from the previous line
        # (e.g. `"south" : __DIR__"xiaoyuan",   /* EXAMPLE */` in
        # room/caihong/dating.c) lands here and used to be turned into the pair
        # (comment, nil), which then rendered as ` = rooms.nil.id` - a UCL
        # syntax error.  Comments carry no mapping data, so drop them.  An
        # explicit LPC `nil` value still parses as a real pair via the ":"
        # branch above.
        stripped = pair.strip()
        if not stripped or stripped.startswith(("/*", "//", "*")):
            continue
        pairs.append((_parse_lpc_value(stripped), ("var", "nil")))
    return pairs


def _split_top_level(inner):
    """Split on commas that sit outside any bracket, paren, brace or string.

    A plain ``inner.split(",")`` shreds a nested mapping such as the portal
    descriptor in ``city/mudren.c``::

        "enter" : ([ "filename" : _DIR_AREA_"world.c",
                     "x_axis" : 75,
                     "y_axis" : 69
                ])

    into three bogus sibling pairs, so the inner keys leaked out as exits of
    the enclosing room.  Only top-level commas separate entries.
    """
    parts = []
    cur = []
    depth = 0
    i = 0
    n = len(inner)
    while i < n:
        c = inner[i]
        if c == '"':
            j = _skip_string(inner, i)
            if j is None:  # unterminated: take the rest verbatim
                cur.append(inner[i:])
                i = n
                break
            cur.append(inner[i:j])
            i = j
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth = max(depth - 1, 0)
        if c == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    parts.append("".join(cur))
    return [p.strip() for p in parts if p.strip() != ""]


def _parse_set_calls(body):
    sets = {}
    for m in _SET_CALL.finditer(body):
        key = m.group(2)
        value = _parse_lpc_value(m.group(3).strip())
        sets[key] = value
    return {"sets": sets}


def _word_before(text, i):
    """The bare identifier ending at index i (exclusive)."""
    j = i
    while j > 0 and (text[j - 1].isalnum() or text[j - 1] == "_"):
        j -= 1
    return text[j:i]


def _keyword_before_paren(text, close_paren):
    """Resolve the `)` at close_paren back to its `(` and report the keyword."""
    depth = 0
    j = close_paren
    while j >= 0:
        if text[j] == ")":
            depth += 1
        elif text[j] == "(":
            depth -= 1
            if depth == 0:
                break
        j -= 1
    if j < 0:
        return None
    k = j
    while k > 0 and text[k - 1] in " \t\r\n":
        k -= 1
    return _word_before(text, k)


def _governing_branch(body, pos):
    """What governs the statement at pos: 'branch', 'top', or 'unknown'.

    LPC allows a braceless body, so `if (random(1000) > 998)\n\tset(...)` is
    perfectly normal and brace depth cannot see it -- we look at the token in
    front of the statement instead.
    """
    i = pos
    while i > 0 and body[i - 1] in " \t\r\n":
        i -= 1
    if i == 0:
        return "unknown"

    ch = body[i - 1]
    if ch == ")":
        kw = _keyword_before_paren(body, i - 1)
        return "branch" if kw in ("if", "while", "for", "switch") else "top"

    if ch == "{":
        # Directly inside a braced block.  Work out what opened it: `else {`,
        # `if (...) {`, or the function body's own brace (which governs nothing).
        k = i - 1
        while k > 0 and body[k - 1] in " \t\r\n":
            k -= 1
        if k > 0 and body[k - 1] == ")":
            kw = _keyword_before_paren(body, k - 1)
            return "branch" if kw in ("if", "while", "for", "switch") else "top"
        if _word_before(body, k) == "else":
            return "branch"
        return "unknown"

    if _word_before(body, i) == "else":
        # A braceless `else` body: the character in front of the statement is the
        # `e` of `else`, not a delimiter.
        return "branch"

    if ch in ";}":
        # Preceded by the end of the previous statement, or by the closing brace
        # of a sibling branch with no `else` between -- either way unconditional.
        return "top"

    return "unknown"


def _parse_object_branches(body):
    """Every branch of a guarded ``set("objects")`` chain, or None.

    ``set("objects", ...)`` REPLACES the property, so a room that does

        set("objects", ([ "npc/yapu" : 2 ]));
        if (random(10) > 5)
                set("objects", ([ "/d/wudu/obj/tongpai" : 1 ]));

    ends up holding *either* yapu *or* tongpai -- never both.  ``_parse_set_calls``
    keeps the last mapping, which for ``taohua/mushi`` meant the ~10% branch won
    every boot and the three rare drops were unreachable.

    Returns one parsed mapping per branch, or None to mean "this is a plain
    sequential overwrite, last-wins is already right" -- callers must fall back
    rather than guess.  The test is deliberately narrow: only when the FINAL
    ``set("objects")`` is itself guarded.  If the last one is unconditional it
    overwrites whatever the branches did, so the branches are unreachable and
    keeping just the last mapping is the faithful answer.
    """
    hits = [m for m in _SET_CALL.finditer(body) if m.group(2) == "objects"]
    if len(hits) < 2:
        return None

    guards = [_governing_branch(body, m.start()) for m in hits]
    if any(g == "unknown" for g in guards):
        return None
    if guards[-1] != "branch":
        return None

    return [_parse_lpc_value(m.group(3).strip()) for m in hits]


def _parse_set_name(body):
    m = _SET_NAME.search(body)
    if m is None:
        # ANSI 常量拼表达式：`set_name(NOR + WHT "干粮" NOR, ({...}));`
        #
        # `_SET_NAME` 只容许**一个**可选 ANSI 常量（`(?:[A-Z_]+)?`），
        # 而实际 LPC 里常见三个（`NOR` + `WHT` + `NOR`），正则匹配不上，
        # 于是这里以前直接退回 `name = "Item"` —— 而 `clone/herb`（53 个）、
        # `clone/fam/pill`（32 个）、`clone/medicine`（16 个）**全是这种写法**，
        # 整批都会产出占位名。
        #
        # 放宽：允许名字参数是任意「ANSI 常量 + 字符串字面量 + 加号」的组合，
        # 名字部分用既有的 `_extract_strings_from_macro_wrapped` 提取
        # （它会把字面量拼起来、丢掉 ANSI 常量）。
        m2 = _SET_NAME_LOOSE.search(body)
        if m2 is None:
            return {}
        name = _extract_strings_from_macro_wrapped(m2.group(1))
        aliases_str = m2.group(2)
        aliases = []
        for a in aliases_str.split(","):
            a = a.strip()
            a = re.sub(r'^["\']|["\']$', "", a)
            if a != "":
                aliases.append(a)
        return {"set_name": {"name": name, "aliases": aliases}}

    name = m.group(2)
    aliases_str = m.group(3)
    aliases = []
    for a in aliases_str.split(","):
        a = a.strip()
        a = re.sub(r'^["\']|["\']$', "", a)
        if a != "":
            aliases.append(a)
    return {"set_name": {"name": name, "aliases": aliases}}


def _parse_direct_assignments(body):
    assigns = {}
    for m in _DIRECT_ASSIGN.finditer(body):
        var = m.group(1)
        value = _parse_lpc_value(m.group(2).strip())
        assigns[var] = value
    return {"assigns": assigns}


def _parse_create_body(body):
    result = {}
    result.update(_parse_set_calls(body))
    result.update(_parse_set_name(body))
    result.update(_parse_direct_assignments(body))
    return result


def _parse_function_calls(body):
    calls = {}
    for m in _FUNC_CALL.finditer(body):
        func = m.group(1)
        args_str = m.group(2)
        args = [_parse_lpc_value(a.strip()) for a in args_str.split(",")]
        # Elixir: Map.update(acc, func, [args], fn existing -> existing ++ [args] end)
        calls.setdefault(func, [])
        calls[func] = calls[func] + [args]
    return calls


def _parse_other_functions(content):
    seen = set()
    out = []
    for m in _OTHER_FN.finditer(content):
        name = m.group(2)
        if name not in seen:
            seen.add(name)
            out.append({"name": name, "return_type": m.group(1)})
    return out


def _parse_globals(content):
    globals_ = {}
    for m in _GLOBAL_DECL.finditer(content):
        globals_[m.group(2)] = m.group(1)
    return globals_


def _parse_inherits(content):
    out = []
    for m in _INHERIT.finditer(content):
        path = m.group(2).strip()
        if path not in out:
            out.append(path)
    return out


def _parse_defines(content):
    defines = {}
    for m in _DEFINE.finditer(content):
        defines[m.group(1)] = m.group(2).strip()
    return defines


def _resolve_inherit_ref(token, defines):
    token = token.strip()
    if token.startswith("/"):
        path = token
    elif token.startswith("__DIR__"):
        # Macro-inherit of a sibling file: `inherit __DIR__"underlt";`
        # (city/wudao1.c).  The quoted tail is a path relative to this file's
        # directory, which _parse_inherit_files/2 joins onto.  Without this the
        # inherit chain was never followed, the type marker was lost and the room
        # was emitted as an empty "generic" entry - i.e. dropped from the zone.
        m = _QUOTED_STR.match(token[len("__DIR__"):].strip())
        path = m.group(1) if m else None
    elif "CLASS_D(" in token:
        # `inherit CLASS_D("generate") + "/chinese";` (room/roomnpc/shouwei.c).
        # CLASS_D only supplies the class directory, so the object id comes from
        # the last quoted segment.
        parts = re.findall(r'"([^"]*)"', token)
        path = parts[-1] if parts else None
    elif token in defines:
        value = defines[token]
        m = _DIR_STR.match(value)
        if m:
            path = m.group(1)
        elif _QUOTED_STR.match(value):
            path = re.sub(r'^["\']|["\']$', "", value).strip()
        else:
            path = None
    else:
        path = None

    if path is None or path == "":
        return None
    # Keep a leading "/" here: _parse_inherit_files/2 needs to tell an
    # LPC-root-relative path ("/d/xiyu/shamo") from a file-relative one, and it
    # resolves the two against different bases.  Stripping it here used to make
    # both look relative, producing ".../d/xiyu/d/xiyu/shamo".
    return path


def _parse_inherit_files(content, source_path):
    dir_ = os.path.dirname(source_path)
    defines = _parse_defines(content)
    out = []
    for token in _parse_inherits(content):
        rel = _resolve_inherit_ref(token, defines)
        if rel is None:
            continue
        # A leading "/" is an LPC-root-relative path ("/d/xiyu/shamo"), not a
        # path relative to this file's directory.  Joining it onto dir_ produced
        # ".../d/xiyu/d/xiyu/shamo", the parent could not be opened, the inherit
        # chain was never followed, shamo1/4/10 lost their ROOM marker and were
        # emitted as empty "generic" entries.  Resolve it against the LPC root
        # instead - the directory that contains the zone directory.
        if rel.startswith("/"):
            # LPC root = the directory that holds "d/".  The file lives at
            # <root>/d/<zone>[/<sub>...], so drop the trailing zone and any
            # subdirectory segments: ".../mud/d/xiyu" -> ".../mud", then
            # append the reference's own "/d/xiyu/shamo".
            zone_dir = _normpath_forward(dir_)
            parts = [p for p in zone_dir.split("/") if p]
            zone_idx = None
            for i in range(len(parts) - 1, -1, -1):
                if parts[i] == "d":
                    zone_idx = i
                    break
            root = "/".join(parts[:zone_idx]) if zone_idx else "/".join(parts[:-1])
            joined = _normpath_forward(root + rel)
        else:
            joined = _normpath_forward(os.path.join(dir_, rel))
        if joined not in out:
            out.append(joined)
    return out


# ---------------------------------------------------------------------------
# Unhandled content extraction
# ---------------------------------------------------------------------------
def _is_switch_table(stmt):
    return re.search(r'case\s+["\'][^"\']+["\']\s*:\s*\w+\s*=', stmt, re.S) is not None


def _parse_switch_table(stmt):
    m = re.search(r"switch\s*\(\s*([^)]+)\s*\)", stmt, _A)
    expr = m.group(1).strip() if m else None
    rows = []
    for m in _SWITCH_TABLE_ROW.finditer(stmt):
        key = m.group(1)
        body = m.group(2)
        cols = []
        for cm in _SWITCH_TABLE_COL.finditer(body):
            cols.append((cm.group(1).strip(), cm.group(2).strip()))
        rows.append({"key": key, "cols": cols})
    if not rows:
        return None
    return {"expr": expr, "rows": rows}


def _function_bodies(content):
    out = []
    for m in _BODY_SIG.finditer(content):
        name = m.group(1)
        match_start = m.start()
        brace_pos = m.end() - 1
        body = _find_matching_brace(content, brace_pos)
        if body is not None:
            out.append((name, body))
    return out


def _scan_chains(chars, i, acc, prev):
    while True:
        nw = _next_word(chars, i)
        if nw is None:
            return list(reversed(acc))
        w, j, k = nw
        if w == "if" and prev != "else":
            parsed = _parse_chain(chars, j)
            if parsed is None:
                i = j + 2
                prev = "if"
            else:
                chain, after_i = parsed
                acc.append(chain)
                i = after_i
                prev = None
        else:
            i = k
            prev = w


def _extract_condition(chars, if_pos):
    j = _skip_trivia(chars, if_pos + 2)
    if j is not None and j < len(chars) and chars[j] == "(":
        close = _match_delim(chars, j + 1, "(", ")", 1)
        if close is None:
            return None
        inner = "".join(chars[j + 1:close])
        cond = _ascii_ws_collapse(inner)
        after = _skip_trivia(chars, close + 1)
        return (cond, after)
    return None


def _read_block(chars, i):
    if i >= len(chars):
        return None
    c = chars[i]
    if c == "{":
        close = _match_delim(chars, i + 1, "{", "}", 1)
        if close is None:
            return None
        return ("".join(chars[i + 1:close]), close + 1)
    if c != ";":
        return _read_statement(chars, i)
    return None


def _read_statement(chars, i):
    fwd, next_ = _do_read_statement(chars, i, [], 0)
    return ("".join(reversed(fwd)), next_)


def _do_read_statement(chars, i, acc, depth):
    while i < len(chars):
        c = chars[i]
        if c == ";" and depth == 0:
            return acc, i + 1
        if c == '"':
            k = _skip_string(chars, i)
            if k is None:
                return acc, i
            seg = chars[i:k]
            acc = list(reversed(seg)) + acc
            i = k
        elif c == "{":
            acc = ["{"] + acc
            depth += 1
            i += 1
        elif c == "}":
            acc = ["}"] + acc
            depth = max(depth - 1, 0)
            i += 1
        elif c == "(":
            acc = ["("] + acc
            depth += 1
            i += 1
        elif c == ")":
            acc = [")"] + acc
            depth = max(depth - 1, 0)
            i += 1
        else:
            acc = [c] + acc
            i += 1
    return acc, i


def _collect_else(chars, i, acc):
    nw = _next_word(chars, i)
    if nw is None:
        return acc, i
    w, _, next_ = nw
    if w != "else":
        return acc, i
    k = _skip_trivia(chars, next_)
    if k is None:
        return acc, i
    if _word_at(chars, k, "if"):
        cond_res = _extract_condition(chars, k)
        if cond_res is None:
            return acc, i
        cond, after_paren = cond_res
        block = _read_block(chars, after_paren)
        if block is None:
            return acc, i
        body, after_idx = block
        branch = {"kind": "elif", "cond": cond, "actions": _branch_actions(body)}
        return _collect_else(chars, after_idx, acc + [branch])
    else:
        block = _read_block(chars, k)
        if block is None:
            return acc, k
        body, after_idx = block
        branch = {"kind": "else", "actions": _branch_actions(body)}
        return acc + [branch], after_idx


def _parse_chain(chars, if_pos):
    cond_res = _extract_condition(chars, if_pos)
    if cond_res is None:
        return None
    cond, after_paren = cond_res
    block = _read_block(chars, after_paren)
    if block is None:
        return None
    body1, after1 = block
    head = {"kind": "if", "cond": cond, "actions": _branch_actions(body1)}
    acc, final_i = _collect_else(chars, after1, [head])
    return acc, final_i


def _branch_actions(body):
    actions = []
    for m in _BRANCH_ACTION.finditer(body):
        full = m.group(0)
        actions.append(re.sub(r"\s+", " ", full, flags=_A).strip())
    # uniq (order-preserving)
    seen = set()
    out = []
    for a in actions:
        if a not in seen:
            seen.add(a)
            out.append(a)
    return out


def _split_condition_branches(body):
    chars = list(body)
    return _scan_chains(chars, 0, [], None)


def _extract_unhandled_content(content, unhandled_fn_names):
    unhandled = {
        "functions": [],
        "globals": [],
        "complex_mappings": [],
        "switch_tables": [],
        "switch_statements": [],
        "switch_pools": [],
        "conditional_branches": {},
        "complex_conditionals": [],
        "raw_code_blocks": [],
    }

    # 1. unhandled functions
    # sorted(): the caller passes a set (`other_fn_names - handled`), and Python
    # randomises string hashing per process (PYTHONHASHSEED), so iterating it
    # directly emitted these lines in a different order on every run.  The .ucl was
    # unaffected, but all 54 regenerated data/world/*.comments.txt files showed up
    # as pure reordering noise in git diff after every SOP re-run.
    for fn_name in sorted(unhandled_fn_names):
        unhandled["functions"] = [fn_name] + unhandled["functions"]

    # 2. globals
    simple_globals = {}
    for m in _GLOBAL_DECL.finditer(content):
        simple_globals[m.group(2)] = m.group(1)
    complex_globals = []
    for m in _COMPLEX_GLOBAL.finditer(content):
        name = m.group(2)
        if name not in simple_globals:
            complex_globals.append({"name": name, "type": m.group(1)})
    unhandled["globals"] = complex_globals

    # 3. complex mappings
    complex_mappings = []
    seen = set()
    for m in _COMPLEX_MAPPING.finditer(content):
        val = m.group(0)
        if val not in seen:
            seen.add(val)
            complex_mappings.append(val)
    unhandled["complex_mappings"] = complex_mappings

    # 4. switch statements
    all_switches = [_trim(m.group(0)) for m in _SWITCH_STMT.finditer(content)]
    switch_tables = []
    for stmt in all_switches:
        if _is_switch_table(stmt):
            parsed = _parse_switch_table(stmt)
            if parsed is not None:
                switch_tables.append(parsed)
    switch_pools = [s for s in all_switches if not _is_switch_table(s) and re.search(r"switch\s*\(\s*random\s*\(", s, re.S)]
    switch_others = [s for s in all_switches if not _is_switch_table(s) and not re.search(r"switch\s*\(\s*random\s*\(", s, re.S)]
    unhandled["switch_tables"] = switch_tables
    unhandled["switch_pools"] = switch_pools
    unhandled["switch_statements"] = switch_others

    # 5. conditional branches
    conditional_branches = {}
    for name, body in _function_bodies(content):
        chains = _split_condition_branches(body)
        if chains:
            conditional_branches[name] = chains
    unhandled["conditional_branches"] = conditional_branches

    # 6. complex if/else
    complex_ifs = [_trim(m.group(0)) for m in _IF_ELSE_BLOCK.finditer(content)]
    unhandled["complex_conditionals"] = complex_ifs

    # 7. raw blocks
    raw_blocks = []
    for m in _RAW_BLOCK.finditer(content):
        raw_blocks.append({"name": m.group(2), "body": _trim(m.group(3))})
    unhandled["raw_code_blocks"] = raw_blocks

    return unhandled


# ---------------------------------------------------------------------------
# valid_leave / exit vetoes / enter / greeting / accept / guard / engage
# ---------------------------------------------------------------------------
def _extract_function_body(content, name):
    sig = re.compile(r"(?:int|string|void|mixed|mapping|object|protected)\s+" + re.escape(name) + r"\s*\([^)]*\)\s*\n*\s*\{")
    m = sig.search(content)
    if m is None:
        return None
    brace_pos = m.end() - 1
    return _find_matching_brace(content, brace_pos)


def _parse_valid_leave(content):
    m = _VALID_LEAVE_SIG.search(content)
    if m is None:
        return None
    brace_pos = m.end() - 1
    body = _find_matching_brace(content, brace_pos)
    if body is None:
        return None
    return _parse_valid_leave_body(body)


def _parse_valid_leave_body(body):
    gm = _PRESENT.search(body)
    guard_npc = gm.group(2) if gm else None
    dm = _DIR_EQ.search(body)
    direction = dm.group(2) if dm else None
    has_permit_pass = "permit_pass" in body
    if guard_npc and direction and has_permit_pass:
        return {
            "guard_npc": guard_npc,
            "direction": direction,
            "permit_module": "Kantele.Npc.Guarder",
            "permit_function": "permit_pass",
        }
    return None


def _parse_exit_vetoes(content):
    body = _extract_function_body(content, "valid_leave")
    if body is None:
        return []
    return _parse_exit_vetoes_body(body)


def _notify_fail_sites(chars, i, acc):
    while True:
        j = _skip_trivia(chars, i)
        if j is None:
            return acc
        nw = _next_word(chars, j)
        if nw is None:
            return acc
        w, _start, k = nw
        if w == "notify_fail":
            m = _skip_trivia(chars, k)
            if m is not None and m < len(chars) and chars[m] == "(":
                acc.append(m)
                i = m + 1
            else:
                i = k
        else:
            i = k


def _preceding_if_condition(chars, open_idx):
    for i in range(open_idx - 1, -1, -1):
        if _word_at(chars, i, "if"):
            j = _skip_trivia(chars, i + 2)
            if j is not None and j < len(chars) and chars[j] == "(":
                close = _match_delim(chars, j + 1, "(", ")", 1)
                if close is not None:
                    text = _ascii_ws_collapse("".join(chars[j + 1:close]))
                    return {"text": text, "close": close}
    return None


def _exit_veto_direction(cond_text):
    if cond_text is None:
        return None
    m = _DIR_EQ.search(cond_text)
    return m.group(2) if m else None


def _exit_veto_at(chars, open_idx):
    close = _match_delim(chars, open_idx + 1, "(", ")", 1)
    if close is None:
        return None
    msg_arg = "".join(chars[open_idx + 1:close])

    cond = _preceding_if_condition(chars, open_idx)
    in_if = False
    if cond is not None:
        mid = "".join(chars[cond["close"] + 1:open_idx])
        trimmed = mid.strip()
        in_if = trimmed.startswith("return notify_fail") or trimmed.startswith("notify_fail")

    dir_ = _exit_veto_direction(cond["text"] if cond else None)
    condition = cond["text"] if in_if else None

    message = _process_literal_string(_extract_strings_from_macro_wrapped(msg_arg))
    if message == "":
        return None
    return {"dir": dir_, "condition": condition, "message": message}


def _parse_exit_vetoes_body(body):
    chars = list(body)
    sites = _notify_fail_sites(chars, 0, [])
    out = []
    for open_idx in sites:
        veto = _exit_veto_at(chars, open_idx)
        if veto is not None:
            out.append(veto)
    return out


def _parse_enter_body(body):
    add_actions = []
    for m in _ADD_ACTION.finditer(body):
        add_actions.append(m.group(2))
    # uniq
    seen = set()
    ua = []
    for v in add_actions:
        if v not in seen:
            seen.add(v)
            ua.append(v)

    gm = _CALL_OUT_GREET.search(body)
    greet_delay = int(gm.group(1)) if gm else 0
    hm = _HEARTBEAT.search(body)
    heartbeat = int(hm.group(1)) if hm else 0

    if not ua and greet_delay == 0 and heartbeat == 0:
        return None
    return {"greet_delay": greet_delay, "add_actions": ua, "heartbeat": heartbeat}


def _extract_enter(content):
    body = _extract_function_body(content, "init")
    if body is None:
        return None
    return _parse_enter_body(body)


def _render_dialogue_expr(raw):
    expr = raw.strip()
    if expr == "":
        return ""
    if re.fullmatch(r"[A-Z][A-Z0-9_]*", expr, _A):
        return ""
    if "RANK_D->query_respect" in expr:
        return "{respect}"
    if "RANK_D->query_rude" in expr:
        return "{rude}"
    if "->name()" in expr or 'query("name")' in expr:
        return "{name}"
    if _only_ansi_constants(expr):
        return ""
    return "{expr}"


def _only_ansi_constants(expr):
    cleaned = re.sub(r"[A-Z][A-Z0-9_]*", "", expr, flags=_A)
    cleaned = cleaned.replace("+", "")
    return cleaned.strip() == ""


def _render_dialogue(args):
    parts = [p for p in _STR_TOKEN.split(args) if p != ""]
    out = []
    for token in parts:
        if token.startswith('"'):
            inner = token[1:-1] if len(token) >= 2 else ""
            inner = inner.replace("\\n", "\n").replace("$N", "{npc}").replace("$n", "{name}")
            out.append(inner)
        else:
            out.append(_render_dialogue_expr(token))
    return "".join(out)


def _extract_greetings(content):
    body = _extract_function_body(content, "greeting")
    if body is None:
        return None
    lines = []
    for m in _DIALOGUE_CALL.finditer(body):
        lines.append(_render_dialogue(m.group(1)))
    clean = [_trim(x) for x in lines]
    clean = [x for x in clean if x != ""]
    return clean if clean else None


def _extract_accept(content):
    body = _extract_function_body(content, "accept_object")
    if body is None:
        return None
    return _parse_accept_body(body)


def _extract_guard(content):
    body = _extract_function_body(content, "permit_pass")
    if body is None:
        return None
    return _parse_guard_body(body)


def _parse_guard_body(body):
    fm = _GUARD_FAMILY.search(body)
    family = fm.group(1) if fm else None
    rm = _GUARD_REFUSE.search(body)
    refuse_msg = None
    if rm:
        refuse_msg = rm.group(1).replace("\\n", "\n").replace("$N", "{npc}").replace("$n", "{name}").strip()
    if family is None and refuse_msg is None:
        return None
    return {"family": family, "refuse_other": refuse_msg}


def _extract_engage(content):
    engage = {}
    for kind in ["fight", "hit", "kill"]:
        body = _extract_function_body(content, f"accept_{kind}")
        if body is None:
            continue
        parsed = _parse_engage_kind(body)
        if parsed is not None:
            engage[kind] = parsed
    return engage if engage else None


def _parse_engage_kind(body):
    last_return = _get_last_return(body)
    has_return = last_return is not None
    has_kill_ob = _KILL_OB.search(body) is not None
    has_inherit = _ENGAGE_KIND.search(body) is not None
    msg = _extract_engage_msg(body)
    spawn = _extract_spawn_ids(body)

    if has_return:
        return {"accept": last_return == 1, "msg": msg, "retaliate": has_kill_ob,
                "spawn": spawn, "inherit": has_inherit, "note": body}
    if has_inherit:
        return {"accept": None, "msg": msg, "retaliate": has_kill_ob,
                "spawn": spawn, "inherit": True, "note": body}
    return {"accept": None, "msg": msg, "retaliate": False, "spawn": spawn,
            "inherit": False, "note": body}


def _get_last_return(body):
    matches = _RETURN_01.findall(body)
    if not matches:
        return None
    return int(matches[-1])


def _extract_engage_msg(body):
    m = _CMD_SAY.search(body)
    if m:
        return _process_literal_string(m.group(1))
    return _extract_message_vision_literal(body)


def _extract_message_vision_literal(body):
    m = _MESSAGE_VISION_LIT.search(body)
    if m is None:
        return None
    group = m.group(1)
    segs = [mm.group(1) for mm in _STR_LITERAL.finditer(group)]
    joined = "".join(segs)
    processed = _process_literal_string(joined)
    return processed if processed != "" else None


def _extract_spawn_ids(body):
    out = []
    for m in _SPAWN_NEW.finditer(body):
        path = m.group(1)
        out.append(_path_basename_rootname(path))
    return [x for x in out if x != ""]


def _parse_accept_body(body):
    accept_dialogues = _extract_accept_dialogues(body)

    money_rule = None
    if "money_id" in body:
        vm = _MONEY_ID.search(body)
        min_ = int(vm.group(1)) if vm else None
        msg = accept_dialogues["money"] or (accept_dialogues["default"][0] if accept_dialogues["default"] else None)
        money_rule = {"kind": "money", "min": min_, "msg": msg}

    reject_msgs = accept_dialogues["reject"]

    item_id_rules = []
    for m in _ITEM_ID_QUERY.finditer(body):
        item_id_rules.append({
            "kind": "item_id",
            "id": m.group(2),
            "msg": accept_dialogues.get(f"item_id_{m.group(2)}") or accept_dialogues["default"],
        })

    item_name_rules = []
    for m in _ITEM_NAME_QUERY.finditer(body):
        item_name_rules.append({
            "kind": "item_name",
            "name": m.group(2),
            "msg": accept_dialogues.get(f"item_name_{m.group(2)}") or accept_dialogues["default"],
        })

    has_return_0 = re.search(r"return\s+0\s*;", body, _A) is not None
    has_return_1 = re.search(r"return\s+1\s*;", body, _A) is not None
    has_specific_rules = bool(money_rule is not None or item_id_rules or item_name_rules)
    last_return = _get_last_return(body)

    default_rule = None
    if has_return_0 and not has_return_1:
        default_rule = {"kind": "any", "accept": False, "msg": accept_dialogues["reject"]}
    elif has_return_1 and not has_return_0:
        default_rule = {"kind": "any", "accept": has_specific_rules, "msg": accept_dialogues["default"]}
    elif has_return_0 and has_return_1:
        accept_default = last_return == 1
        reject_pool = accept_dialogues["reject"]
        if last_return == 1:
            msg = accept_dialogues["default"]
        else:
            msg = accept_dialogues["default"] if not reject_pool else reject_pool
        default_rule = {"kind": "any", "accept": accept_default,
                        "msg": msg or accept_dialogues["default"]}

    if default_rule is not None and reject_msgs and default_rule.get("msg") != reject_msgs:
        default_rule["fail_msg"] = reject_msgs

    rules = [r for r in [money_rule] + item_id_rules + item_name_rules + [default_rule] if r is not None]
    return rules if rules else None


def _extract_all_strings_with_context(body):
    out = []

    # tell_object
    for tm in _ACCEPT_DIALOGUE_TELL.finditer(body):
        call = tm.group(0)
        for sm in _STR_LITERAL.finditer(call):
            out.append(("tell_object", _process_literal_string(sm.group(1))))

    # command("say ...")
    for cm in _ACCEPT_CMD_SAY.finditer(body):
        out.append(("command_say", _process_literal_string(cm.group(1))))

    # message_vision / message_sort
    out.extend(_extract_pool_calls(body, _MESSAGE_CALL, "message_vision"))
    # say
    out.extend(_extract_pool_calls(body, _SAY_CALL, "say"))
    # notify_fail -> reject
    out.extend(_extract_pool_calls(body, _NOTIFY_FAIL_CALL, "reject"))
    # write -> default
    out.extend(_extract_pool_calls(body, _WRITE_CALL, "default"))

    # command("msg") without say
    for cm in _ACCEPT_CMD_OTHER.finditer(body):
        out.append(("command_other", _process_literal_string(cm.group(1))))

    return out


def _extract_pool_calls(body, re_call, context):
    try:
        result = []
        for call in _extract_calls_balanced(body, re_call):
            text = _extract_quoted_strings(call)
            text = _sanitize_message_text(text)
            if text != "":
                result.append((context, text))
        return result
    except Exception:
        return []


def _extract_quoted_strings(call):
    return "".join(_process_literal_string(m.group(1)) for m in _STR_LITERAL.finditer(call))


def _extract_calls_balanced(body, re_call):
    out = []
    for m in re_call.finditer(body):
        call = _take_balanced_call(body[m.start():])
        if call != "":
            out.append(call)
    return out


def _take_balanced_call(call):
    chars = list(call)
    depth = 0
    acc = []
    for h in chars:
        if h == "(":
            depth += 1
            acc.insert(0, h)
        elif h == ")":
            if depth <= 1:
                return "".join(reversed(acc)) + ")"
            depth -= 1
            acc.insert(0, h)
        else:
            acc.insert(0, h)
    return "".join(reversed(acc))


def _extract_accept_dialogues(body):
    all_strings = _extract_all_strings_with_context(body)
    money_msgs = [s for ctx, s in all_strings if ctx in ("tell_object", "money")]
    default_msgs = [s for ctx, s in all_strings if ctx in ("command_say", "say", "message_vision", "command_other", "default")]
    reject_msgs = [s for ctx, s in all_strings if ctx == "reject"]

    money_msg = money_msgs[0] if money_msgs else (default_msgs[0] if default_msgs else None)
    default_msgs = [s for s in default_msgs if not s.startswith("say ")]
    default_msgs = list(dict.fromkeys(default_msgs))
    reject_msgs = list(dict.fromkeys(reject_msgs))

    return {"money": money_msg, "default": default_msgs, "reject": reject_msgs}


def _sanitize_message_text(text):
    text = re.sub(r"message_(?:vision|sort)\s*\(.*", "", text, flags=re.S)
    text = re.sub(r"\s*\)\;.*", "", text, flags=re.S)
    text = text.replace(";", "\\;").replace(")", "\\)").replace("(", "\\(")
    return text.strip()


# ---------------------------------------------------------------------------
# Inherit chain merge
# ---------------------------------------------------------------------------
def _child_of(ast):
    create = ast.create_fn or {}
    return {
        "inherits": ast.inherits or [],
        "sets": create.get("sets", {}),
        "set_name": create.get("set_name", {}),
        "heredocs": (ast.heredocs or {}).get("heredocs", {}),
        "exit_vetoes": ast.exit_vetoes or [],
        "valid_leave": ast.valid_leave,
    }


def _is_exit_mapping(v):
    # A "mapping" marker is a non-empty (type, contents) tuple.  An empty tuple
    # is the .get() default for "no exits mapping set anywhere in this chain"
    # and must fall through to the plain set-merge branch, not crash on v[0].
    return isinstance(v, tuple) and len(v) > 0 and v[0] == "mapping"


def _merge_vals(base, newer):
    merged_sets = {**base["sets"], **newer["sets"]}
    # For exits specifically, we need to merge mappings by key (direction)
    # rather than having newer overwrite base, to avoid duplicate directions
    base_exits = base["sets"].get("exits", ())
    newer_exits = newer["sets"].get("exits", ())
    if _is_exit_mapping(base_exits) and _is_exit_mapping(newer_exits):
        # Merge exit mappings: base first, then newer (newer wins for same direction)
        base_exit_map = {k[1]: v for k, v in base_exits[1]} if isinstance(base_exits[1], list) else {}
        newer_exit_map = {k[1]: v for k, v in newer_exits[1]} if isinstance(newer_exits[1], list) else {}
        merged_exit_map = {**base_exit_map, **newer_exit_map}
        merged_exits = ("mapping", list(merged_exit_map.items()))
        merged_sets = {**base["sets"], **newer["sets"], "exits": merged_exits}
    else:
        merged_sets = {**base["sets"], **newer["sets"]}
    return {
        "inherits": newer["inherits"] + base["inherits"],
        "sets": merged_sets,
        "set_name": {**base["set_name"], **newer["set_name"]},
        "heredocs": {**base["heredocs"], **newer["heredocs"]},
        "exit_vetoes": newer["exit_vetoes"],
        "valid_leave": newer["valid_leave"],
    }


def _merge_inherit_level(ast, visited):
    source = ast.source_path
    create = ast.create_fn or {}
    child_vals = {
        "inherits": ast.inherits or [],
        "sets": create.get("sets", {}),
        "set_name": create.get("set_name", {}),
        "heredocs": (ast.heredocs or {}).get("heredocs", {}),
        "exit_vetoes": ast.exit_vetoes or [],
        "valid_leave": ast.valid_leave,
    }
    parents = ast.inherit_files or []

    if source in visited or not parents:
        return _finalize_merged(ast, child_vals)

    base_vals = {
        "inherits": [], "sets": {}, "set_name": {}, "heredocs": {},
        "exit_vetoes": [], "valid_leave": None,
    }
    for parent_ref in parents:
        # The corpus spells the parent both ways: `inherit "/d/xiyu/shamo";`
        # and `inherit "/d/xiyu/shamo.c";` (xiyu/shamo4.c).  Appending ".c"
        # blindly turned the second form into "shamo.c.c", so the parent could
        # not be opened and the room lost its ROOM marker.
        path = parent_ref if parent_ref.endswith(".c") else parent_ref + ".c"
        try:
            with open(path, "rb") as f:
                content = f.read()
        except OSError:
            continue
        parent_ast = _parse_lpc(content, path, os.path.dirname(path))
        if parent_ast is None:
            continue
        parent_vals = _child_of(_merge_inherit_level(parent_ast, visited | {source}))
        base_vals = _merge_vals(base_vals, parent_vals)

    merged_vals = _merge_vals(base_vals, child_vals)

    if child_vals["exit_vetoes"] == []:
        merged_vals["exit_vetoes"] = base_vals["exit_vetoes"]
    if child_vals["valid_leave"] is None:
        merged_vals["valid_leave"] = base_vals["valid_leave"]

    return _finalize_merged(ast, merged_vals)


def _finalize_merged(ast, vals):
    ast.inherits = vals["inherits"]
    create_fn = {"sets": vals["sets"], "set_name": vals["set_name"]}
    # Branches are a property of one file's own create(), not of the merged
    # `sets` (whose "objects" entry is just the last branch), so carry the
    # child's across untouched.
    if ast.create_fn.get("object_branches") is not None:
        create_fn["object_branches"] = ast.create_fn["object_branches"]
    ast.create_fn = create_fn
    ast.heredocs = {"heredocs": vals["heredocs"]}
    ast.exit_vetoes = vals["exit_vetoes"]
    ast.valid_leave = vals["valid_leave"]
    return ast


# ---------------------------------------------------------------------------
# Object type detection
# ---------------------------------------------------------------------------
_ITEM_KWS = ["WEAPON", "SWORD", "BLADE", "DAGGER", "STAFF", "CLUB", "HAMMER", "AXE",
             "THROWING", "WHIP", "FORCE ?", "ARMOR", "CLOTH", "BOOTS", "FINGER",
             "HANDS", "HEAD", "HELMET", "NECK", "RING", "SHIELD", "SURCOAT",
             "WAIST", "WRIST", "ARMOR ?", "ITEM", "MONEY", "CONTAINER", "FOOD",
             "MEDICINE", "BOOK", "GOLD", "SILVER"]


def _npc_subdir(source_path):
    norm = source_path.replace("\\", "/")
    return "npc" in [p for p in norm.split("/")]


def _is_item_inherit(inherit):
    return any(kw in inherit for kw in _ITEM_KWS)


def _skill_inherit(inherit):
    up = inherit.upper()
    return "SKILL" in up or "FORCE" in up


# NPC feature macros, mixed in with `inherit CLASS_D(...) + "/chinese";` by
# room/roomnpc/shouwei.c.  They mark the file as an NPC even though no line
# carries the NPC keyword.
_NPC_FEATURE_KWS = ("F_GUARDER", "F_COAGENT", "F_COUNTER", "F_PERFORMER",
                    "F_TRADE", "F_SCHOLAR", "F_HUTTER")


def _is_npc_feature_inherit(inherit):
    up = inherit.upper()
    return any(kw in up for kw in _NPC_FEATURE_KWS)


def _item_features(ast):
    create = ast.create_fn or {}
    sets = create.get("sets", {})
    set_name = create.get("set_name", {})
    return ("material" in sets or "unit" in sets or "value" in sets or
            "weight" in sets or "name" in set_name)


def _item_like(ast):
    source = ast.source_path
    if "obj" + "/" in source or "obj" + os.sep in source:
        return _item_features(ast)
    return False


def _determine_object_type(ast):
    inherits = ast.inherits
    if any("ROOM" in i for i in inherits):
        return "room"
    if any("RIVER" in i for i in inherits):
        return "room"
    if any("NPC" in i for i in inherits):
        return "npc"
    if any(_is_npc_feature_inherit(i) for i in inherits):
        # NPC feature macros, e.g. room/roomnpc/shouwei.c:
        #     inherit CLASS_D("generate") + "/chinese";
        #     inherit F_GUARDER;
        #     inherit F_COAGENT;
        # The CLASS_D line names no type, so without the feature macros the file
        # fell through to "generic" and the guard was dropped from the zone -
        # its four siblings in the same directory all use `inherit NPC;`.
        return "npc"
    if any("KNOWER" in i for i in inherits):
        return "npc"
    if _npc_subdir(ast.source_path):
        return "npc"
    if any(_is_item_inherit(i) for i in inherits):
        return "item"
    if any(_skill_inherit(i) for i in inherits):
        return "skill"
    if _item_like(ast):
        return "item"
    return "generic"


def _type_marker_inherit(inherit, obj_type):
    if obj_type == "room":
        return "ROOM" in inherit or "RIVER" in inherit
    if obj_type == "npc":
        return "NPC" in inherit or "KNOWER" in inherit
    if obj_type == "item":
        return _is_item_inherit(inherit)
    if obj_type == "skill":
        return _skill_inherit(inherit)
    return False


# ---------------------------------------------------------------------------
# UCL generation
# ---------------------------------------------------------------------------
def _extract_string(value, default):
    if isinstance(value, tuple) and value[0] == "string":
        return value[1]
    if isinstance(value, str):
        return value
    return default


def _ucl_string(s):
    return '"' + _sanitize_ucl_sval(s) + '"'


def _sanitize_ucl_sval(s):
    # LPC line continuation first: a backslash at end of line joins the next
    # line.  It must happen BEFORE newlines collapse to spaces, otherwise the
    # backslash survives as a lone "\" followed by a space, and elias cannot
    # lex that: elias_parser.yrl only has `words -> back_slash word words`
    # and `words -> back_slash quotes words`, so a backslash before
    # whitespace aborts the parse.  This bit mingjiao/miaorenbuluo.c, whose
    # @TEXT block ends a line with a backslash after the character Kou.
    s = _LPC_CONTINUATION.sub("", s)
    s = s.replace("\\\\\\\\", "\\\\")
    s = s.replace("\\\\", "\\")
    s = s.replace('\\"', "'")
    s = s.replace('"', "'")
    s = s.replace(";", " ")
    s = s.replace("\n", " ")
    s = s.replace("\r", " ")
    # LPC message placeholders used in wield/unwield/emote strings
    s = s.replace("$N", "{npc}")
    s = s.replace("$n", "{name}")
    # elias parser chokes on [ ] inside strings (used in sound effects like $N[噌])
    s = s.replace("[", "(")
    s = s.replace("]", ")")
    return s.strip()


def _escape_heredoc_content(s):
    return _sanitize_ucl_sval(s)


def _escape_set_string(s):
    return _sanitize_ucl_sval(s)


def _get_heredoc_or_set(heredocs, sets, key, default):
    v = sets.get(key)
    if isinstance(v, tuple) and v[0] == "string":
        if v[1] != "":
            return _escape_set_string(v[1])
        return _get_heredoc(heredocs, key, default)
    if isinstance(v, tuple) and v[0] == "var":
        if re.match(r"^@\w+", v[1], _A):
            return _get_heredoc(heredocs, key, default)
        return default
    if v is None:
        return _get_heredoc(heredocs, key, default)
    return default


def _get_heredoc(heredocs, key, default):
    h = heredocs.get(key)
    if h is not None:
        return _escape_heredoc_content(h["content"])
    return default


def _coord_of(value):
    if isinstance(value, tuple) and value[0] == "int":
        return value[1]
    return 0


def _room_id_from_path(path):
    stripped = path.replace('__DIR__"', "")
    # The path may end with a bare quote (from __DIR__"npc/foo")
    # Original code looked for "$ but path ends with just "
    stripped = stripped.replace('"', "")
    stripped = re.sub(r'^"/d/', "", stripped)
    base = os.path.splitext(os.path.basename(stripped))[0]
    return _norm_id(base).lower()


# Roots that live outside d/ and therefore have no data/world/<zone>.ucl to
# point at.  An exit into one of them cannot be expressed as a zone reference.
_UNLINKABLE_ROOTS = ("/clone/", "/b/", "/u/", "/adm/", "/cmds/", "/include/")

# Zone ids that actually exist as data/world/<zone>.ucl.  Refreshed by main() at
# the start of every run so a cross-zone reference can be validated against what is
# really installed rather than only against the LPC directory names.
_INSTALLED_ZONE_IDS = set()


def note_installed_zones(output_dir):
    """Record which zone ids have a UCL file in the output directory."""
    global _INSTALLED_ZONE_IDS
    try:
        names = os.listdir(output_dir)
    except OSError:
        _INSTALLED_ZONE_IDS = set()
        return _INSTALLED_ZONE_IDS
    _INSTALLED_ZONE_IDS = {n[:-4] for n in names
                           if n.endswith(".ucl") and os.path.isfile(
                               os.path.join(output_dir, n))}
    return _INSTALLED_ZONE_IDS

# An LPC runtime pick: a literal path concatenated with random(n), optionally
# offset by k.  The driver evaluates str(random(n) [+ k]) ONCE per key, so the
# destination is exactly one of the candidates.
#
#     __DIR__"shulin" + (random(8) + 6)   ->  shulin6 .. shulin13   (offset 6)
#     __DIR__"obj/fojing1" + random(2)   ->  fojing10, fojing11  (no offset)
#     __DIR__"wuxing" + random(5)       ->  wuxing0 .. wuxing4   (no offset, no
#                                                                 spaces, no parens)
#
# The last form is shaolin/rukou.c's "south" exit; requiring the parentheses and
# the offset (an earlier version of this pattern) let it through unresolved and
# emitted `rooms.wuxing+random(5).id` straight into the UCL.
_RANDOM_PICK_RE = re.compile(
    r'^(?P<stem>[^+\[\]()$]+?)\s*\+\s*'
    r'\(?\s*random\(\s*(?P<n>\d+)\s*\)'
    r'(?:\s*\+\s*(?P<k>\d+)\s*\)?)?\s*$')

# A runtime-picked path: a literal path concatenated with `random(...)`, e.g.
#     __DIR__"shulin" + (random(8) + 6)     ->  shulin6 .. shulin13
#     "d/shaolin/obj/fojing1" + random(2)  ->  fojing10, fojing11
# Only these are preserved whole; a concatenation with a plain variable
# (changan's `__DIR__"obj/" + weapon_file`) has no determinate candidate set and
# keeps the old truncate-then-skip behaviour.
_RUNTIME_PATH_RE = re.compile(
    r'^\s*(__DIR__)?"[^"]*"\s*\+\s*\(?\s*random\(')


def _classify_exit_path(path, zone_id, direction=None):
    """Classify an LPC exit target path.

    `direction` is the exit key, used only as a last resort to recover the
    destination zone when the LPC directory itself was never converted; see the
    _INSTALLED_ZONE_IDS block below.

    Returns one of:
      ("local",  room_id)               same zone -> rooms.<room>.id
      ("cross",  zone, room_id)         other d/ zone -> <zone>.rooms.<room>.id
      ("sub",    room_id)               same zone, written with a subdirectory
                                         (e.g. "dule/xiaoyuan", "heisenlin/entry")
      ("random", [room_id, ...])        runtime pick among several rooms
                                         (`__DIR__"shulin" + (random(8) + 6)`,
                                          `__DIR__"wuxing" + random(5)`)
      ("self",   None)                  __FILE__ / the room itself
      ("skip",   reason)                no data/world zone to point at
    """
    raw = path.strip()
    if raw.startswith("__FILE__"):
        return ("self", None)

    t = raw.replace("__DIR__", "").replace('"', "").strip()

    # A runtime-picked destination:  __DIR__"shulin" + (random(8) + 6)
    # The MUD concatenates str(random(n) [+ k]), so this names exactly the n
    # files stem<k+0> .. stem<k+n-1>.  gaochang/shulin1.c and shaolin/shulin10.c
    # use the offset form in all four directions; shaolin/rukou.c uses the bare
    # `__DIR__"wuxing" + random(5)`.  Returning the whole candidate set (rather
    # than the bare stem, which named a room that does not exist) lets the
    # loader pick one per room, exactly as the LPC driver did.
    rand = _RANDOM_PICK_RE.match(t)
    if rand:
        stem = rand.group("stem")
        n = int(rand.group("n"))
        k = int(rand.group("k") or 0)
        if n > 0 and stem:
            return ("random", [_room_id_from_path("%s%d" % (stem, k + i))
                               for i in range(n)])

    # A `d/<zone>/<file>` path written WITHOUT the leading slash.  This is a known
    # data bug in the corpus - tiezhang/hunanroad1.c has
    #   "east" : "d/xiangyang/caodi6",
    # which therefore never resolved and left 铁掌帮 -> 襄阳 a one-way dead end
    # (documented in docs/mud-d-zone-center-connections.zh-CN.md, "数据 bug").
    # Treating it as the /d/ path it was meant to be repairs that link.
    if re.match(r"^d/[A-Za-z0-9_]+/", t):
        t = "/" + t

    if t.startswith("/d/"):
        parts = t[3:].split("/")
        tzone = parts[0]
        tail = "/".join(parts[1:])
        if not tail:
            return ("skip", "empty /d/ path")
        room = _room_id_from_path(tail)
        if tzone == zone_id:
            return ("local", room)
        # When the LPC directory has no data/world zone of its own, "<tzone>" names
        # a zone the loader cannot find and the exit is dropped.  The author's intent
        # is still recoverable from the direction: LPC names such an exit after the
        # place it leads to, and one town's square links out to another town under
        # that town's name.  So when the direction is itself an installed zone id,
        # prefer it over the unconvertible directory.
        #
        # This is a PREFERENCE, never a gate.  Gating on it ("if tzone is not
        # installed then skip") makes the output depend on whatever happens to be in
        # --output: converting into a fresh or partial directory dropped every
        # cross-zone exit, e.g. city lost `-north-> shaolin`, `-in-> gaibang` and
        # `-liuxi-> liuxi` and emitted `# skipped exit ...` for them.  With nothing
        # known about the target zone we emit the plain cross-zone reference and let
        # the loader's `not is_nil` filter deal with a genuinely dead link.  Room
        # name is deliberately NOT used as a fallback: "guangchang" is the town
        # square of a dozen zones, so it identifies nothing.
        if _INSTALLED_ZONE_IDS and tzone not in _INSTALLED_ZONE_IDS \
                and direction and direction in _INSTALLED_ZONE_IDS \
                and direction != zone_id:
            return ("cross", direction, room)
        return ("cross", tzone, room)

    for root in _UNLINKABLE_ROOTS:
        if t.startswith(root):
            return ("skip", "target outside d/: %s" % t)

    if t.startswith(".."):
        return ("skip", "relative path: %s" % t)

    if t == "":
        return ("skip", "empty target")

    if "/" in t:
        # A same-zone reference written with a subdirectory.  The zone prefix is
        # optional and, when absent, the head segment is simply a subdirectory of
        # THIS zone - the basename is the room id:
        #   room/xiaoyuan.c     "panlong" : __DIR__"panlong/dayuan"
        #   room/xiaoyuan.c     "dule"    : __DIR__"dule/xiaoyuan"
        #   city/liaotian.c     "east"    : __DIR__ "qiyuan/qiyuan1"
        #   death/jimiesi.c     "north"   : "heisenlin/entry"
        # Previously anything whose head was not the zone name was rejected as an
        # "unrecognised relative path", which silently dropped those four working
        # links.
        return ("local", _room_id_from_path(t))

    return ("local", _room_id_from_path(t))


def _resolve_exit_target(val, zone_id, room_id=None, direction=None):
    """Render an exit value as a UCL reference.

    Cross-zone targets become `<zone>.rooms.<room>.id` because that is the shape
    Kantele.World.Loader.dereference/3 understands: it splits on "." and treats
    a first segment that is not "rooms"/"characters"/"items" as a zone id to
    look up (loader.ex:1315-1343).  Without the zone prefix a cross-zone exit
    was written as `rooms.<room>.id`, which resolved *inside the source zone* -
    either dangling (dropped by parse_exits' `not is_nil` filter) or, when the
    source zone happened to own a room of that name, silently linked to the
    wrong room (e.g. beijing/ximenwai -west-> /d/heimuya/road3 pointed at
    beijing/road3).

    `room_id` is the room being generated; it is only needed to resolve
    `__FILE__`, which names the room itself.  `direction` is the exit key, used to
    recover the destination zone when the LPC directory was never converted.
    """
    if isinstance(val, tuple) and val[0] == "string":
        kind, *rest = _classify_exit_path(val[1], zone_id, direction)
    elif isinstance(val, tuple) and val[0] == "var":
        kind, *rest = _classify_exit_path(val[1].strip(), zone_id, direction)
    else:
        return None, "non-literal exit target"

    if kind == "local" or kind == "sub":
        return "rooms." + rest[0] + ".id", None
    if kind == "random":
        # One direction that the MUD resolves to one of several rooms at run time
        # (gaochang/shulin1.c's `__DIR__"shulin" + (random(8) + 6)`).  Emit all
        # candidates as a bracketed list; the loader picks one per room, the same
        # way the LPC driver did.  elias only accepts this WITHOUT spaces between
        # the elements - `[a, b]` is a syntax error, `[a,b]` parses to the string
        # "a,b".
        if not rest[0]:
            return None, "runtime random with no candidates"
        return "[" + ",".join("rooms.%s.id" % c for c in rest[0]) + "]", None
    if kind == "cross":
        return "%s.rooms.%s.id" % (rest[0], rest[1]), None
    if kind == "self":
        # LPC's __FILE__ is the room's own source file, i.e. the exit leads back
        # to this very room - a legal (if odd) self-loop.  50 rooms / 137 exits
        # across 11 zones use it, e.g. baituo/cao1.c:
        #     "west" : __FILE__,
        #     "south": __FILE__,
        # Resolving it to the room itself keeps the direction usable; the old
        # behaviour wrote a literal `rooms.__file__.id`, which named a room that
        # does not exist, so the loader dropped it and the direction silently did
        # nothing.  Verified safe downstream: a self-loop resolves to the same
        # room id, Zone -> Voting -> MoveEvent simply re-enters the same room,
        # and both assign_room_coords (visited set) and check_room_coords
        # (already-seen guard) treat it as a no-op.  None of these 137 exits use
        # up/down, so the vertical-link synthesis is untouched.
        if not room_id:
            return None, "self-referential (__FILE__) with unknown room id"
        return "rooms." + _room_id_from_path(room_id) + ".id", None
    return None, rest[0]


def _exit_key(key):
    if isinstance(key, tuple) and key[0] == "string":
        return _strip_exit_c_comments(key[1])
    if isinstance(key, tuple) and key[0] == "int":
        return str(key[1])
    if isinstance(key, tuple) and key[0] == "var":
        return _strip_exit_c_comments(key[1])
    if isinstance(key, str):
        return _strip_exit_c_comments(key)
    return "unknown"


def _strip_exit_c_comments(s):
    s = _C_COMMENT.sub("", s)
    return s.strip()


# A UCL key that elias can actually lex.  Stripping a C comment out of a
# direction can leave nothing behind (`"south" : ..., /* EXAMPLE */` becomes the
# pair ("", nil)), and an empty key renders as ` = rooms.x.id`.
# elias_parser.yrl only accepts
# `assignment -> word equality ...`, and elias's Word token pattern is
#     Word = [^0-9{}\*\/#\n\[\]=\s'":\;\\-]+
# with `Digit = [0-9]+` as a separate token.  So a key containing a digit is
# split into word+digit and the assignment cannot close.  Measured against
# elias 0.2.8:
#     hole = rooms.b.id      -> parses
#     hole6 = rooms.b.id     -> FAILS (word "hole" then digit "6")
#     hole_6 = rooms.b.id    -> FAILS
# A *value* is unaffected: `rooms.lockroom6.id` parses fine, so room ids may
# still contain digits.  Only the key is restricted.
#
# The same rule also rejects a non-ASCII key: elias's Word token is ASCII-only, so
# shaolin's bagua directions (乾/巽/离/艮/兑/坎/震/坤) cannot be written as keys
# either.  64 such exits across the eight bagua rooms.
def _exit_dir_skip_reason(direction):
    """Why this exit direction cannot be written, or None when it is fine.

    Two very different causes used to share one (wrong) message:

    * empty - a C comment was stripped off the end of the direction, leaving
      nothing behind (room/caihong/dating.c's `"south" : __DIR__"xiaoyuan",
      /* EXAMPLE */`).  Nothing to do with elias.
    * not a bare identifier - a genuine LPC direction that elias cannot lex as a
      key: CJK (shaolin's bagua 乾/巽/...) or an embedded digit
      (huashan's "hole1".."hole6").  Writing it produces
      `syntax error before: ', ['"6"']` and aborts the whole world load.
    """
    if direction == "":
        return "direction became empty after stripping a C comment"
    if not direction.isascii():
        return ("direction is not ASCII; elias's Word token is ASCII-only, "
                "so this key cannot be lexed")
    if re.search(r"\d", direction):
        return ("direction contains a digit; elias lexes Digit as a separate "
                "token, so the assignment cannot close")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z_]*", direction):
        return "direction is not a bare identifier"
    return None


def _build_room_flags(sets):
    # Elixir build_room_flags: all `flags = [...]` rebindings sit inside `if`
    # blocks whose scope discards them -> flags is always [] -> no flags block.
    return []


def _generate_room_item_desc(sets):
    v = sets.get("item_desc")
    if not (isinstance(v, tuple) and v[0] == "mapping"):
        return ""
    entries = []
    for k, val in v[1]:
        keyword = _normalize_item_keyword(_item_desc_keyword(k))
        text = _item_desc_text(val)
        # Test the NORMALISED keyword: a CJK key such as "床" or "大床" (see
        # changan/qunyuys8.c) normalises to the empty string, and emitting
        # ` = "..."` with no key is a syntax error.
        if keyword != "" and text != "":
            entries.append((keyword, text))
    if not entries:
        return ""
    rendered = "\n".join(
        f" {kw} = \"{_escape_set_string(text)}\"" for kw, text in entries
    )
    return f"item_desc = {{\n{rendered}\n}}\n"


def _item_desc_text(value):
    if isinstance(value, tuple) and value[0] == "array":
        parts = "".join(s for tag, s in value[1] if tag == "string")
        return _process_literal_string(parts)
    if isinstance(value, tuple) and value[0] == "string":
        return _process_literal_string(value[1])
    if isinstance(value, str):
        return _process_literal_string(value)
    return ""


def _item_desc_keyword(key):
    if isinstance(key, tuple) and key[0] == "string":
        return key[1]
    if isinstance(key, str):
        return key
    return ""


def _normalize_item_keyword(keyword):
    keyword = re.sub(r"[^a-zA-Z0-9_]", "_", keyword)
    keyword = re.sub(r"^_+|_+$", "", keyword)
    return keyword


def _generate_room_exit_vetoes(ast):
    if not ast.exit_vetoes:
        return ""
    rendered = ",\n".join(_render_veto(v) for v in ast.exit_vetoes)
    return f"valid_leave = [\n{rendered}\n]\n"


def _render_veto(veto):
    dir_ = f'"{veto["dir"]}"' if veto["dir"] else "~"
    message = f'"{_escape_set_string(veto["message"])}"'
    condition_comment = f' # 阻挡条件（原样保留）：{veto["condition"]}\n' if veto.get("condition") else ""
    return f"{{\n  {condition_comment}direction = {dir_}\n  message = {message}\n}}\n"


def _generate_room_ucl(ast, zone_id):
    create = ast.create_fn
    sets = create.get("sets", {})
    heredocs = (ast.heredocs or {}).get("heredocs", {})
    long_val = sets.get("long")

    room_id = _norm_id(_path_basename_rootname(ast.source_path))

    is_river = any("RIVER" in i for i in ast.inherits)
    arrive_room = sets.get("arrive_room") if is_river else None

    room_block = (
        f'    rooms "{room_id}" {{\n'
        f"      name = {_ucl_string(_extract_string(sets.get('short'), 'Room'))}\n"
        f"      description = {_ucl_string(_get_heredoc_or_set(heredocs, sets, 'long', ''))}\n"
        f"  x = {_coord_of(sets.get('x'))}\n"
        f"  y = {_coord_of(sets.get('y'))}\n"
        f"  z = {_coord_of(sets.get('z'))}\n"
    )

    flags = _build_room_flags(sets)
    if flags:
        room_block += "  flags = [\n" + "\n".join(f'            "{f}"' for f in flags) + "\n          ]\n"

    if ast.valid_leave is not None:
        vl = ast.valid_leave
        room_block += (
            'behavior = "guarded_exit"\n'
            "behavior_config = {\n"
            f'  guard_npc = "{vl["guard_npc"]}"\n'
            f'  direction = "{_escape_set_string(vl["direction"])}"\n'
            f'  permit_module = "{vl["permit_module"]}"\n'
            f'  permit_function = "{vl["permit_function"]}"\n'
            "}\n"
        )

    room_block += _generate_room_item_desc(sets)
    room_block += _generate_room_exit_vetoes(ast)

    if is_river:
        room_block += (
            "  # River actions: yell [boat] / cross\n"
            "  # - yell boat: summons river_boat to arrive_room (3s)\n"
            "  # - cross: requires dodge>=270 & neili>=300, moves to arrive_room\n"
        )

    room_block += "    }"

    exits_block = ""
    exits = sets.get("exits")
    if isinstance(exits, tuple) and exits[0] == "mapping":
        exit_lines = []
        skipped = []
        skipped_bad_dir = []
        skipped_unlinkable = []
        for key, val in exits[1]:
            direction = _exit_key(key)
            direction = re.sub(r'^"|"$', "", direction)
            reason = _exit_dir_skip_reason(direction)
            if reason is not None:
                # Either a C-comment artefact (stripping the comment left nothing
                # behind, see _strip_exit_c_comments) or a genuine LPC direction
                # elias cannot lex as a key: shaolin's CJK bagua directions
                # (乾/巽/...) and huashan's "hole1".."hole6".  In both cases no
                # spelling of `direction = target` parses, so the exit is dropped
                # and the reason recorded.
                skipped_bad_dir.append((direction or "<empty>", reason))
                continue
            if isinstance(val, tuple) and val[0] == "mapping":
                # A portal descriptor such as city/mudren.c's "enter" points at
                # a raw LPC file plus x_axis/y_axis instead of at a room in this
                # zone, so it has no rooms.<id>.id form.  Record it and move on
                # rather than emitting a dangling target the loader would follow.
                skipped.append(direction)
                continue
            target, why = _resolve_exit_target(val, zone_id, room_id,
                                               direction=direction)
            if target is None:
                # No data/world zone to point at (/clone/shop, /b/, __FILE__,
                # a relative path, ...).  Dropping it is correct: a bare
                # `rooms.<x>.id` would resolve inside THIS zone and could link
                # to an unrelated local room.
                skipped_unlinkable.append("%s: %s" % (direction, why))
                continue
            exit_lines.append(f"  {direction} = {target}")
        river_exit = ""
        if is_river and arrive_room:
            river_target, _ = _resolve_exit_target(arrive_room, zone_id)
            river_exit = ("  river = " + river_target) if river_target else ""
        all_exit_lines = "\n".join(exit_lines)
        if river_exit != "":
            all_exit_lines = all_exit_lines + "\n" + river_exit if all_exit_lines else river_exit
        if all_exit_lines:
            exits_block = (
                f'  room_exits "{room_id}" {{\n'
                f"    room_id = rooms.{room_id}.id\n"
                f"{all_exit_lines}  }}\n"
            )
        # Emitted after the closing brace: a '#' comment runs to end of line and
        # would otherwise swallow that brace.
        for direction in skipped:
            exits_block += (
                f"  # skipped non-room exit '{direction}': LPC portal/mapping target\n"
            )
        for direction, reason in skipped_bad_dir:
            exits_block += (
                f"  # skipped exit direction '{direction}': {reason}\n"
            )
        for note in skipped_unlinkable:
            exits_block += (
                f"  # skipped exit {note}: no data/world zone to reference\n"
            )
    else:
        if is_river and arrive_room:
            target, _ = _resolve_exit_target(arrive_room, zone_id)
            if target:
                exits_block = (
                    f'  room_exits "{room_id}" {{\n'
                    f"    room_id = rooms.{room_id}.id\n"
                    f"  river = {target}\n"
                    "  }\n"
                )

    src_dir = os.path.dirname(ast.source_path) if ast.source_path else None
    branches = create.get("object_branches")

    if branches:
        objects_block = _generate_room_object_sets(room_id, branches, src_dir=src_dir)
    else:
        objects_block = _generate_room_objects(
            room_id, sets.get("objects"), src_dir=src_dir)

    return "\n\n".join([x for x in [room_block, exits_block, objects_block] if x != ""])


def _contains_npc(path):
    """Last-resort guess for a set("objects") path that names no readable file.

    Kept only as the fallback of _object_is_npc/3 -- "npc" in the path catches
    the /d/<zone>/npc/*.c spelling and nothing else.  It cannot see
    /kungfu/class/<sect>/*.c, /clone/{quarry,worm,beast}/*.c, or
    /d/hangzhou/honghua/huo, which is 431 of the 437 refs it used to misfile.
    """
    return "npc" in path


def _object_is_npc(path, literal, src_dir):
    """Is this one set("objects") entry a person?

    The entry is resolved to its LPC file and classified by the inherit chain,
    which is the same verdict the definition side now uses.  `path` is the raw
    entry and `literal` its path-with-the-runtime-suffix-stripped form; only
    `path` still names the CLASS_D()/__DIR__ part that says which file it is.
    """
    if src_dir is not None:
        f = LP.object_file(path, src_dir)
        if f and os.path.exists(f):
            return LP.resolve_type(f) == "npc"
    return _contains_npc(literal)


def _count_or_one(value):
    if isinstance(value, tuple) and value[0] == "int":
        return max(value[1], 1)
    return 1


def _extract_key_path(key):
    if isinstance(key, tuple) and key[0] == "var":
        return key[1]
    if isinstance(key, tuple) and key[0] == "string":
        return key[1]
    return None


def _looks_like_path(s):
    """Heuristic: a string that looks like a file path (contains / or __DIR__)."""
    return isinstance(s, str) and ("/" in s or "__DIR__" in s)


# Characters that mark a path fragment as a runtime expression rather than a
# literal file path: array subscript (books[random(...)]), interpolation ($x),
# parentheses (sizeof(...)).
_DYNAMIC_EXPR_RE = re.compile(r'[\[\]()]|\$[A-Za-z_]')

# A trailing runtime operand appended to a literal path:
#     "/clone/book/" + books[random(sizeof(books))]
#     "d/shaolin/obj/fojing1" + random(2)
# The literal prefix is still a perfectly good path; only the operand is dynamic.
_PATH_CONCAT_RE = re.compile(r'^(?P<prefix>[^+\[\]()$]*?)\s*\+\s*(?P<operand>.+)$')

# `random(n)` - the LPC driver returns an int in [0, n-1], and `+` on a string
# CONCATENATES its decimal form.  So a key written as
#     "d/shaolin/obj/fojing1" + random(2)
# names exactly these two files:
#     d/shaolin/obj/fojing10   (random(2) -> 0)
#     d/shaolin/obj/fojing11   (random(2) -> 1)
# which is precisely the object set that exists on disk (shaolin/obj/ has
# fojing10.c, fojing11.c, fojing20.c, fojing21.c and no fojing1.c/fojing2.c).
_RANDOM_CALL_RE = re.compile(r'^random\(\s*(\d+)\s*\)$')

# Object ids must be bare UCL identifiers: lowercase letters, digits, underscore.
_SAFE_ID_RE = re.compile(r'^[a-z0-9_]+$')


def _random_candidates(base, operand):
    """Candidate object ids for `"<base>" + random(n)`, or None if not that shape.

    The operand is concatenated verbatim (``str(random(n))``), NOT treated as a
    file-stem suffix.  shaolin/cjlou.c writes

        "d/shaolin/obj/fojing1" + random(2) : 1,
        "d/shaolin/obj/fojing2" + random(2) : 1,

    so the driver picks one of fojing10 / fojing11 and one of fojing20 /
    fojing21 - all four of which exist.  Emitting every candidate keeps that
    information instead of dropping the key, which is what the previous
    "contains a paren -> dynamic" rule did, silently and with no comment.
    """
    m = _RANDOM_CALL_RE.match(operand.strip())
    if not m or not base:
        return None
    n = int(m.group(1))
    if n <= 0:
        return None
    return ["%s%d" % (base, i) for i in range(n)]


def _split_runtime_suffix(path):
    """Split `"<literal path>" + <operand>` into (path, candidate ids or None).

    Returns ``(path, None)`` when there is no concatenation, and
    ``(path, [ids...])`` when the operand is an enumerable ``random(n)``.
    Returns ``(None, None)`` when the path cannot be resolved statically.

    The concatenation is examined BEFORE the bracket check on purpose: an
    operand such as ``random(2)`` contains parentheses, so testing for brackets
    first would reject every ``"<path>" + random(n)`` key before the split ever
    ran - which is exactly the bug that dropped shaolin's fojing entries.
    """
    if not isinstance(path, str):
        return None, None

    stripped = path.strip()
    if "+" in stripped:
        m = _PATH_CONCAT_RE.match(stripped)
        if m:
            prefix = m.group("prefix").strip().replace('"', "").replace("'", "")
            operand = m.group("operand").strip()
            if prefix:
                cands = _random_candidates(prefix, operand)
                if cands is not None:
                    return prefix, cands
                # A concatenation whose right-hand side is itself a plain path
                # literal is still resolvable; anything else (a variable, a
                # nested call, an array subscript) names no determinate file.
                if operand.startswith('"') or "__DIR__" in operand or "/" in operand:
                    return stripped, None
                return None, None

        # The prefix could not be split off because it is itself an expression,
        # most often the CLASS_D(...) idiom:
        #     CLASS_D("shaolin") + "/dao-yi"
        # Here the RIGHT-hand side is a plain literal and decides the object id
        # (the class prefix only supplies the directory), so take the basename of
        # the last operand.  This is what keeps dao_yi / wuming / tao_yi in the
        # room_items lists.
        tail = stripped.rsplit("+", 1)[-1].strip().replace('"', "").replace("'", "")
        if tail.startswith("/") or tail.startswith("__DIR__"):
            return tail, None

        return None, None

    return stripped, None



def _is_dynamic_expr(path):
    """True when a key path cannot be resolved to any object id at all.

    ``"/clone/book/" + books[random(sizeof(books))]`` is a *string* whose text
    contains "/", so :func:`_looks_like_path` accepts it, but the trailing
    ``books[random(sizeof(books))]`` names no determinate file.  Such keys must be
    skipped rather than leak LPC source into the generated UCL.

    Note this deliberately no longer rejects a merely-parenthesised path:
    ``"d/shaolin/obj/fojing1"+random(2)`` *is* resolvable (see
    :func:`_random_candidates`), and dropping it lost real content silently.
    """
    if not isinstance(path, str):
        return False
    literal, cands = _split_runtime_suffix(path)
    if literal is None:
        return True
    if cands is not None:
        return False
    # Still dynamic when a bracket/interpolation survives in the literal part,
    # e.g. "/clone/book/" + books[random(sizeof(books))].
    return bool(_DYNAMIC_EXPR_RE.search(literal))



def _room_object_links(value, src_dir=None):
    """Turn one parsed set("objects") mapping into character / item UCL lines."""
    char_links = []
    item_links = []
    skipped_dynamic = []
    if not (isinstance(value, tuple) and value[0] == "mapping"):
        return char_links, item_links, skipped_dynamic
    for key, count in value[1]:
        path = _extract_key_path(key)
        if path is None or not _looks_like_path(path):
            # Skip keys that are expressions (like names[random(sizeof(names))])
            # rather than simple file paths
            continue

        # A key may be "<literal path>" + random(n).  The literal part is a real
        # path and random(n) enumerates n candidates.  LPC evaluates random(n)
        # ONCE per key at load time, so the room ends up with exactly ONE of the
        # candidates - not all of them.  Emit them as an alternative list and let
        # Kantele.World.Loader pick one, the same way exits do; writing every
        # candidate out would put four fojings in emei/cangjingge.c's
        # "obj/fojing1" + random(2) / "obj/fojing2" + random(2) where the MUD
        # puts two.
        literal, cands = _split_runtime_suffix(path)
        if literal is None or _is_dynamic_expr(path):
            # Not resolvable to any id (e.g. "/clone/book/" + books[random(...)]).
            # Emitting it would leak LPC source into the UCL and break the parser.
            skipped_dynamic.append(path)
            continue

        if cands is not None:
            ids = [_room_id_from_path(c) for c in cands]
            ids = [i for i in ids if _SAFE_ID_RE.match(i)]
            if not ids:
                continue
            n = _count_or_one(count)
            # `n` copies of "one of these", e.g. random(2) listed twice.
            joined = ",".join("items.%s.id" % i for i in ids)
            for _ in range(n):
                item_links.append("      { id = [%s] }" % joined)
            continue

        id_ = _room_id_from_path(literal)
        if not _SAFE_ID_RE.match(id_):
            # Defensive: never emit an id that is not a bare UCL identifier.
            continue
        n = _count_or_one(count)
        if _object_is_npc(path, literal, src_dir):
            char_links.extend(
                [f"      {{ id = characters.{id_}.id }}" for _ in range(n)])
        else:
            # The count means the same thing for things as for people: LPC's
            # `"/clone/money/gold" : 10` puts ten gold in the room.  Only the
            # character branch used to honour it, so 131 entries across the
            # corpus were written as a single reference -- including taohua/mushi's
            # gold, which is 10 in the top branch.
            item_links.extend(
                [f"      {{ id = items.{id_}.id }}" for _ in range(n)])

    return char_links, item_links, skipped_dynamic


def _generate_room_object_sets(room_id, branches, src_dir=None):
    """Emit `room_object_sets` for a room that picks a whole layout at random.

    See `_parse_object_branches` for why the branches exist.  Each branch may mix
    people and things (taohua/daojufang's are `npc/yapu` plus a few items), so a
    group is a flat list of references whose kind is read off the prefix --
    `characters.` or `items.`.

    Branches that resolve to nothing are dropped rather than emitted as an empty
    group: heimuya/house1's 1-in-6 branch holds only `/kungfu/class/...`, which
    is a kungfu definition rather than something a room can contain.  Dropping
    it also leaves a single group, in which case we emit the ordinary
    `room_items` / `room_characters` blocks instead -- no new data shape needed
    for a room that never actually branches.
    """
    resolved = []
    for branch in branches:
        char_links, item_links, skipped = _room_object_links(branch, src_dir)
        if char_links or item_links:
            resolved.append((char_links, item_links))
        else:
            for p in skipped:
                print("  # note: branch dropped, no determinate object id: %r" % p)

    if not resolved:
        return ""

    # Branches that all come out identical are not a random room.  jueqing/house's
    # two branches differ only by a /kungfu/class/... entry that no room can hold,
    # so without this it would ship two identical groups.
    first = resolved[0]
    if all(r == first for r in resolved[1:]):
        char_links, item_links = first
        return _emit_room_object_blocks(room_id, char_links, item_links, [])

    groups = []
    for char_links, item_links in resolved:
        # Strip the per-link indent the flat form uses; a group is indented once.
        refs = [re.sub(r"^\s+", "", link)
                for link in (char_links + item_links)]
        # elias 0.2.8 parses neither a list of lists nor a multi-key anonymous
        # object, so a group is a single-key object and list order is branch order.
        groups.append("      {\n        refs = [\n"
                      + ",\n".join("          " + ref for ref in refs)
                      + "\n        ]\n      }")

    return (
        f'\n\n  room_object_sets "{room_id}" {{\n'
        f"    room_id = rooms.{room_id}.id\n"
        "    sets = [\n"
        + ",\n".join(groups)
        + "\n    ]\n  }\n"
    )


def _generate_room_objects(room_id, value, src_dir=None):
    if value is None:
        return ""
    char_links, item_links, skipped_dynamic = _room_object_links(value, src_dir)
    return _emit_room_object_blocks(room_id, char_links, item_links,
                                    skipped_dynamic)


def _emit_room_object_blocks(room_id, char_links, item_links, skipped_dynamic):
    char_block = ""
    if char_links:
        char_block = (
            f'  room_characters "{room_id}" {{\n'
            f"    room_id = rooms.{room_id}.id\n"
            "    characters = [\n"
            + ",\n".join(char_links)
            + "    ]\n  }\n"
        )

    item_block = ""
    if item_links:
        item_block = (
            f'\n\n  room_items "{room_id}" {{\n'
            f"    room_id = rooms.{room_id}.id\n"
            "    items = [\n"
            + ",\n".join(item_links)
            + "    ]\n  }\n"
        )

    note_block = ""
    if skipped_dynamic:
        note_block = "\n".join(
            "  # skipped unresolvable object path %r: no determinate object id"
            % p for p in skipped_dynamic)

    return "\n".join(
        [x for x in [char_block, item_block, note_block] if x != ""])


# ---------------------------------------------------------------------------
# NPC generation
# ---------------------------------------------------------------------------
def _add_if_present(acc, sets, key, type_):
    v = sets.get(key)
    if isinstance(v, tuple) and v[0] == "string":
        return [f'  {key} = "{_escape_set_string(v[1])}"'] + acc
    if isinstance(v, tuple) and v[0] == "int":
        return [f"  {key} = {v[1]}"] + acc
    return acc


def _infer_brain(inherits):
    for kw, brain in [("VENDOR", "vendor"), ("DEALER", "dealer"), ("GUARD", "guarder"),
                      ("BANKER", "banker"), ("HORSE", "horseboss"), ("QUEST", "quester")]:
        if any(kw in i for i in inherits):
            return brain
    return None


def _build_npc_combat(sets):
    # Elixir small maps iterate in Erlang term order (bytewise-sorted keys)
    combat_fields = [
        ("attitude", ("string", "peaceful")),
        ("combat_exp", ("int", 0)),
        ("con", ("int", 10)),
        ("dex", ("int", 10)),
        ("int", ("int", 10)),
        ("max_jing", ("int", 100)),
        ("max_neili", ("int", 0)),
        ("max_qi", ("int", 100)),
        ("no_kill", ("bool", False)),
        ("respawn_delay", ("int", 0)),
        ("str", ("int", 10)),
    ]
    fields = []
    for key, _default in combat_fields:
        v = sets.get(key)
        if isinstance(v, tuple) and v[0] == "int":
            fields.append(f"    {key} = {v[1]}")
        elif isinstance(v, tuple) and v[0] == "string":
            fields.append(f'    {key} = "{v[1]}"')
        elif isinstance(v, tuple) and v[0] == "bool":
            fields.append(f"    {key} = {'true' if v[1] else 'false'}")
    return "\n".join(fields)


def _object_path(s):
    return "/" in s or s.endswith(".c") or s.startswith("__DIR__")


def _strip_object_dir_prefix(path):
    path = re.sub(r'^__DIR__"', "", path)
    path = re.sub(r'"$', "", path)
    return path.strip()


def _object_file_known(path, ast):
    stripped = _strip_object_dir_prefix(path)
    base = ast.base_path
    dir_ = os.path.dirname(ast.source_path)
    if stripped.startswith("/"):
        candidates = ["." + stripped, stripped]
    else:
        rel = re.sub(r'^"/d/', "", stripped)
        rel = rel.lstrip("/")
        candidates = [_normpath_forward(os.path.join(base, rel)),
                      _normpath_forward(os.path.join(dir_, rel)),
                      _normpath_forward(os.path.join(".", rel))]
    for cand in candidates:
        if os.path.exists(cand) or os.path.exists(cand + ".c"):
            return True
    return False


def _build_goods(sets, ast):
    entries = []
    comments = []
    for key in ["goods", "vendor_goods"]:
        v = sets.get(key, [])
        if isinstance(v, tuple) and v[0] == "array":
            for item in v[1]:
                if isinstance(item, tuple) and item[0] == "string":
                    s = item[1]
                    if _object_path(s) and not _object_file_known(s, ast):
                        comments.append(f'{key}: "{s}" (file not found)')
                    else:
                        entries.append(f"items.{_room_id_from_path(s)}.id")
                elif isinstance(item, tuple) and item[0] == "var":
                    entries.append(item[1])
    return entries, comments


def _build_inquiries(sets):
    inquiry_data = sets.get("inquiry") or sets.get("inquiries")
    comments = []
    if isinstance(inquiry_data, tuple) and inquiry_data[0] == "mapping":
        out = {}
        for k, v in inquiry_data[1]:
            key = _get_string(k)
            value = _get_string(v)
            if not _elias_safe_value(value):
                # No spelling of this value parses; see _elias_safe_value/1.
                comments.append(
                    "skipped inquiry %s: value %s is unparseable by elias "
                    "(digit immediately before a comma)" % (key, value)
                )
                continue
            out[key] = value
        return out, comments
    return {}, comments


def _get_string(value):
    if isinstance(value, tuple) and value[0] == "string":
        return _ucl_string(value[1])
    if isinstance(value, tuple) and value[0] == "int":
        return str(value[1])
    if isinstance(value, tuple) and value[0] == "var":
        return _ucl_string(value[1])
    if isinstance(value, str):
        return _ucl_string(value)
    return '"unknown"'


# elias 0.2.8 lexes with leex using
#     Word = [^0-9{}\*\/#\n\[\]=\s'":\;\\-]+
# Note that a COMMA is *not* in the exclusion set, so leex's longest match
# swallows "a," into a single `word` token.  A digit breaks that run, after
# which the comma lexes as its own `comma` token - and elias_parser.yrl has no
# `words -> comma ...` production, so Elias.parse/1 aborts with
#     syntax error before: ', ['","']
#
# Measured against elias 0.2.8 (mix run --no-start):
#     "(: a, 'b' :)"        -> parses   (comma absorbed into the word "a,")
#     "(: ab, 'c' :)"       -> parses
#     "(: a_b, 'c' :)"      -> parses
#     "(: a1, 'b' :)"       -> FAILS    (digit, then comma)
#     "(: ask_me_1, 'b' :)" -> FAILS
#
# A comma is therefore only safe when the character before it is one leex keeps
# inside the same word.  There is no alternative spelling: the grammar accepts a
# quoted string only as `double_quote words double_quote`, `words` has neither a
# comma nor a newline production, and no amount of backslash or extra quoting
# can hide the comma.  Such values must be dropped.
_ELIAS_WORD_STOP = frozenset("0123456789{}*/#\n[]= \t'\":;\\-")


def _elias_safe_value(ucl_string):
    """True when a rendered UCL string literal survives Elias.parse/1.

    `ucl_string` is the already-quoted literal produced by :func:`_ucl_string`.
    """
    if not isinstance(ucl_string, str):
        return False
    text = ucl_string[1:-1] if len(ucl_string) >= 2 and ucl_string[0] == '"' else ucl_string
    if text == "":
        return False
    for i, ch in enumerate(text):
        if ch == "," and i > 0 and text[i - 1] in _ELIAS_WORD_STOP:
            return False
    return True


def _generate_inquiries(inquiries):
    # Elixir map iteration = Erlang term order = bytewise-sorted keys
    items = sorted(inquiries.items(), key=lambda kv: kv[0].encode("utf-8"))
    return ",\n".join(f"    {{ key = {q} value = {a} }}" for q, a in items)


def _build_chat(sets):
    chance = sets.get("chat_chance")
    chats = sets.get("chats") or sets.get("chat_msg")
    if isinstance(chance, tuple) and chance[0] == "int" and chance[1] > 0 and \
            isinstance(chats, tuple) and chats[0] == "array":
        chat_lines = []
        for item in chats[1]:
            if isinstance(item, tuple) and item[0] == "string":
                chat_lines.append(_sanitize_message_text(_process_literal_string(item[1])))
        chat_lines = [x for x in chat_lines if x != ""]
        chat_lines = list(dict.fromkeys(chat_lines))
        if not chat_lines:
            return None
        rendered = ",\n".join(f'    "{_escape_set_string(x)}"' for x in chat_lines)
        return f"chat_chance = {chance[1]}\nchats = [\n{rendered}\n]\n"
    return None


def _build_enter_ucl(init):
    if init is None:
        return ""
    add_actions = init.get("add_actions", [])
    heartbeat = init.get("heartbeat", 0)
    greet_delay = init.get("greet_delay", 0)
    s = f"  init = {{\n    greet_delay = {greet_delay}\n"
    if heartbeat > 0:
        s += f"    heartbeat = {heartbeat}\n"
    if add_actions:
        s += "    add_actions = [" + ", ".join(f'"{a}"' for a in add_actions) + "]\n"
    s += "  }"
    return s


def _build_greetings_ucl(lines):
    if not lines:
        return ""
    rendered = ",\n".join(f'    {{ line = "{_escape_heredoc_content(line)}" }}' for line in lines)
    return f"  greetings = [\n{rendered}\n  ]"


def _render_accept_msg(msg):
    if isinstance(msg, list) and msg:
        return "[" + ", ".join(f'"{_escape_set_string(x)}"' for x in msg) + "]"
    if isinstance(msg, str):
        return f'"{_escape_set_string(msg)}"'
    return None


def _build_accept_ucl(rules):
    if not rules:
        return ""
    entries = []
    for rule in rules:
        s = f'    {{ kind = "{rule["kind"]}"'
        if rule.get("min") is not None:
            s += f' min = {rule["min"]}'
        if rule.get("id") is not None:
            s += f' id = "{rule["id"]}"'
        if rule.get("name") is not None:
            s += f' name = "{rule["name"]}"'
        if isinstance(rule.get("accept"), bool):
            s += f" accept = {str(rule['accept']).lower()}"
        else:
            s += " accept = true"
        msg = _render_accept_msg(rule.get("msg"))
        if msg is not None:
            s += f" msg = {msg}"
        fail_msg = _render_accept_msg(rule.get("fail_msg"))
        if fail_msg is not None:
            s += f" fail_msg = {fail_msg}"
        s += " }"
        entries.append(s)
    return "  accept = [\n" + ",\n".join(entries) + "\n  ]"


def _build_guarder_ucl(guard):
    if not guard:
        return ""
    family = guard.get("family")
    refuse_other = guard.get("refuse_other")
    if family is None:
        return ""
    s = f'  meta = {{\n    guarder = {{\n      family = "{family}"\n'
    if refuse_other:
        s += f'      msgs = {{ refuse_other = "{_escape_set_string(refuse_other)}" }}\n'
    s += "    }\n  }"
    return s


def _build_engage_ucl(engage):
    if not engage:
        return ""
    entries = []
    for kind in ["fight", "hit", "kill"]:
        rule = engage.get(kind)
        if rule is None:
            continue
        accept = rule.get("accept")
        if accept is None:
            continue
        s = f"    {kind} = {{ accept = {str(accept).lower()}"
        if rule.get("msg"):
            s += f' msg = "{_escape_set_string(rule["msg"])}"'
        if rule.get("retaliate"):
            s += " retaliate = true"
        if rule.get("spawn"):
            s += " spawn = [" + ", ".join(f'"{x}"' for x in rule["spawn"]) + "]"
        s += " }"
        entries.append(s)
    if not entries:
        return ""
    return "  engage = {\n" + "\n".join(entries) + "\n  }"


def _build_skills_block(calls):
    skills = calls.get("set_skill", [])
    map_skills = calls.get("map_skill", [])
    skill_lines = []
    for args in skills:
        if len(args) == 2 and args[0][0] == "string" and args[1][0] in ("int", "string"):
            skill_lines.append(f'    {{ skill = "{args[0][1]}" level = {args[1][1]} }}')
    map_lines = []
    for args in map_skills:
        if len(args) == 2 and args[0][0] == "string" and args[1][0] == "string":
            map_lines.append(f'    {{ type = "{args[0][1]}" skill = "{args[1][1]}" }}')
    all_lines = skill_lines + map_lines
    if not all_lines:
        return ""
    return "  skills = [\n" + ",\n".join(all_lines) + "\n  ]\n"


def _build_carry_block(calls):
    carry_objects = calls.get("carry_object", [])
    if not carry_objects:
        return ""
    items = []
    for args in carry_objects:
        if args and args[0][0] in ("string", "var"):
            items.append(f"items.{_room_id_from_path(args[0][1])}.id")
        else:
            items.append("items.unknown.id")
    return "  carry = [\n" + ",\n".join(f"    {{ id = {x} }}" for x in items) + "\n  ]\n"


def _generate_npc_ucl(ast, zone_id):
    create = ast.create_fn
    sets = create.get("sets", {})
    set_name = create.get("set_name", {})
    heredocs = (ast.heredocs or {}).get("heredocs", {})

    npc_id = _norm_id(_path_basename_rootname(ast.source_path))
    name = _extract_string(set_name.get("name"), _extract_string(sets.get("name"), "NPC"))
    aliases = set_name.get("aliases", [])

    ucl = (
        f'    characters "{npc_id}" {{\n'
        f"      name = {_ucl_string(name)}\n"
        f"      description = {_ucl_string(_get_heredoc_or_set(heredocs, sets, 'long', ''))}\n"
    )

    basic_attrs = []
    for key in ["title", "nickname", "gender", "age", "shen_type", "score", "startroom"]:
        basic_attrs = _add_if_present(basic_attrs, sets, key, "int" if key in ("age", "shen_type", "score") else "string")

    # Elixir generate_npc_ucl: the aliases rebinding sits inside an `if`
    # block whose scope discards it -> aliases never emitted. Reproduce that.
    basic_block = ""
    if basic_attrs:
        basic_block = "\n".join(list(reversed(basic_attrs))) + "\n"

    brain = _infer_brain(ast.inherits)
    brain_line = f"  brain = brains.{brain}\n" if brain else ""

    combat = _build_npc_combat(sets)
    goods, goods_comments = _build_goods(sets, ast)
    inquiries, inquiry_comments = _build_inquiries(sets)
    chat = _build_chat(sets)
    function_calls = ast.function_calls
    skills_block = _build_skills_block(function_calls)
    carry_block = _build_carry_block(function_calls)
    init_block = _build_enter_ucl(ast.enter)
    greetings_block = _build_greetings_ucl(ast.greetings)
    accept_block = _build_accept_ucl(ast.accept)
    guarder_block = _build_guarder_ucl(ast.guard)
    engage_block = _build_engage_ucl(ast.engage)

    out = ucl + basic_block + brain_line
    if combat:
        out += f"\n  combat = {{\n{combat}\n  }}\n"
    if goods:
        out += "\n  goods = [\n" + ",\n".join(f"    {{ id = {x} }}" for x in goods) + "\n  ]\n"
    if goods_comments:
        out += "\n" + "\n".join(f"  # {x}" for x in goods_comments) + "\n"
    if inquiries:
        out += "\n  inquiries = [\n" + _generate_inquiries(inquiries) + "\n  ]\n"
    if inquiry_comments:
        out += "\n" + "\n".join(f"  # {x}" for x in inquiry_comments) + "\n"
    if chat:
        out += f"\n  {chat}\n"
    if skills_block:
        out += f"\n{skills_block}\n"
    if carry_block:
        out += f"\n{carry_block}\n"
    if init_block:
        out += f"\n{init_block}\n"
    if greetings_block:
        out += f"\n{greetings_block}\n"
    if accept_block:
        out += f"\n{accept_block}\n"
    if guarder_block:
        out += f"\n{guarder_block}\n"
    if engage_block:
        out += f"\n{engage_block}\n"
    out += "    }"
    return out


# ---------------------------------------------------------------------------
# Item generation
# ---------------------------------------------------------------------------
def _infer_verbs(inherits, sets):
    base = ["get", "drop"]
    if any(("WEAPON" in i or "SWORD" in i or "BLADE" in i) for i in inherits):
        return base + ["wield", "unwield"]
    if any("ARMOR" in i for i in inherits):
        return base + ["wear", "remove"]
    if any(("FOOD" in i or "EDIBLE" in i) for i in inherits):
        return base + ["eat"]
    if "wield_msg" in sets:
        return base + ["wield", "unwield"]
    if "wear_msg" in sets:
        return base + ["wear", "remove"]
    return base


def _infer_skill_type(inherits):
    for kws, sk in [
        (["SWORD"], "sword"),
        (["BLADE", "DAO"], "blade"),
        (["STAFF", "GUN"], "staff"),
        (["WHIP", "BIAN"], "whip"),
        (["DAGGER"], "dagger"),
        (["THROWING"], "throwing"),
        (["HAMMER"], "hammer"),
        (["AXE"], "axe"),
        (["FIST", "UNARMED"], "unarmed"),
        (["FINGER"], "finger"),
        (["CLAW"], "claw"),
        (["PALM", "STRIKE"], "strike"),
    ]:
        if any(kw in i for i in inherits for kw in kws):
            return sk
    return "sword"


def _build_item_meta(sets, inherits):
    meta = {}
    for key in ["weapon_prop", "damage"]:
        if sets.get(key) is not None:
            meta["damage"] = sets[key]
    if sets.get("skill_type") is not None:
        meta["skill_type"] = sets["skill_type"]
    else:
        meta["skill_type"] = ("string", _infer_skill_type(inherits))
    if sets.get("armor") is not None:
        meta["armor"] = sets["armor"]
    if sets.get("armor_type") is not None:
        meta["armor_type"] = sets["armor_type"]
    for key in ["value", "weight", "unit", "material"]:
        if sets.get(key) is not None:
            meta[key] = sets[key]
    if sets.get("flag") is not None:
        meta["flag"] = sets["flag"]
    for key in ["food", "medicine", "book"]:
        if sets.get(key) is not None:
            meta[key] = sets[key]
    if sets.get("weapon_prop") is not None:
        meta["weapon_prop"] = sets["weapon_prop"]
    if sets.get("armor_prop") is not None:
        meta["armor_prop"] = sets["armor_prop"]
    return meta


def _format_meta_value(value):
    if isinstance(value, tuple) and value[0] == "string":
        return f'"{_escape_set_string(value[1])}"'
    if isinstance(value, tuple) and value[0] == "int":
        return str(value[1])
    if isinstance(value, tuple) and value[0] == "float":
        return str(value[1])
    if isinstance(value, tuple) and value[0] == "bool":
        return "true" if value[1] else "false"
    if isinstance(value, tuple) and value[0] == "array":
        return "[\n" + ",\n".join(_format_meta_value(x) for x in value[1]) + "\n    ]"
    if isinstance(value, tuple) and value[0] == "mapping":
        return "{\n" + ",\n".join(
            f"      {_format_meta_value(k)} = {_format_meta_value(v)}" for k, v in value[1]
        ) + "\n    }"
    if isinstance(value, tuple) and value[0] == "var":
        return value[1]
    return "nil"


def _generate_meta(meta):
    return "\n".join(f"    {k} = {_format_meta_value(v)}" for k, v in meta.items())


def _generate_item_ucl(ast, zone_id):
    create = ast.create_fn
    sets = create.get("sets", {})
    set_name = create.get("set_name", {})
    heredocs = (ast.heredocs or {}).get("heredocs", {})

    item_id = _norm_id(_path_basename_rootname(ast.source_path))

    name = "Item"
    sv = set_name.get("name")
    if isinstance(sv, tuple) and sv[0] == "string":
        name = sv[1]
    elif isinstance(sv, str):
        name = sv
    else:
        nv = sets.get("name")
        if isinstance(nv, tuple) and nv[0] == "string":
            name = nv[1]
        elif isinstance(nv, str):
            name = nv

    ucl = (
        f'    items "{item_id}" {{\n'
        f"      name = {_ucl_string(name)}\n"
        f"      description = {_ucl_string(_get_heredoc_or_set(heredocs, sets, 'long', ''))}\n"
    )

    verbs = _infer_verbs(ast.inherits, sets)

    out = ucl + "  verbs = [\n" + ",\n".join(f'    "{v}"' for v in verbs) + "\n  ]\n"
    if "wield_msg" in sets or "unwield_msg" in sets:
        wield_str = _escape_set_string(_extract_string(sets.get("wield_msg"), ""))
        unwield_str = _escape_set_string(_extract_string(sets.get("unwield_msg"), ""))
        out += "\n  messages = {\n"
        if wield_str != "":
            out += f'    wield = "{wield_str}"\n'
        if unwield_str != "":
            out += f'    unwield = "{unwield_str}"\n'
        out += "  }\n"
    out += "    }"
    return out


def _generate_skill_ucl(ast, zone_id):
    return (f"# Skill file: {ast.source_path}\n"
            "# Skills are implemented as Elixir modules in lib/kantele/combat/skills/")


def _generate_generic_ucl(ast, zone_id):
    return f"# Generic LPC file: {ast.source_path}\n# Requires manual conversion"


# ---------------------------------------------------------------------------
# Unhandled comments
# ---------------------------------------------------------------------------
def _sanitize_comment_text(text):
    text = text.replace("\\", "\\\\")
    text = text.replace('"', "'")
    text = text.replace("\n", " ")
    text = text.replace("\r", " ")
    text = text.replace('\\"', "'")
    text = text.replace("\\n", "\\\\n")
    text = text.replace("\\t", "\\\\t")
    text = text.replace("\\r", "\\\\r")
    text = _ESC_SEQ.sub(r"\\\\\g<0>", text)
    return text


def _generate_unhandled_comments(unhandled):
    sections = []

    if unhandled.get("functions"):
        sections.append(["# ==== UNHANDLED FUNCTIONS ===="] +
                        [f"  # UNHANDLED FUNCTION: {name}" for name in unhandled["functions"]])

    if unhandled.get("globals"):
        sections.append(["# ==== UNHANDLED GLOBAL VARIABLES ===="] +
                        [f"  # UNHANDLED GLOBAL: {g['type']} {g['name']}" for g in unhandled["globals"]])

    if unhandled.get("complex_mappings"):
        sections.append(["# ==== COMPLEX MAPPINGS ===="] +
                        [f"  # COMPLEX MAPPING: {_trim(m)}" for m in unhandled["complex_mappings"]])

    if unhandled.get("switch_tables"):
        table_list = []
        for t in unhandled["switch_tables"]:
            table_list.append(f"  # SWITCH TABLE (expr: {t['expr']})")
            table_list.append("  # " + "-" * 64)
            for row in t["rows"]:
                cols_str = " ".join(f"{v}={val}" for v, val in row["cols"])
                table_list.append(f"  #   {row['key']}: {cols_str}")
        sections.append(["# ==== SWITCH TABLES ===="] + table_list)

    if unhandled.get("switch_pools"):
        pool_list = []
        for stmt in unhandled["switch_pools"]:
            lines = [f"  # SWITCH POOL: {_trim(l)}" for l in stmt.split("\n")]
            pool_list.append("\n".join(lines))
        sections.append(["# ==== SWITCH POOLS ===="] + pool_list)

    if unhandled.get("switch_statements"):
        switch_list = []
        for stmt in unhandled["switch_statements"]:
            lines = [f"  # SWITCH: {_trim(l)}" for l in stmt.split("\n")]
            switch_list.append("\n".join(lines))
        sections.append(["# ==== SWITCH STATEMENTS ===="] + switch_list)

    if unhandled.get("conditional_branches"):
        branch_sections = []
        for fn_name, chains in unhandled["conditional_branches"].items():
            header = f"# ==== CONDITIONAL BRANCHES ({fn_name}) ===="
            chain_lines = []
            for chain in chains:
                for branch in chain:
                    kind = branch["kind"]
                    if kind == "if":
                        prefix = f"if ({branch['cond']})"
                    elif kind == "elif":
                        prefix = f"else if ({branch['cond']})"
                    else:
                        prefix = "else"
                    actions = " ".join(branch["actions"])
                    sanitized_actions = _sanitize_comment_text(actions)
                    chain_lines.append(f"  # {prefix}  →  {sanitized_actions}")
            branch_sections.append([header] + chain_lines)
        sections.append(["# ==== CONDITIONAL BRANCHES ===="] +
                        [l for sec in branch_sections for l in sec])

    if unhandled.get("complex_conditionals"):
        cond_list = []
        for stmt in unhandled["complex_conditionals"]:
            lines = [f"  # COMPLEX IF: {_trim(l)}" for l in stmt.split("\n")]
            cond_list.append("\n".join(lines))
        sections.append(["# ==== COMPLEX CONDITIONALS ===="] + cond_list)

    if unhandled.get("raw_code_blocks"):
        block_list = []
        for b in unhandled["raw_code_blocks"]:
            lines = [f"  # {b['name']}: {_trim(l)}" for l in b["body"].split("\n")]
            block_list.append("\n".join(["  # RAW BLOCK: " + b["name"]] + lines))
        sections.append(["# ==== RAW CODE BLOCKS ===="] + block_list)

    flat = [x for sec in sections for x in sec]
    if not flat:
        return ""
    header = "\n\n# ========================================\n# UNHANDLED CONTENT (for manual review)\n# ========================================\n"
    body = "\n".join(reversed(flat))
    footer = "\n# ========================================\n"
    return header + body + footer


# ---------------------------------------------------------------------------
# Main convert path
# ---------------------------------------------------------------------------
def _parse_lpc(content: bytes, source_path: str, base_path: str):
    """Return AST or None on failure."""
    try:
        utf8_content = _to_utf8(content)

        heredocs = _parse_heredocs_from_raw(utf8_content)
        content_for_brace = _strip_heredocs_for_brace(utf8_content)
        create_body = _extract_create_body(content_for_brace)
        # Both comment syntaxes, not just `//`.  `create_body` is cut out of the RAW
        # text, so before this only line comments were removed and a block comment
        # survived into the parsed values.  That silently cost 18 room objects: the
        # corpus writes the object count as a block comment immediately before the
        # list, e.g.
        #     set("objects", ([ /* sizeof() == 5 */ __DIR__"npc/fujiang" : 1, ...
        # so the path arrived as '/* sizeof() == 5 */\n  __DIR__"npc/fujiang"',
        # had no determinate object id, and the whole entry was dropped with a
        # `# skipped unresolvable object path` comment (changan 8, meizhuang 4,
        # tiezhang 3, death 1, hangzhou 1, wanjiegu 1).  400 corpus files carry a
        # block comment inside create(); only those 18 entries actually broke.
        create_body = _strip_c_comments(_strip_cpp_comments(create_body))

        cleaned = _preprocess(utf8_content)

        create_fn = _parse_create_function(cleaned, create_body)
        # Kept apart from `sets`: the whole point is that `sets["objects"]` has
        # already collapsed the chain to its last branch.
        create_fn["object_branches"] = _parse_object_branches(create_body)
        create_fn = _backfill_exits_outside_create(cleaned, create_fn)
        # Elixir: create_body || find_create_body(content) — "" is truthy, so
        # create_body (always a string) wins; find_create_body only for nil.
        function_calls = _parse_function_calls(create_body if create_body is not None else (_find_create_body(cleaned) or ""))

        handled = {"create", "init", "greeting", "accept_object", "permit_pass", "valid_leave"}
        other_fns = _parse_other_functions(cleaned)
        other_fn_names = {f["name"] for f in other_fns}
        unhandled_fns = other_fn_names - handled

        unhandled = _extract_unhandled_content(cleaned, unhandled_fns)
        inherits = _parse_inherits(cleaned)
        inherit_files = _parse_inherit_files(cleaned, source_path)
        globals_ = _parse_globals(cleaned)
        valid_leave = _parse_valid_leave(cleaned)
        exit_vetoes = _parse_exit_vetoes(cleaned)
        enter = _extract_enter(cleaned)
        greetings = _extract_greetings(cleaned)
        accept = _extract_accept(cleaned)
        guard = _extract_guard(cleaned)
        engage = _extract_engage(cleaned)

        return AST(
            inherits=inherits,
            inherit_files=inherit_files,
            create_fn=create_fn,
            other_fns=other_fns,
            globals=globals_,
            heredocs=heredocs,
            source_path=source_path,
            base_path=base_path,
            valid_leave=valid_leave,
            exit_vetoes=exit_vetoes,
            function_calls=function_calls,
            enter=enter,
            greetings=greetings,
            accept=accept,
            guard=guard,
            engage=engage,
            unhandled=unhandled,
        )
    except Exception:
        return None


def _parse_create_function(content, create_body=None):
    body = create_body if create_body is not None else _find_create_body(content)
    if body is None:
        return {}
    return _parse_create_body(body)


def _backfill_exits_outside_create(cleaned, create_fn):
    """Recover `set("exits", ...)` written outside create().

    create() is where the corpus normally declares a room's exits, and it stays
    authoritative here.  But four corpus files put the call somewhere else, and two
    of them are rooms:

        death/god1.c      void reset()      "down": "/d/city/wumiao"
        death/lunhuisi.c  void recreate()   "out" : __DIR__ "lunhuisi_road1"

    lunhuisi's create() body happens to overrun its own braces, so its recreate()
    exits were picked up anyway.  god1's did not: the room came out with no
    `room_exits` block at all, and assign_room_coords.py then covered the gap by
    synthesising up/down for the resulting orphan - silently replacing the author's
    `down : "/d/city/wumiao"`, the one intended link from 冥界 back to 扬州武馆, with
    a local hop to emptyroom.

    Only consulted when create() declares no exits whatsoever, so a room wired the
    normal way is untouched and lunhuisi's deliberately sealed create() (its `out`
    only appears after the 石桌 puzzle is solved) keeps what it already had.
    """
    if "exits" in create_fn.get("sets", {}):
        return create_fn
    outside = _parse_set_calls(cleaned).get("sets", {}).get("exits")
    if outside is None:
        return create_fn
    merged = dict(create_fn)
    merged["sets"] = dict(merged.get("sets", {}))
    merged["sets"]["exits"] = outside
    return merged


def _find_create_body(content):
    m = _CREATE_SIG.search(content)
    if m is None:
        return None
    brace_pos = m.end() - 1
    return _find_matching_brace(content, brace_pos)


def _generate_ucl(ast, zone_id, include_comments, include_header=True):
    header = f"# Generated from {ast.source_path} by LPCConverter\n# Zone: {zone_id}\n\n"

    merged = _merge_inherit_chain(ast)
    # _determine_object_type/1 only sees the inherits it could resolve, and a
    # bare marker names no type: `inherit QUARRY;` says nothing about being a
    # person.  LP.resolve_type/1 repeats that verdict and then, on "generic",
    # walks the base classes under mud/inherit/ -- where char/quarry.c is
    # `inherit NPC;`.  Without it every /clone/{quarry,worm,beast}/*.c and
    # /kungfu/class/<sect>/*.c came out "generic" and got no characters block.
    obj_type = LP.resolve_type(ast.source_path)

    if obj_type == "room":
        new_sections = [_generate_room_ucl(merged, zone_id)]
    elif obj_type == "npc":
        new_sections = [_generate_npc_ucl(ast, zone_id)]
    elif obj_type == "item":
        new_sections = [_generate_item_ucl(ast, zone_id)]
    elif obj_type == "skill":
        new_sections = [_generate_skill_ucl(ast, zone_id)]
    else:
        new_sections = [_generate_generic_ucl(ast, zone_id)]

    inherit_comments = ""
    if obj_type != "generic":
        parts = [i for i in ast.inherits if not _type_marker_inherit(i, obj_type)]
        inherit_comments = "\n".join(f"# inherit {i};" for i in parts)

    if obj_type == "generic":
        ucl_content = ""
    else:
        ucl_content = (header if include_header else "") + "\n\n".join(new_sections)

    comments_content = ""
    if include_comments:
        generic_marker = []
        if obj_type == "generic":
            generic_marker = [f"# Generic LPC file: {ast.source_path}", "# Requires manual conversion"]
        inherit_parts = [inherit_comments] if inherit_comments != "" else []
        unhandled_text = _generate_unhandled_comments(ast.unhandled)
        unhandled_parts = [unhandled_text] if unhandled_text != "" else []
        extra = "\n\n".join([x for x in generic_marker + inherit_parts + unhandled_parts if x != ""])
        if extra != "":
            comments_content = header + extra + "\n"

    return ucl_content, comments_content


def _merge_inherit_chain(ast):
    return _merge_inherit_level(ast, set())


def convert_file(lpc_path, zone_id=None, base_path=None, include_comments=True, include_header=True):
    if base_path is None:
        base_path = os.path.dirname(lpc_path)
    if zone_id is None:
        zone_id = _infer_zone_id(lpc_path, base_path)
    try:
        with open(lpc_path, "rb") as f:
            content = f.read()
    except OSError as e:
        return (None, None, f"File read failed: {e}")
    ast = _parse_lpc(content, lpc_path, base_path)
    if ast is None:
        return (None, None, "Parse failed")
    ucl, comments = _generate_ucl(ast, zone_id, include_comments, include_header)
    return (ucl, comments, None)


def _infer_zone_id(lpc_path, base_path=None):
    return _norm_id(_path_basename_rootname(lpc_path))


# ---------------------------------------------------------------------------
# CLI (mirrors mix kantele.convert_lpc recursive directory mode)
# ---------------------------------------------------------------------------
def _normpath_forward(p):
    """Elixir Path.join / Path.dirname always yield forward slashes."""
    return os.path.normpath(p).replace("\\", "/")


def _walk_c_files(path):
    """Path.wildcard(Path.join(dir, "**/*.c")) ordering: sorted, dirs first."""
    files = []
    for root, dirs, names in os.walk(path):
        dirs.sort()
        for name in sorted(names):
            if name.endswith(".c"):
                files.append(_normpath_forward(os.path.join(root, name)))
    return files


def main(argv):
    args = []
    opts = {}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a.startswith("--"):
            if "=" in a:
                k, v = a[2:].split("=", 1)
                opts[k] = v
            elif i + 1 < len(argv) and not argv[i + 1].startswith("--"):
                opts[a[2:]] = argv[i + 1]
                i += 1
            else:
                opts[a[2:]] = True
        else:
            args.append(a)
        i += 1

    if not args:
        print("Usage: python scripts/lpc_converter.py PATH [--zone ZONE] [--output DIR]")
        return 1

    path = args[0]
    zone_id = opts.get("zone")
    output_dir = opts.get("output", "data/world")
    recursive = opts.get("recursive", True)

    # Which zones are really installed.  A cross-zone exit into an LPC directory
    # that was never converted can only be recovered from the exit direction, and
    # that recovery must not fire while converting into a staging directory that
    # has no zones in it yet, so only trust it when the directory already has
    # something in it.
    note_installed_zones(output_dir)

    if os.path.isdir(path):
        files = _walk_c_files(path)
        print(f"Found {len(files)} LPC files in {path}")
        if zone_id is None:
            zone_id = _norm_id(os.path.basename(os.path.dirname(path)))
        entries = []
        failures = []
        for file in files:
            print(f"Converting {file}...")
            ucl, comments, err = convert_file(file, zone_id=zone_id, include_comments=True)
            if err is not None:
                print(f"Conversion failed: {err}")
                failures.append((file, err))
                continue
            ucl_name = _norm_id(_path_basename_rootname(file))
            entries.append((ucl_name, ucl, comments))

        seen = set()
        deduped = []
        for e in entries:
            if e[0] not in seen:
                seen.add(e[0])
                deduped.append(e)

        output_file = os.path.join(output_dir, f"{zone_id}.ucl")
        comments_file = os.path.join(output_dir, f"{zone_id}.comments.txt")
        os.makedirs(os.path.dirname(output_file), exist_ok=True)

        zone_header = f'zones "{zone_id}" {{\n  name = "{zone_id}"\n}}\n\n'
        body = "\n\n".join(u.rstrip() for _n, u, _c in deduped if u.strip() != "")
        if body == "":
            with open(output_file, "w", encoding="utf-8", newline="") as f:
                f.write(zone_header)
        else:
            with open(output_file, "w", encoding="utf-8", newline="") as f:
                f.write(zone_header + body + "\n")

        comments_body = "\n\n".join(c.rstrip() for _n, _u, c in deduped)
        with open(comments_file, "w", encoding="utf-8", newline="") as f:
            f.write(comments_body + "\n")

        print(f"Wrote {len(deduped)} objects to {output_file}")
        print(f"Wrote comments to {comments_file}")
        if failures:
            print(f"Failed on {len(failures)} files: {failures}")
        print("Done.")
        return 0 if not failures else 1
    else:
        if zone_id is None:
            zone_id = _norm_id(os.path.basename(os.path.dirname(path)))
        ucl, comments, err = convert_file(path, zone_id=zone_id, include_comments=True)
        if err is not None:
            print(f"Conversion failed: {err}")
            return 1
        output_file = os.path.join(output_dir, f"{zone_id}.ucl")
        comments_file = os.path.join(output_dir, f"{zone_id}.comments.txt")
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        ucl_name = _norm_id(_path_basename_rootname(path))
        if os.path.exists(output_file):
            existing = open(output_file, encoding="utf-8").read()
            if f"# Generated from {path} by LPCConverter" in existing or \
               f'rooms "{ucl_name}"' in existing or \
               f'characters "{ucl_name}"' in existing or \
               f'items "{ucl_name}"' in existing:
                print(f"{ucl_name} already exists in {output_file}, skipping append")
            else:
                with open(output_file, "w", encoding="utf-8", newline="") as f:
                    f.write(existing.rstrip() + "\n\n" + ucl.rstrip() + "\n")
                print(f"Appended to {output_file}")
        else:
            zone_header = f'zones "{zone_id}" {{\n  name = "{zone_id}"\n}}\n\n'
            with open(output_file, "w", encoding="utf-8", newline="") as f:
                f.write(zone_header + ucl.rstrip() + "\n")
            print(f"Created {output_file}")
        with open(comments_file, "w", encoding="utf-8", newline="") as f:
            f.write(comments + "\n")
        print(f"Wrote comments to {comments_file}")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
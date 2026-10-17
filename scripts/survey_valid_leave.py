#!/usr/bin/env python
"""P4 勘查：从 LPC `valid_leave` 提取可回填的阻挡条件候选。

背景
----
sidecar 记录 410 条 valid_leave「裸条件」（转换器 `_BRANCH_ACTION` 不认
`return notify_fail(...)` → sidecar 只有条件、没有动作）。`.ucl` 里现有
`valid_leave = [ ... ]` 条目来自转换器**当时抽到的**部分；本脚本回源拿
**真实的** if 嵌套结构与 notify_fail 文案，产出候选清单（不改数据）。

与转换器做法的差别（关键）
------------------------
转换器处理嵌套 if 只保留**最内层**条件，外层守卫丢失 → 已入库的 33 条
「未限定方向」被运行时跳过（见 `scripts/audit_exit_veto_locks.py`）。
本脚本把外层守卫**与内层条件合取**，产出方向明确的完整条件。

提取规则
--------
- 支持 `if (COND) return notify_fail("MSG\n");`、`if (COND) { ...; return
  notify_fail("MSG"); ... }`、嵌套 if（守卫逐层合取）。
- 支持**放行式外层守卫**取反：`if (dir != "east") return ::valid_leave(...);`
  → 后续语句隐含守卫 `dir == "east"`（仅限简单比较，其余不猜）。
- 跳过：条件含未知自定义函数（check_dirs/check_out/->refuse 等框架通道）、
  非字面量消息（拼接变量）、循环包裹、else 分支的 notify_fail。
- 消重：房间已有 condition+message 相同的条目不重复产出。

输出
----
tmp/p4_candidates.json：
  {candidates: [{zone, room, condition, message, direction, all_dirs,
                 exits_ok, source, lpc_line}],
   skipped: [{source, reason}], stats: {...}}
后续 `scripts/probe_valid_leave_candidates.exs`（容器内）用真实求值器门
（parse/enforceable/direction_scoped/supported）分类，
`scripts/backfill_exit_vetoes.py` 只写通过门的候选。

只读；不写 data/world。
"""
import argparse
import collections
import json
import os
import re
import sys

CORPUS = r"C:\files\git\mud"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WORLD = os.path.join(ROOT, "data", "world")
OUT = os.path.join(ROOT, "tmp", "p4_candidates.json")

# 排除区（同 audit_exit_veto_locks.py：测试靶场/夹具/手写区）
EXCLUDE_ZONES = {"test", "global", "liuxi", "kissa-jarvi", "lepakko-luola",
                 "sammatti", "signature", "clone_lib"}

# ---------- UCL 块遍历（同 B9/B10 口径） ----------
GEN = re.compile(r"^#\s*Generated from\s+(\S+)\s+by LPCConverter\s*$")
LPC = re.compile(r"^#\s*LPC:\s*(\S+)")
OPEN = re.compile(r'^(\s*)(rooms|room_exits|items|characters)\s+"([^"]+)"\s*\{\s*$')


def norm(path):
    return path.replace("\\", "/").lower()


def skeleton_delta(line):
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if not in_str and ch == "#":
            break
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_str = False
            out.append(" ")
        else:
            if ch == '"':
                in_str = True
                out.append(" ")
            else:
                out.append(ch)
        i += 1
    s = "".join(out)
    return s.count("{") - s.count("}")


def iter_blocks(lines):
    depth = 0
    pending = None
    header = None
    for i, line in enumerate(lines):
        m = GEN.match(line.strip())
        if m and depth == 0:
            header = norm(m.group(1))
        if depth == 0:
            om = OPEN.match(line)
            if om:
                pending = (om.group(2), om.group(3), header, i)
        nxt = depth + skeleton_delta(line)
        if pending is not None and depth != 0 and nxt == 0:
            kind, key, src, start = pending
            resolved = src
            for j in range(start + 1, i):
                lm = LPC.match(lines[j].strip())
                if lm and resolved in (None, header):
                    resolved = norm(lm.group(1))
            yield kind, key, resolved, start, i
            pending = None
        depth = nxt


# ---------- LPC 源码解析 ----------
FN_RE = re.compile(r'(?:int|varargs|void|mixed|nomask\s+int)\s+valid_leave\s*\(')

DIR_CMP_RE = re.compile(r"""\bdir\s*(==|!=)\s*(['"])([a-z]+)\2""")

# 已知安全调用/方法（LpcCondition 白名单，容器内核验兜底）
KNOWN_FUNCS = {"present", "environment", "objectp", "living", "userp",
               "wizardp", "this_object", "this_player", "id"}
KNOWN_METHODS = {"query", "query_temp", "query_skill", "query_condition",
                 "id", "permit_pass"}
# permit_pass 是放行式返回的条件里常见（本身不产 notify_fail），不判未知。

IDENT_CALL_RE = re.compile(r'\b([A-Za-z_][A-Za-z_0-9]*)\s*\(')
METHOD_RE = re.compile(r'->\s*([A-Za-z_][A-Za-z_0-9]*)\s*\(')


def find_function(text):
    """返回 (start, end) 覆盖整个函数定义；失败 None。"""
    m = FN_RE.search(text)
    if not m:
        return None
    # 找到函数体的第一个 {
    i = text.find("{", m.end())
    if i < 0:
        return None
    depth = 0
    j = i
    while j < len(text):
        c = text[j]
        if c == '"' or c == "'":
            q = c
            j += 1
            while j < len(text) and text[j] != q:
                if text[j] == "\\":
                    j += 1
                j += 1
        elif c == "/" and j + 1 < len(text) and text[j + 1] == "/":
            j = text.find("\n", j)
            if j < 0:
                break
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return m.start(), j + 1
        j += 1
    return None


def skip_string(s, i):
    """s[i] 是引号 → 返回引号串结束后的下标。"""
    q = s[i]
    j = i + 1
    while j < len(s):
        if s[j] == "\\":
            j += 2
            continue
        if s[j] == q:
            return j + 1
        j += 1
    return j


def find_matching(s, i, open_c, close_c):
    """s[i]==open_c → 配对 close_c 下标（跳过字符串/注释）。"""
    depth = 0
    j = i
    while j < len(s):
        c = s[j]
        if c in "\"'":
            j = skip_string(s, j)
            continue
        if c == "/" and j + 1 < len(s) and s[j + 1] == "/":
            k = s.find("\n", j)
            j = len(s) if k < 0 else k
            continue
        if c == "/" and j + 1 < len(s) and s[j + 1] == "*":
            k = s.find("*/", j)
            j = len(s) if k < 0 else k + 2
            continue
        if c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1


def read_statement(s, i):
    """从 i 读一条简单语句（到 ';' 或配对的 {}）。

    返回 (stmt, next_i, is_block, stmt_i)——stmt_i 是语句在 s 中的起始下标
    （跳过前导空白后），供调用方换算行号。

    注意 `if (c1) if (c2) { ... }` 嵌套形态：语句以 `if` 开头、第一个 `;`
    落在内层块**里面**，必须先找 `;` 之前的 `{`，按块配对读，否则会把
    块的收尾 `}` 切掉。
    """
    j = i
    while j < len(s) and s[j].isspace():
        j += 1
    if j < len(s) and s[j] == "{":
        k = find_matching(s, j, "{", "}")
        return s[j:k + 1], (k + 1 if k >= 0 else len(s)), True, j
    # 扫描到第一个 ; 或 {（跳过字符串/注释）
    k = j
    first_brace = -1
    while k < len(s):
        c = s[k]
        if c in "\"'":
            k = skip_string(s, k)
            continue
        if c == "/" and k + 1 < len(s) and s[k + 1] == "/":
            e = s.find("\n", k)
            k = len(s) if e < 0 else e
            continue
        if c == ";":
            break
        if c == "{":
            first_brace = k
            break
        k += 1
    if first_brace >= 0:
        kb = find_matching(s, first_brace, "{", "}")
        end = (kb + 1) if kb >= 0 else len(s)
        return s[j:end], end, True, j
    if k >= len(s):
        return s[j:], len(s), False, j
    return s[j:k], k + 1, False, j


# `return notify_fail(CYN "..." NOR);` —— LPC 颜色宏包裹的纯字符串。
# 只认「宏 + 单个字符串字面量 + 宏」形态；带 `+` 拼接 / 函数调用的动态
# 文案一律不匹配（无法静态落库，属 Trap）。
# 注意收尾宏后紧跟 `)` 没有空白（`"..." NOR)`），宏与空白之间用 \s*。
MACRO_TOKEN_RE = r'(?:[A-Z][A-Z0-9_]*\s*)*'
NOTIFY_RE = re.compile(
    r'^return\s+notify_fail\s*\(\s*' + MACRO_TOKEN_RE +
    r'"((?:\\.|[^"\\])*)"\s*' + MACRO_TOKEN_RE + r'\)\s*$')
PASSTHRU_RE = re.compile(
    r'^return\s+(?:::valid_leave\s*\([^)]*\)|1|0)?\s*$')


def is_simple_comparison(cond):
    """简单比较（可安全取反）：可选 ! + LHS ==/!= RHS，两侧为简单 token。"""
    c = cond.strip()
    neg = False
    while c.startswith("!"):
        neg = not neg
        c = c[1:].strip()
    m = re.match(r'^([A-Za-z_][\w.\'"]*)\s*(==|!=)\s*(.+)$', c)
    if not m:
        return None
    lhs, op, rhs = m.group(1), m.group(2), m.group(3).strip()
    # RHS 不能再是复杂表达式
    if any(ch in rhs for ch in "()|&<>+-*/") and not re.match(r'^-?\d+(\.\d+)?$', rhs):
        return None
    # 取反
    new_op = "!=" if op == "==" else "=="
    prefix = "!" if neg else ""
    return "%s%s %s %s" % (prefix, lhs, new_op, rhs)


def unknown_identifiers(cond):
    """条件里是否有白名单外的函数/方法调用（框架类判定）。"""
    bad = []
    for m in IDENT_CALL_RE.finditer(cond):
        name = m.group(1)
        # `->method(` 的 METHOD_RE 也会被 IDENT_CALL_RE 命中（`>` 是非单词字符），
        # 按 `->` 前缀跳过，交给下面的方法白名单校验
        if cond[:m.start()].rstrip().endswith("->"):
            continue
        # 跳过类型转换 (int)/(string) 与已知内置
        if name in ("int", "string", "if", "return", "sizeof"):
            continue
        if name not in KNOWN_FUNCS:
            bad.append(name + "()")
    for m in METHOD_RE.finditer(cond):
        name = m.group(1)
        if name not in KNOWN_METHODS:
            bad.append("->" + name + "()")
    return bad


# LpcCondition 求值器内置变量（eval/1 直接绑定的 5 个名字）。
# 其余裸标识符求值为 nil（ctx.vars 缺省）——LPC 里它们是真实值，
# 照抄会造成语义偏移（如 `skill < 30` 恒真），必须排除。
VAR_OK = {"me", "dir", "room", "this_object", "this_player"}
IDENT_TOKEN_RE = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')


def bare_unknown_vars(cond):
    """条件里出现白名单外的裸标识符（变量）→ 返回名单。

    允许：内置变量；`->` 方法名；方法目标（仅限内置变量）；
    同一表达式内 `x = ...` 赋值的 x（LpcCondition assign 会现场绑定）。
    """
    stripped = re.sub(r"'[^']*'", "''", cond)
    bad = []
    for m in IDENT_TOKEN_RE.finditer(stripped):
        name = m.group(0)
        if name in ("int", "string"):
            continue  # (int)/(string) 类型转换
        s, e = m.start(), m.end()
        nxt = stripped[e:e + 1]
        if nxt == "(":
            continue  # 函数名（unknown_identifiers 已单独校验）
        if stripped[:s].rstrip().endswith("->"):
            continue  # -> 方法名
        rest = stripped[e:].lstrip()
        if rest.startswith("->"):
            # 方法目标：仅允许内置变量（ob->refuse 这类上游变量拒绝）
            if name not in VAR_OK:
                bad.append(name)
            continue
        if rest.startswith("=") and not rest.startswith("=="):
            continue  # 同一表达式内赋值
        if name not in VAR_OK:
            bad.append(name)
    return bad


def normalize_condition(cond):
    """条件归一化（输出书写 + 既有条目去重共用）：

    - 压空白、双引号 → 单引号（对齐既有条目惯例）
    - `&&` / `||` 两侧补空格（吸收源码里 `&&ob` 这类粘写）
    - `! x` → `!x`（源码两种写法都有）
    - 结尾的 `&& x = present(...)` → `&& (x = present(...))`：LPC 惯用法，
      补上括号确保求值器按「与」运算解析而不是把赋值当最低优先级

    字符串字面量先用占位符保护，避免误伤引号内的 && / = / !。
    """
    c = " ".join(cond.split())
    c = c.replace('"', "'")
    strs = []

    def _stash(m):
        strs.append(m.group(0))
        return "\x00%d\x00" % (len(strs) - 1)

    c = re.sub(r"'[^']*'", _stash, c)
    c = re.sub(r'\s*&&\s*', ' && ', c)
    c = re.sub(r'\s*\|\|\s*', ' || ', c)
    c = re.sub(r'!\s+', '!', c)
    # LPC 惯例：裸 `present(id)` = 在 this_object（即本房）里找。
    # 求值器 present/2 收两个参数（单参会在 eval_args 解构时 MatchError），
    # 这里补成 `present(id,this_object())` —— 语义等价且求值器支持。
    # 注意逗号后**不能有空格**：elias 词法器不接受 `, x`（既有条目惯例
    # `present('shi wei',environment(me))`，实测见 probe_ucl_brackets.exs）。
    c = re.sub(r'present\((\x00\d+\x00)\)', r'present(\1,this_object())', c)
    # 仅处理「结尾处」的赋值项（corpus 惯用法）；中途赋值的形态不补括号，
    # 留给求值器判 parse 失败 → probe 阶段排除（宁缺毋滥）
    c = re.sub(r'(&&|\|\|)\s+([A-Za-z_]\w*)\s*=\s*(?![=])(.+\))$', r'\1 (\2 = \3)', c)
    c = re.sub(r'\x00(\d+)\x00', lambda m: strs[int(m.group(1))], c)
    return c


def walk_block(body, guards, stats, text, line_base):
    """顺序执行一个语句块，返回 [(guards, msg, lpc_line)]。

    顺序语义（对应 LPC 顺序执行）：
    - `if (c) <notify_fail>`        → guards + [c]
    - `if (c) { ... }`              → 递归，c 守卫整块
    - `if (c) return 1;`（放行式）  → NOT(c)（仅简单比较可取反）**累积**作用于
      块内后续语句；复杂条件取不了反 → 本块后续候选作废并计数
      （缺守卫会让 veto 比 LPC 更激进，可能锁死玩家，宁缺毋滥）
    - 无条件 `return notify_fail`   → guards（+ 已累积的取反）
    - 声明 / 副作用 return / for / while / switch → 跳过
    """
    out = []
    negs = []
    i = 0
    n = len(body)
    while i < n:
        c = body[i]
        if c.isspace():
            i += 1
            continue
        if c == "/" and i + 1 < n and body[i + 1] == "/":
            k = body.find("\n", i)
            i = n if k < 0 else k + 1
            continue
        if c == "/" and i + 1 < n and body[i + 1] == "*":
            k = body.find("*/", i)
            i = n if k < 0 else k + 2
            continue
        if body.startswith("if", i) and (i + 2 >= n or not (body[i + 2].isalnum() or body[i + 2] == "_")):
            op = body.find("(", i)
            if op < 0:
                i += 2
                continue
            cp = find_matching(body, op, "(", ")")
            if cp < 0:
                stats["parse_fail"] += 1
                break
            cond = body[op + 1:cp].strip()
            stmt, nxt, is_block, si = read_statement(body, cp + 1)
            line = text.count("\n", 0, line_base + si) + 1
            # ---- else 分支（执行条件 = NOT(cond)）----
            k = nxt
            while k < n and body[k].isspace():
                k += 1
            if body.startswith("else", k) and (k + 4 >= n or not (body[k + 4].isalnum() or body[k + 4] == "_")):
                k += 4
                while k < n and body[k].isspace():
                    k += 1
                estmt, enxt, eis_block, esi = read_statement(body, k)
                s_est = estmt.strip()
                neg = is_simple_comparison(cond)
                if NOTIFY_RE.match(s_est):
                    stats["else_notify_fail"] += 1
                    if neg is not None:
                        out.append((guards + negs + [neg],
                                    NOTIFY_RE.match(s_est).group(1), line))
                        stats["emitted"] += 1
                elif eis_block or s_est.startswith("if"):
                    # else 块 / else if：整体执行条件是 NOT(cond)，
                    # 取不了反就不能要（否则少守卫 → 过拦）
                    if neg is None:
                        stats["skip_else_complex"] += 1
                    elif eis_block:
                        out.extend(walk_block(estmt[1:-1], guards + negs + [neg],
                                              stats, text, line_base + esi + 1))
                    else:
                        op2 = s_est.find("(")
                        cp2 = find_matching(s_est, op2, "(", ")")
                        if 0 <= op2 < cp2:
                            inner_cond = s_est[op2 + 1:cp2].strip()
                            estmt2, _e2, eis2, esi2 = read_statement(s_est, cp2 + 1)
                            cands, neg3, poisoned3 = handle_if(
                                inner_cond, estmt2, eis2, guards + negs + [neg],
                                stats, text, line_base + esi + esi2, line)
                            out.extend(cands)
                            if neg3 is not None:
                                negs.append(neg3)
                            if poisoned3:
                                break
                        else:
                            stats["parse_fail"] += 1
                nxt = enxt
            # ---- if 本体 ----
            cands, neg2, poisoned = handle_if(cond, stmt, is_block,
                                              guards + negs, stats, text,
                                              line_base + si, line)
            out.extend(cands)
            if neg2 is not None:
                negs.append(neg2)
            if poisoned:
                stats["poisoned_block"] += 1
                break
            i = nxt
            continue
        if body.startswith("return", i) and (i + 6 >= n or not (body[i + 6].isalnum() or body[i + 6] == "_")):
            stmt, nxt, _rb, si = read_statement(body, i)
            s = stmt.strip()
            if NOTIFY_RE.match(s):
                out.append((guards + negs, NOTIFY_RE.match(s).group(1),
                            text.count("\n", 0, line_base + si) + 1))
                stats["emitted"] += 1
            i = nxt
            continue
        if body.startswith(("for", "while"), i):
            stats["skip_loop"] += 1
            op = body.find("(", i)
            stmt, nxt, _rb, _si = read_statement(body, op if 0 <= op < i + 20 else i)
            i = nxt
            continue
        # 其它语句（变量声明、表达式语句、switch…）：跳到 ; 或配对 {} 后
        stmt, nxt, _rb, _si = read_statement(body, i)
        i = nxt
    return out


def handle_if(cond, stmt, is_block, guards, stats, text, abs_si, line):
    """处理 if 语句本体。返回 (candidates, neg_or_None, poisoned)。

    neg：放行式 `if (c) return 1;` 的取反条件（简单比较才可取反），
    由调用方累积到块内后续语句；poisoned：条件复杂取不了反，块内后续作废。
    """
    s = stmt.strip()
    if NOTIFY_RE.match(s):
        mm = NOTIFY_RE.match(s)
        stats["emitted"] += 1
        return ([(guards + [cond], mm.group(1), line)], None, False)
    if s.startswith("if"):
        # 嵌套单语句 if：`if (c1) if (c2) ...`。必须**先于** is_block 判断——
        # read_statement 对 `if (c2) { ... }` 返回的 stmt 以 `if` 开头而非 `{`。
        op = s.find("(")
        cp = find_matching(s, op, "(", ")")
        if 0 <= op < cp:
            inner_cond = s[op + 1:cp].strip()
            estmt, _enxt, eis_block, esi2 = read_statement(s, cp + 1)
            return handle_if(inner_cond, estmt, eis_block, guards + [cond],
                             stats, text, abs_si + esi2, line)
        return ([], None, True)
    if is_block:
        return (walk_block(stmt[1:-1], guards + [cond], stats, text, abs_si + 1),
                None, False)
    if PASSTHRU_RE.match(s):
        neg = is_simple_comparison(cond)
        if neg is not None:
            return ([], neg, False)
        return ([], None, True)
    # permit_pass / delete_temp / 其它带副作用的 return → 不产候选
    stats["skip_non_notify"] += 1
    return ([], None, False)


def extract_candidates(path, text):
    """返回 (candidates, stats)：candidates = [(guards_list, message, lpc_line)]"""
    stats = collections.Counter()
    span = find_function(text)
    if not span:
        stats["no_fn"] += 1
        return [], stats
    fn = text[span[0]:span[1]]
    b0 = fn.find("{")
    if b0 < 0:
        stats["no_body"] += 1
        return [], stats
    body = fn[b0 + 1:-1]
    return walk_block(body, [], stats, text, span[0] + b0 + 1), stats


# ---------- 消息/条件清洗 ----------
def process_lpc_escapes(s):
    return (s.replace("\\n", "\n").replace("\\t", "\t").replace("\\r", "\r")
             .replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\"))


def sanitize_msg(s):
    s = s.replace('\\"', "'").replace('"', "'")
    s = s.replace(";", " ")
    s = s.replace("\n", " ").replace("\r", " ")
    s = s.replace("[", "(").replace("]", ")")
    return s.strip()


def elias_hostile(text):
    """返回 elias 无法词法化的原因列表（probe_ucl_brackets.exs 实测边界）。"""
    bad = []
    if "[" in text or "]" in text:
        bad.append("brackets")
    if re.search(r",\s+[A-Za-z]", text):
        bad.append("comma-space-letter")
    if re.search(r"\d,", text):
        bad.append("digit-comma")
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="debug: stop after N files")
    args = ap.parse_args()

    # ---- 1. LPC 侧：源文件 → candidates ----
    src_cands = {}
    skip_log = []
    stats = collections.Counter()
    for root, _dirs, files in os.walk(CORPUS):
        for fn in sorted(files):
            if not fn.endswith(".c"):
                continue
            path = os.path.join(root, fn)
            rel = os.path.relpath(path, CORPUS).replace("\\", "/")
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    text = fh.read()
            except OSError:
                continue
            if "valid_leave" not in text:
                continue
            stats["files_with_vl"] += 1
            cands, fst = extract_candidates(path, text)
            stats.update({("fn_" + k): v for k, v in fst.items()})
            if not cands:
                continue
            src_cands[norm(path)] = {"rel": rel, "cands": cands}
            if args.limit and len(src_cands) >= args.limit:
                break

    # ---- 2. UCL 侧：源 → room 块、既有条目、出口 ----
    src_to_rooms = collections.defaultdict(list)   # src -> [(zone, room_key, exits, valid_leave_text)]
    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith(".ucl"):
            continue
        zone = fn[:-4]
        if zone in EXCLUDE_ZONES:
            continue
        with open(os.path.join(WORLD, fn), encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        blocks = list(iter_blocks(lines))
        room_exits = {}
        for kind, key, src, start, close in blocks:
            if kind == "room_exits":
                dirs = []
                for ln in lines[start + 1:close]:
                    m = re.match(r'^\s*([a-z_]+)\s*=\s*rooms?\.', ln)
                    if m:
                        dirs.append(m.group(1))
                room_exits[key] = set(dirs)
        for kind, key, src, start, close in blocks:
            if kind != "rooms":
                continue
            body = "\n".join(lines[start + 1:close])
            # 既有 valid_leave 条目
            vl = []
            for m in re.finditer(r'valid_leave\s*=\s*\[(.*?)\n\s*\]', body, re.S):
                for e in re.finditer(r'\{(.*?)\}', m.group(1), re.S):
                    cm = re.search(r'condition\s*=\s*"(.*?)"', e.group(1), re.S)
                    mg = re.search(r'message\s*=\s*"(.*?)"', e.group(1), re.S)
                    dm = re.search(r'direction\s*=\s*(?:"([^"]*)"|(~))(?:\n|$)',
                                   e.group(1))
                    ncond = normalize_condition(cm.group(1)) if cm else ""
                    nmsg = " ".join((mg.group(1) if mg else "").split())
                    ndir = normalize_condition(
                        dm.group(1) if dm.group(1) is not None else dm.group(2)
                    ) if dm else ""
                    # 方向也要一致才算「已存在」：转换器有时把 `dir=='a'||dir=='b'`
                    # 的条件截成单个方向（chengdu/wuguan 只留 up），
                    # 同为 cond+msg 但方向更宽的候选是**真缺口**，必须放行
                    vl.append((ncond, nmsg, ndir))
            if src is not None:
                src_to_rooms[src].append((zone, key, room_exits.get(key, set()), vl))

    # ---- 3. 生成候选 ----
    candidates = []
    for src, info in sorted(src_cands.items()):
        rooms = src_to_rooms.get(src, [])
        for guards, raw_msg, lpc_line in info["cands"]:
            msg = sanitize_msg(process_lpc_escapes(raw_msg))
            if not msg:
                stats["skip_empty_msg"] += 1
                continue
            hostile = elias_hostile(msg)
            # 守卫连接：**多条**守卫相遇时，含 || 的那条整体加括号，
            # 避免 && 拼接后优先级漂移（LPC 里 && 紧于 ||）。
            # 单守卫时保持原文形态 —— 转换器产出的既有条目就是原文，
            # 加括号会让去重键失配（chengdu/wuguan 踩过）。
            parts_g = []
            for g in guards:
                g = g.strip()
                if not g:
                    continue
                parts_g.append(g)
            if len(parts_g) > 1:
                parts_g = ["(" + g + ")" if "||" in g else g for g in parts_g]
            cond = normalize_condition(" && ".join(parts_g))
            if not cond:
                stats["skip_empty_cond"] += 1
                skip_log.append({"source": info["rel"], "reason": "empty-cond"})
                continue
            bad = unknown_identifiers(cond)
            if bad:
                stats["skip_unknown_func"] += 1
                skip_log.append({"source": info["rel"], "reason": "unknown:" + ",".join(bad[:3]),
                                 "condition": cond[:100]})
                continue
            bare = bare_unknown_vars(cond)
            if bare:
                stats["skip_bare_var"] += 1
                skip_log.append({"source": info["rel"], "reason": "bare-var:" + ",".join(bare[:3]),
                                 "condition": cond[:100]})
                continue
            hostile_c = elias_hostile(cond)
            if hostile_c:
                stats["skip_hostile_cond"] += 1
                skip_log.append({"source": info["rel"], "reason": "cond-elias:" + ",".join(hostile_c),
                                 "condition": cond[:100]})
                continue
            if hostile:
                stats["skip_hostile_msg"] += 1
                skip_log.append({"source": info["rel"], "reason": "msg-elias:" + ",".join(hostile),
                                 "condition": cond[:100], "message": msg[:60]})
                continue
            # 方向推导：`dir == 'x'` 单值 → 该方向；
            # `!=` / 多值 / 混用 → "~"（条件自身限定方向，direction_scoped?
            # 只查 "dir" 字面量，`dir != 'east'` 同样含 "dir"，可正常执行）
            dirs_found = DIR_CMP_RE.findall(cond)
            if dirs_found:
                eq_vals = {d[2] for d in dirs_found if d[0] == "=="}
                has_ne = any(d[0] == "!=" for d in dirs_found)
                if eq_vals and not has_ne and len(eq_vals) == 1:
                    direction = eq_vals.pop()
                else:
                    direction = "~"
                # 多方向时 direction = ~（前置过滤放行，由条件自身判定）
                all_dirs = False
            else:
                direction = "~"
                all_dirs = True
            if not rooms:
                stats["skip_no_room"] += 1
                skip_log.append({"source": info["rel"], "reason": "no-room",
                                 "condition": cond[:100]})
                continue
            if len(rooms) > 1:
                stats["skip_ambiguous_room"] += 1
                skip_log.append({"source": info["rel"], "reason": "ambiguous-room",
                                 "rooms": [r[1] for r in rooms]})
                continue
            zone, room_key, exits, vl = rooms[0]
            exists = (direction in exits) if direction != "~" else bool(exits)
            # 方向感知去重：同 cond + 同 msg + 同方向才算已存在
            already = (cond, msg, direction) in set(vl)
            candidates.append({
                "zone": zone, "room": room_key,
                "condition": cond, "message": msg,
                "direction": direction, "all_dirs": all_dirs,
                "direction_exists": exists,
                "source": info["rel"], "lpc_line": lpc_line,
                "already_present": already,
            })

    n_already = sum(1 for c in candidates if c["already_present"])
    stats["candidates_total"] = len(candidates)
    stats["candidates_new"] = len(candidates) - n_already
    stats["candidates_already"] = n_already
    stats["candidates_new_dir_ok"] = sum(
        1 for c in candidates if not c["already_present"] and c["direction_exists"])
    # 按区统计
    by_zone = collections.Counter(c["zone"] for c in candidates if not c["already_present"])
    stats["zones"] = len(by_zone)

    out = {
        "candidates": candidates,
        "skipped": skip_log,
        "stats": dict(stats),
        "by_zone": dict(by_zone),
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)

    print("files with valid_leave : %d" % stats["files_with_vl"])
    print("notify_fail emitted    : %d" % stats.get("fn_emitted", 0))
    print("candidates total       : %d (new %d / already %d)"
          % (stats["candidates_total"], stats["candidates_new"], stats["candidates_already"]))
    print("new with dir exists    : %d" % stats["candidates_new_dir_ok"])
    print("zones touched          : %d" % stats["zones"])
    print("skip reasons           : %s" % {
        k.replace("skip_", ""): v for k, v in stats.items() if k.startswith("skip_")})
    print("by zone                : %s" % dict(by_zone.most_common(12)))
    print("wrote %s" % OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())

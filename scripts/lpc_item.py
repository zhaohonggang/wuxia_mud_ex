"""LPC item .c -> 字段提取（P0b 新方法，不复用已归档的转换器）

从 create() 里抽：name / long / weight / value / unit / material /
damage+skill_type / food / armor / book(skill)，并按既有 UCL 约定推导 verbs。

约定与已转换产物一致（对照 lib/kantele/world/lpc_converter.ex 的
generate_item_ucl/build_item_meta/infer_verbs，另补它漏掉的
set_weight / init_* / base_* / food_supply）：

  meta = { damage, skill_type, armor, value, weight, unit, material, food, book }
  book = { skill, min_skill, max_skill, exp_required, jing_cost, difficulty }
"""
import re

# ANSI 颜色宏：转换时要剥掉（HIC/CYN/... 在 Elixir 端由 Tags 处理）
ANSI = (r'HIC|HIG|BBL|BRED|BGRN|BYEL|BBLU|BMAG|BWHT|BLK|RED|GRN|YEL|BLU|MAG|WHT|CYN|CGRN|'
        r'CYEL|CBLU|CMAG|HGRN|HYEL|HBLU|HMAG|HWHT|BLK|WHT|NOR')

COMMENT_RE = re.compile(r'//[^\n]*|/\*.*?\*/', re.S)


def strip_comments(src):
    # 字符串里的 // 不能当注释：先保护字符串
    parts = re.split(r'("(?:[^"\\]|\\.)*")', src)
    out = []
    for i, p in enumerate(parts):
        out.append(p if i % 2 == 1 else COMMENT_RE.sub(' ', p))
    return ''.join(out)


def clean_text(s):
    """去掉 ANSI 宏与 $ 占位符，折叠空白"""
    s = re.sub(r'\$([A-Za-z@][A-Za-z0-9_]*)', '', s)
    s = re.sub(r'\b(%s)\b' % ANSI, '', s)
    s = s.replace('\\n', '\n')
    s = re.sub(r'[ \t]+', ' ', s)
    s = re.sub(r'\n{2,}', '\n', s)
    return s.strip()


def find_arrays(src):
    """收集文件级 `string* names = ({ "a", "b" });`，供 set_name(names[i], ..) 取名"""
    arrs = {}
    for m in re.finditer(r'\bstring\s*\*\s*([A-Za-z_]\w*)\s*=\s*\(\s*\{(.*?)\}\s*\)\s*;',
                         src, re.S):
        lits = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2))
        if lits:
            arrs[m.group(1)] = [clean_text(x) for x in lits]
    return arrs


def find_vars(src):
    """收集 `string name = <expr>;` 之类的局部/文件级变量，供 set_name(name, ..) 解析"""
    vs = {}
    for m in re.finditer(r'\b(?:string|mixed|int|object)\s+([A-Za-z_]\w*)\s*=\s*([^;]+);', src):
        vs[m.group(1)] = m.group(2)
    return vs


def expand(expr, vs, depth=3):
    """把表达式里的标识符替换成其定义（支持几层嵌套）"""
    out = expr
    for _ in range(depth):
        new = re.sub(r'\b([A-Za-z_]\w*)\b',
                     lambda m: '(' + vs[m.group(1)] + ')' if m.group(1) in vs else m.group(0),
                     out)
        if new == out:
            break
        out = new
    return out


def literal_strings(expr, vs=None):
    """取表达式里相邻字面量的拼接结果（去掉宏），可先展开变量"""
    if vs:
        expr = expand(expr, vs)
    lits = re.findall(r'"((?:[^"\\]|\\.)*)"', expr)
    if not lits:
        return None
    return clean_text(''.join(lits))


def strip_macros_expr(expr):
    """去掉裸宏拼接（NOR + CYN "柴胡" NOR），保留字面量"""
    return re.sub(r'\b(%s)\b' % ANSI, '', expr)


def find_create_body(src):
    m = re.search(r'\bvoid\s+create\s*\(\s*\)\s*\{', src)
    if not m:
        return None
    i = m.end() - 1
    depth = 0
    for j in range(i, len(src)):
        if src[j] == '{':
            depth += 1
        elif src[j] == '}':
            depth -= 1
            if depth == 0:
                return src[i + 1:j]
    return None


def inherits(src):
    return re.findall(r'^\s*inherit\s+([A-Za-z_][\w/]*)', src, re.M)


def extract(path):
    raw = open(path, encoding='utf-8', errors='replace').read()
    src = strip_comments(raw)
    body = find_create_body(src)
    if body is None:
        return {'_error': 'no create()'}

    inh = inherits(src)
    vs = find_vars(src)
    arrs = find_arrays(src)
    d = {'_inherits': inh}

    # set_name(<name expr>, ({aliases}))
    m = re.search(r'\bset_name\s*\((.*?)\)\s*;', body, re.S)
    if m:
        args = m.group(1)
        # 第一个逗号前是名字，其后是别名表
        head = args.split(',')[0]
        # set_name(titles[random(sizeof(titles))], ..) / set_name(names[i], ..)
        # 原 LPC 每次 clone 随机取一个；静态物品只能取确定性首项
        am = re.match(r'\s*([A-Za-z_]\w*)\s*\[', head)
        if am and am.group(1) in arrs:
            d['name'] = arrs[am.group(1)][0]
            d['_name_variants'] = arrs[am.group(1)]
        else:
            d['name'] = literal_strings(strip_macros_expr(head), vs)

    # set("long", ...) —— 可能跨多行拼接 / 引用局部变量
    m = re.search(r'set\s*\(\s*"long"\s*,(.*?)\)\s*;', body, re.S)
    if m:
        d['long'] = literal_strings(strip_macros_expr(m.group(1)), vs)

    # 数值/字符串字段
    def num(key, *keys2):
        for k in (key,) + keys2:
            mm = re.search(r'set\s*\(\s*"%s"\s*,\s*(-?\d+)\s*\)' % k, body)
            if mm:
                return int(mm.group(1))
        return None

    def numfn(fn):
        mm = re.search(r'\b%s\s*\(\s*(-?\d+)\s*\)' % fn, body)
        return int(mm.group(1)) if mm else None

    d['weight'] = numfn('set_weight') or num('base_weight', 'weight')
    d['value'] = num('value', 'base_value')
    # 护甲写在 armor_prop/armor（ARMOR inherit 的常见写法）
    d['armor'] = num('armor') or num('armor_prop/armor')
    d['armor_type'] = None
    mm = re.search(r'set\s*\(\s*"armor_prop/type"\s*,\s*"([A-Za-z_]\w*)"', body)
    if mm:
        d['armor_type'] = mm.group(1)
    d['food'] = num('food_supply', 'food')

    for k in ('unit', 'material'):
        mm = re.search(r'set\s*\(\s*"(?:base_)?%s"\s*,\s*("(?:[^"\\]|\\.)*")' % k, body)
        if mm:
            d[k] = literal_strings(mm.group(1))

    # init_<weaponclass>(N) -> damage
    for cls in ('sword', 'blade', 'dao', 'staff', 'gun', 'whip', 'bian', 'dagger',
                'throwing', 'hammer', 'mace', 'axe', 'spear', 'halberd', 'stick',
                'longsword', 'shortsword', 'club', 'fork', 'needle'):
        v = numfn('init_' + cls)
        if v is not None:
            d['damage'] = v
            d['_skill_from_init'] = cls
            break

    # skill_type：优先 init_ 推出的，其次 inherit 推断
    if '_skill_from_init' in d:
        d['skill_type'] = d.pop('_skill_from_init')
    else:
        d['skill_type'] = infer_skill_type(inh)

    # set("skill", ([ "name": ..., "exp_required": ..., "sen_cost": ...,
    #                 "difficulty": ..., "max_skill": ... ]))
    m = re.search(r'set\s*\(\s*"skill"\s*,\s*\(?\s*\[(.*?)\]\s*\)?\s*\)', body, re.S)
    if m:
        sk = m.group(1)
        bk = {}
        for key, out in (('name', 'skill'), ('exp_required', 'exp_required'),
                         ('sen_cost', 'jing_cost'), ('jing_cost', 'jing_cost'),
                         ('difficulty', 'difficulty'), ('max_skill', 'max_skill'),
                         ('min_skill', 'min_skill')):
            mm = re.search(r'"%s"\s*:\s*"?(?:([A-Za-z_]\w*)|(-?\d+))"?' % key, sk)
            if mm:
                bk[out] = mm.group(1) or int(mm.group(2))
        if bk:
            d['book'] = bk

    return d


SKILL_MAP = [
    ('SWORD', 'sword'), ('BLADE', 'blade'), ('DAO', 'blade'), ('STAFF', 'staff'),
    ('GUN', 'staff'), ('WHIP', 'whip'), ('BIAN', 'whip'), ('DAGGER', 'dagger'),
    ('THROWING', 'throwing'), ('HAMMER', 'hammer'), ('MACE', 'mace'), ('AXE', 'axe'),
    ('SPEAR', 'spear'), ('HALBERD', 'halberd'), ('CLUB', 'club'), ('FORK', 'fork'),
    ('NEEDLE', 'needle'), ('LONGSWORD', 'sword'), ('SHORTSWORD', 'sword'),
    ('STAFF', 'staff'),
]


def infer_skill_type(inh):
    for token, st in SKILL_MAP:
        if any(token in x.upper() for x in inh):
            return st
    return None


def infer_verbs(inh, d):
    base = ['get', 'drop']
    up = ' '.join(x.upper() for x in inh)
    if any(k in up for k in ('WEAPON', 'SWORD', 'BLADE', 'DAGGER', 'STAFF', 'WHIP',
                             'HAMMER', 'MACE', 'CLUB', 'SPEAR')):
        return base + ['wield', 'unwield']
    if 'ARMOR' in up:
        return base + ['wear', 'remove']
    if 'FOOD' in up or 'EDIBLE' in up or d.get('food'):
        return base + ['eat']
    return base


def is_item_like(d, src):
    """源文件确实是物品吗（排除同名房间/NPC）"""
    if '_error' in d:
        return False, d['_error']
    if not d.get('name'):
        return False, 'no set_name'
    inh = ' '.join(d.get('_inherits', []))
    if re.search(r'^\s*inherit\s+ROOM', src, re.M):
        return False, 'inherit ROOM'
    if 'ITEM' in inh or d.get('weight') is not None or d.get('value') is not None:
        return True, ''
    return False, 'no ITEM inherit / weight / value'


if __name__ == '__main__':
    import sys, json
    for p in sys.argv[1:]:
        r = extract(p)
        r['verbs'] = infer_verbs(r.get('_inherits', []), r)
        r.pop('_inherits', None)
        print('=== %s' % p.replace('C:\\files\\git\\mud', ''))
        print(json.dumps(r, ensure_ascii=False, indent=1))
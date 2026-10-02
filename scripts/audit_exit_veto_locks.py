"""锁房审计：列出所有「不限定方向」的 valid_leave 阻挡条件。

为什么需要这个脚本
------------------
LPC 的 `valid_leave` 常写成嵌套 if，**外层守卫（方向、present 判断）在内层条件之前**：

    # mud/d/beijing/kediandayuan.c
    if (dir != "east") return ::valid_leave(me, dir);      # 外层：只管 east
    room = find_object(query("exits/east"));
    if (room && present("la ma", room) && present("dubi shenni", room)) {
        if ((int)me->query_skill("force") < 100)           # 内层：转换器只留了这个
            return notify_fail("……");

转换器处理嵌套 if 时只保留了最内层条件，外层守卫丢失，于是 UCL 里剩下
`(int)me->query_skill('force') < 100` —— 它对**所有方向**成立。若照此执行，
技能不足的玩家会被锁在该房的每一个出口上。

现状：`Kantele.World.LpcCondition.direction_scoped?/1` 让这类条件**一律不执行**
（方向明确的 112 条照常生效）。本脚本就是补齐外层守卫的工作清单：
逐条回原 .c 读出真实的 `dir` / `present` 守卫，补进 UCL 的 condition，
然后把对应的 `direction_scoped?` 例外去掉。

用法：python scripts/audit_exit_veto_locks.py
"""
import os, re, io, sys, collections

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

WORLD = r'C:\files\git\wuxia_mud_ex\data\world'
EX = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti',
      'signature', 'clone_lib'}

COND = re.compile(r'^\s*condition\s*=\s*"(.*)"\s*$')
ROOM = re.compile(r'^\s*rooms\s+"([^"]+)"\s*\{')
EXITS = re.compile(r'^\s*room_exits\s+"([^"]+)"\s*\{')
DIRLINE = re.compile(r'^\s*([a-z_]+)\s*=\s*rooms?\.')
CHAR = re.compile(r'^\s*characters\s+"([^"]+)"\s*\{')

# 收集：zone -> {room -> [conditions]}
rooms_conds = collections.defaultdict(lambda: collections.defaultdict(list))
# zone -> {room -> [exit dirs]}
room_dirs = collections.defaultdict(lambda: collections.defaultdict(list))

for fn in sorted(os.listdir(WORLD)):
    if not fn.endswith('.ucl') or fn[:-4] in EX:
        continue
    z = fn[:-4]
    lines = open(os.path.join(WORLD, fn), encoding='utf-8').read().split('\n')
    cur_room = None
    for i, l in enumerate(lines):
        m = ROOM.match(l)
        if m:
            cur_room = m.group(1)
        m = EXITS.match(l)
        if m:
            key = m.group(1)
            j = i + 1
            while j < len(lines) and lines[j].strip() != '}':
                d = DIRLINE.match(lines[j])
                if d:
                    room_dirs[z][key].append(d.group(1))
                j += 1
        m = COND.match(l)
        if m and cur_room:
            rooms_conds[z][cur_room].append((i + 1, m.group(1)))

total = sum(len(v) for c in rooms_conds.values() for v in c.values())
print('带条件的房间数: %d，条件数: %d'
      % (sum(len(v) for v in rooms_conds.values()), total))

no_dir = []
for z, rm in sorted(rooms_conds.items()):
    for room, conds in sorted(rm.items()):
        dirs = set(room_dirs[z].get(room, []))
        for ln, c in conds:
            if 'dir' not in c:
                no_dir.append((z, room, ln, c, sorted(dirs)))

print('\n=== 不限定方向的条件（命中即锁死该房所有出口）: %d 条 ===' % len(no_dir))
for z, room, ln, c, dirs in no_dir:
    print('  %-10s %-16s line %-6d 方向=%s' % (z, room, ln, dirs))
    print('       %s' % c[:110])

# 只剩 message（无条件无 condition）的条目统计：这些不拦，仅提示
print('\n=== 提示：direction="*" 且带 condition 的（对所有方向生效）===')
star = [(z, r, ln, c) for z, rm in rooms_conds.items() for r, cs in rm.items()
        for ln, c in cs if 'dir' not in c]
print('  共 %d 条（见上）' % len(star))
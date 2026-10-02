"""P2 第一步：把 `valid_leave` 块里的阻挡条件从注释搬进 `condition` 字段

原形态（转换器写的）：

    valid_leave = [
    {
       # 阻挡条件（原样保留）：dir == "north" && objectp(present("shi wei", environment(me)))
    direction = "north"
      message = "..."
    }

改成（loader 的 parse_room_vetoes 本来就读 `condition`，只是数据里一直缺）：

    valid_leave = [
    {
      condition = "dir == 'north' && objectp(present('shi wei',environment(me)))"
    direction = "north"
      message = "..."
    }

三处必要的格式处理（都是语义中性的，因为 Elias 的词法器很挑）：

1. 内层字符串字面量的双引号换成单引号。Elias 处理嵌套 `\"` 会提前截断字符串
   （实测 `objectp(present(\\"mang she\\", ...))` 直接语法错误）。
   求值器 `Kantele.World.LpcCondition` 单双引号都收。
2. 去掉 `,` 后与 `)` 前的空格。Elias 在字符串里遇到「逗号后带空格」同样截断
   （实测 `present('x', environment(me))` 失败、`present('x',environment(me))` 通过）。
3. 下面两类条件**保持原注释不动**（原文一字不删，等词法器/求值器补齐再迁）：
   - 含下标 `inv[i]` / `myfam["family_name"]`：求值器不支持，且 `[` 会让 Elias 出错
   - 逗号后紧跟数字 `query_skill('dodge',1)`：Elias 遇到「,数字」会提前截断
     （实测 `f('x',1)` 语法错误、`f('x',env)` 正常）

能否真正执行由 `Kantele.World.LpcCondition.enforceable?/1` 判定；运行时求值
失败一律放行（宁可少拦，不能把玩家锁死在房里）。

用法：python scripts/migrate_exit_vetoes.py [--apply]
"""
import os
import re
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, 'data', 'world')
EXCLUDED = {'test', 'global', 'liuxi', 'kissa-jarvi', 'lepakko-luola', 'sammatti',
            'signature', 'clone_lib'}

COND = re.compile(r'^(\s*)#\s*阻挡条件（原样保留）：\s*(.+?)\s*$')
UNMIGRATABLE = re.compile(r'\[|,\s*\d')


def esc(s):
    """条件文本 -> 能安全放进 UCL 字符串的形式（语义中性）"""
    s = s.replace('"', "'")
    s = re.sub(r'\s*,\s*', ',', s)
    s = re.sub(r'\s+\)', ')', s)
    return s.replace('\\', '\\\\')


def write_with_retry(path, content, zone, attempts=5):
    """写盘带重试：Windows bind mount 偶发 OSError 22，中断会留下半完成状态"""
    for i in range(attempts):
        try:
            with open(path, 'w', encoding='utf-8', newline='') as fh:
                fh.write(content)
            return True
        except OSError as e:
            if i == attempts - 1:
                print('  [FAIL] %s 写入失败：%s' % (zone, e))
                return False
            time.sleep(0.3)
    return False


def main():
    apply_ = '--apply' in sys.argv
    total = 0
    skipped = 0
    failed = 0
    changed = []

    for fn in sorted(os.listdir(WORLD)):
        if not fn.endswith('.ucl'):
            continue
        z = fn[:-4]
        if z in EXCLUDED:
            continue

        path = os.path.join(WORLD, fn)
        raw = open(path, encoding='utf-8', newline='').read()
        out = []
        n = 0

        for line in raw.split('\n'):
            m = COND.match(line)

            if not m:
                out.append(line)
                continue

            expr = m.group(2)

            if UNMIGRATABLE.search(expr):
                out.append(line)
                skipped += 1
                continue

            out.append('%scondition = "%s"' % (m.group(1), esc(expr)))
            n += 1

        if n:
            total += n
            changed.append((z, n))
            if apply_ and not write_with_retry(path, '\n'.join(out), z):
                failed += 1

    for z, n in changed:
        print('[%s] %-12s %d 条' % ('apply' if apply_ else 'dry', z, n))

    print('\n合计迁移 %d 条（%d 个区）；保留原注释 %d 条；写入失败 %d 个区'
          % (total, len(changed), skipped, failed))

    if not apply_:
        print('(dry-run，未写入；加 --apply 生效)')


if __name__ == '__main__':
    main()
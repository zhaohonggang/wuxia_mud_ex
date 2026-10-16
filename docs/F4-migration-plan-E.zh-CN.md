# F4 招式迁移 · Plan E（60 个文件，交给独立 session）

> **本文件是给「另一个 session」的完整交接说明。** 请先通读全文再动手。
> 清单数据源：`scripts/f4-plan-E-rel.json`（60 条 rel，机器可读，供 `--json` 批量验收）。
> 本清单与 Plan D（`docs/F4-migration-plan-D.zh-CN.md`）**互不重叠**：Plan E 拿走 60 个，
> Plan D 保留其余 57 个（A 级 10 + B 级 47）。

## 0. 你的任务（一句话）

把下面清单里每个 `performs/<skill>/<move>.ex` 的**代码部分（不含注释）**，
改到与对应 LPC 源 `C:/files/git/mud/kungfu/skill/<lpc-rel>.c` 的**代码部分（不含注释）**
中的中文文案**逐条字面一致**，直到严格验收工具报 **PASS**。

## 1. 仓库与权威源

| 项 | 路径 |
|----|------|
| Elixir 仓库（你改这里） | `C:\files\git\wuxia_mud_ex`（分支 `kalevala`） |
| LPC 权威源（只读，**唯一裁判**） | `C:\files\git\mud\kungfu\skill\<skill-dashed>\<move>.c` |
| 目标文件 | `lib/kantele/combat/skills/performs/<skill_underscore>/<move>.ex` |
| 验收工具（**禁止修改**） | `scripts/perf_acceptance.py` |
| 保护登记表 | `scripts/protected_performs.txt` |

- `<skill-dashed>` 是 LPC 目录名（连字符），`<skill_underscore>` 是 Elixir 目录名（下划线）。
  映射由 `perf_acceptance.build_c_map()` 自动完成（`skill-foo/bar.c` → `skill_foo/bar.ex`）。
- 每个 `.ex` 文件**末尾必须保留** `# ===== 原始 LPC 源码 =====` 注释块，且与 `.c` **逐字节对齐**（禁止删改）。

## 2. 验收方式（硬性判据）

```bash
cd C:/files/git/wuxia_mud_ex
# 单文件
python scripts/perf_acceptance.py <skill>/<move>.ex
# 批量（本计划全部 60 个）
python scripts/perf_acceptance.py --json scripts/f4-plan-E-rel.json
```

- 工具打印 `PASS` 或 `FAIL`，并列出每条：
  - `- MISSING:` = `.c` 有、`.ex` 缺的中文文案 → **必须为 0**；
  - `+ EXTRA:`  = `.ex` 多出来的文案 → 仅提示，**不判失败**（但尽量收敛，尤其是泄漏的默认值）。
- **判据严格、不模糊（2026-10-12 决策，不可协商）**：不做「语义等价 / 同义改写」的宽松判定。
  `.c` 里怎么写，`.ex` 就怎么写。`难以施展`≠`无法施展`、`修为不够`≠`不够娴熟`、`真气不够`≠`真气不足`。
  工具内部用 **multiset（Counter）比对**：`.c` 中同一句文案出现 N 次，`.ex` 侧就必须有 **N 份独立字面量**。
- **绝对不要修改 `scripts/perf_acceptance.py`** 来「放水」；也不要改 `.c`。

## 3. 每文件标准流程（务必按序）

1. **读 `.c`**：`C:/files/git/mud/kungfu/skill/<skill-dashed>/<move>.c`（含 `#define` 宏，宏体要内联展开）。
2. **读 `.ex`**：目标文件当前内容（多数是抽取器生成的 stub，含 `差异(TODO)` 注释）。
3. **重写 `.ex` 代码**：逐条对齐门槛 / 起手 / 命中 / 落空 / 后续分支文案；补缺失分支。
4. **验收**：`python scripts/perf_acceptance.py <skill>/<move>.ex` → 必须 `PASS`（MISSING=0）。
5. **格式化（CI 门禁）**：容器内 `mix format <file>`，并 `mix format --check-formatted <file>` 确认通过。
6. **隔离编译**：容器内 `elixir tmp/f4/cc.exs <file>` → 期望 `COMPILE_OK` + `BEAM_OK <file>`（见第 5 节）。
7. **登记保护**：确认该 rel 已在 `scripts/protected_performs.txt`；不在则追加（否则抽取器重跑会覆盖你的手工修改）。
8. **提交**：`git -c core.autocrlf=false -c core.safecrlf=false commit -F <msg> -- <显式路径>`（见第 7 节）。

## 4. 容器与命令约定（Windows / Git Bash）

```bash
# 所有容器命令都要 MSYS_NO_PATHCONV=1，否则 Git Bash 会把 /app 改写成 Windows 路径
MSYS_NO_PATHCONV=1 docker exec wuxia_mud_dev-app-1 sh -c 'cd /app && <命令>'
```

- 容器名：`wuxia_mud_dev-app-1`，仓库在容器内挂载为 `/app`。
- 格式化：`MSYS_NO_PATHCONV=1 docker exec wuxia_mud_dev-app-1 sh -c 'cd /app && mix format <file> && mix format --check-formatted <file>'`
- **CI 有格式门禁**：`.github/workflows/main.yml:48` 跑 `mix format --check-formatted`。
  凡你手写/改动的 `.ex`，**提交前必须 `mix format`**，否则 CI 红。

## 5. 隔离编译（`tmp/f4/cc.exs`）

全量 `mix compile` 会被**别的文件**的错误阻塞（且容器 `_build` 未编译 kantele app），
所以用隔离编译工具（已存在，gitignored）：

```bash
MSYS_NO_PATHCONV=1 docker exec wuxia_mud_dev-app-1 sh -c   'cd /app && elixir tmp/f4/cc.exs lib/kantele/combat/skills/performs/<skill>/<move>.ex'
```

- 输出 `COMPILE_OK (closure=N)`，再逐个目标打印 `BEAM_OK <file>` 或 `BEAM_MISSING <file>`。
- 有语法/未定义错误会打印 `COMPILE_ERRORS` 并标出 `<<< TARGET`。
- 若该文件不存在（你新起 session），需先自建 `tmp/f4/cc.exs`：编译「目标文件 + 编译期依赖闭包」
  （`import` / `%Struct{}` 触发的 `module X is not loaded`），并从 `_build/dev/lib/*/ebin` 取 `Kalevala.*` 等依赖模块的 beam。
  这一步只是**语法/引用自检**，真正的逻辑正确性靠 `.c` 逐字对齐 + 后续游戏内测试（本计划不做游戏内测试）。

## 6. 换行符 / CRLF 铁律

- 仓库 blob **必须是纯 LF**。Windows Python 的 `Path.write_text()` 会把 `\n` 写成 `\r\n`。
  用 Python 改仓库文件后必须归一化：
  ```python
  p.write_bytes(p.read_bytes().replace(b"\r\n", b"\n"))
  ```
- 自查 CRLF **必须用 Python**（Git Bash 里 `grep -c $'\r'` 有假阳性）：
  ```bash
  git cat-file blob HEAD:<file> | python -c "import sys;print(sys.stdin.buffer.read().count(b'\r\n'))"
  ```
  期望 `0`。
- 用编辑器工具（Read/Edit/Write）改文件不会引入 CRLF；只有 Windows Python 写文件才需归一化。

## 7. 提交约定（并发 session 共享 git index，务必小心）

```bash
git -c core.autocrlf=false -c core.safecrlf=false commit -F /tmp/msg.txt -- <显式路径1> <显式路径2>
```

- **绝不**用 `git add -A` / `git commit`（无路径）。另有并发 session 在改同一个仓库，
  无路径提交会把**对方暂存进 index 的改动一起吞掉**。
- 提交前 `git diff --cached --name-only` 看一眼暂存区；只提交你自己的文件。
- 按**顶层目录**批次提交（一个目录一个 commit，message 用中文说明改了哪些 move）。
- 推送不可用（HTTPS 无凭据），**只需本地 commit**。

## 8. 验收规律速查（血泪教训，务必遵守）

**通用**
1. `@name <> "字面量"` **不会**被还原 → 门槛文案必须写成 `"#{@name}只能对战斗中的对手使用。\n"`。
2. 局部变量插值 `"A#{wp}B"` 会被还原成**单段**，与 `.c` 的 `"A"+wp+"B"` 两段不匹配
   → 必须写 `"A" <> wp <> "B"`（两侧非纯字面量，`<>` 不合并）。
3. 纯字面量多段：`.c` 里出现 `+` 才拆段，E 侧用 `Enum.join([...], "")`（逗号分隔，正则不合并）；
   仅空白/颜色宏分隔 → 一个 `"..."`。
4. `.c` 原始笔误是**内容**：双逗号「，，」、`!。` 连写、错别字、多余句号（如「丝毫不受腿影的干扰，。」）必须逐字复刻。
5. 前导词（`只见`/`只听`/`结果`）必须保留；半角 `!` vs 全角 `！` 逐字对齐。
6. `$N`/`$P`=攻击方，`$n`/`$p`=目标；`$n/$N/$p/$P` 在验收工具的 `norm()` 里会被抹掉，不必特殊处理。
7. 中文弯引号 `` “ ” ‘ ’ `` 与全角标点 `！。，` 是**内容**，按 `.c` 原样保留。
8. `perf_acceptance.ex_code_chinese` 会**剥除所有 `@attr "..."` 模块属性声明**，
   故裸招名（LPC `name()`）不能靠 `@name_bare "X"` 提供，必须在代码里以字符串字面量出现（如 `_ = "X"`）。

**门槛 / 分支**
9. 门槛按 `.c` 逐条对齐：`can_perform` → 目标 `living` → 武器/空手 → 各技能/内力 → 目标存活。
   `.c` 无 `can_perform` 时**保留** `Stats.perform_known?/2` 守卫（会多 1 条信息性 EXTRA，可接受）。
10. `resolve_incoming` 目标侧 `cond` 三态：`dead` → 广播「对方都已经这样了，用不着这么费力吧？」；
    `busy` → 广播「$n目前正自顾不暇，放胆攻击吧(。|！)」；`true` → 正常。
11. `Stats.prepared_perform/2` 返回**绝招 ID**（如 `"jiuyang-shengong/hun"`）或 `nil`；
    LPC `query_skill_prepared("unarmed")!="xxx"` 须写成
    `prepared == nil or hd(String.split(prepared, "/")) != "xxx"`（错写会恒真、门槛拦死）。
12. 多技能 OR 准备门槛：各自取 `prepared_perform` 前缀比对，`not ok_a and not ok_b` 才拦截。
13. 性别分档双文案：按 `meta[:gender] == "女性"` 取档（引擎无 gender，缺省非女性档），两档文案 + `女性` 字面量都要保留。

**消耗 / 伤害 / 效果映射（LPC → Elixir）**
14. `me->add("neili",-N)` + 忙乱 → `Performs.feedback(attacker, N, busy)`（在**目标侧**调用，作用于攻击方）。
15. `receive_damage("qi",d)` + `receive_wound("qi",w)` → `Vitals.damage(v, :qi, d) |> Vitals.wound(:qi, w)`。
16. `do_damage(..., percent, ...)` 的第 5 参是外伤比例 → `Vitals.wound(:qi, div(damage*percent, 100))`；
    第 4 参是 attack_type 不是伤害加成。
17. `target->start_busy(n)` → `Combat.start_busy(target.combat, n)`。
18. `query("character")` → `Map.get(character.meta, :character)`；`max_neili` → `character.meta.vitals.max_neili`。
19. `tell_object(target, ...)` → `render(conn, CommandView, "text", text: ...)`；
    `tell_object(me, ...)` → `Broadcast.publish(conn, ..., bindings)`。
20. `eff_status_msg(p)` → `Messages.eff_status_msg(div(vitals.qi * 100, max(vitals.max_qi, 1)))`。
21. 目标即死：先广播，再 `vitals = %{v | qi: 0}` + `combat = %{c | dead: true}`。
22. 延时减益（`call_out`）：`Combat.Buff{key:, applies:}` + `Combat.apply_temp(%{...})` +
    `Process.send_after(self(), %Event{topic: "combat/buff-expire", ...}, seconds * 1000)` +
    `schedule_expire/2` + `expire_message/0`。先例：`mantian_xing/xing.ex`、`bingpo_shenzhen/bing.ex`。
23. 攻击方持有的武器名要在**事件 data 里下发**（目标侧不知道攻击方武器）；
    取默认值不要写 `"某物"`（`.c` 无此串 → 会变成 EXTRA 泄漏），用 `""`。
24. 命中判定：攻击方算 `ap` 下发，目标侧算 `dp`（parry/dodge/force + con*10）再
    `div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp`（按 `.c` 的随机式为准）。

## 9. 完成定义（DoD）

- 本清单 **60 个文件全部 `PASS`（MISSING=0）**；
- 每个都过 `mix format --check-formatted` + 隔离编译 `BEAM_OK`；
- 全部已在 `scripts/protected_performs.txt` 登记；
- 按顶层目录批次**本地提交**（显式路径）。

## 10. 清单（60 个 / 57 个顶层目录 / 基线 miss 合计 603）

> 格式：`- [ ] ❌ <rel> ← <lpc-rel>.c (miss=N)`
> 完成后把 `[ ] ❌` 改成 `[x] ✅`。

### `chanhun_suo/` （2 个，基线缺失 23 条）

- [x] ✅ `chanhun_suo/duo.ex` ← `chanhun-suo/duo.c`  (miss=0)
- [x] ✅ `chanhun_suo/suo.ex` ← `chanhun-suo/suo.c`  (miss=0)

### `chuangwang_dao/` （1 个，基线缺失 11 条）

- [x] ✅ `chuangwang_dao/xiong.ex` ← `chuangwang-dao/xiong.c`  (miss=0)

### `chuanxin_zhang/` （1 个，基线缺失 8 条）

- [x] ✅ `chuanxin_zhang/zhui.ex` ← `chuanxin-zhang/zhui.c`  (miss=0)

### `chuanyue_jian/` （1 个，基线缺失 11 条）

- [x] ✅ `chuanyue_jian/hao.ex` ← `chuanyue-jian/hao.c`  (miss=0)

### `dacheng_fosuo/` （1 个，基线缺失 9 条）

- [x] ✅ `dacheng_fosuo/chanrao.ex` ← `dacheng-fosuo/chanrao.c`  (miss=0)

### `dagou_bang/` （2 个，基线缺失 24 条）

- [x] ✅ `dagou_bang/ban.ex` ← `dagou-bang/ban.c`  (miss=0)
- [x] ✅ `dagou_bang/chuo.ex` ← `dagou-bang/chuo.c`  (miss=0)

### `dali_chu/` （1 个，基线缺失 12 条）

- [x] ✅ `dali_chu/hong.ex` ← `dali-chu/hong.c`  (miss=0)

### `damo_jian/` （1 个，基线缺失 8 条）

- [x] ✅ `damo_jian/sanjue.ex` ← `damo-jian/sanjue.c`  (miss=0)

### `danding_dao/` （1 个，基线缺失 10 条）

- [x] ✅ `danding_dao/kou.ex` ← `danding-dao/kou.c`  (miss=0)

### `dongyang_dao/` （1 个，基线缺失 9 条）

- [x] ✅ `dongyang_dao/zhan.ex` ← `dongyang-dao/zhan.c`  (miss=0)

### `duanjia_sword/` （1 个，基线缺失 9 条）

- [ ] ❌ `duanjia_sword/jing.ex` ← `duanjia-sword/jing.c`  (miss=9)

### `duanyun_fu/` （1 个，基线缺失 7 条）

- [ ] ❌ `duanyun_fu/tiaoyan.ex` ← `duanyun-fu/tiaoyan.c`  (miss=7)

### `dugu_jiujian/` （2 个，基线缺失 22 条）

- [ ] ❌ `dugu_jiujian/qi.ex` ← `dugu-jiujian/qi.c`  (miss=12)
- [ ] ❌ `dugu_jiujian/yi.ex` ← `dugu-jiujian/yi.c`  (miss=10)

### `duoluoye_zhi/` （1 个，基线缺失 14 条）

- [ ] ❌ `duoluoye_zhi/jimie.ex` ← `duoluoye-zhi/jimie.c`  (miss=14)

### `duoming_jinhua/` （1 个，基线缺失 11 条）

- [ ] ❌ `duoming_jinhua/hua.ex` ← `duoming-jinhua/hua.c`  (miss=11)

### `emei_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `emei_jian/xian.ex` ← `emei-jian/xian.c`  (miss=10)

### `feifeng_whip/` （1 个，基线缺失 9 条）

- [ ] ❌ `feifeng_whip/wu.ex` ← `feifeng-whip/wu.c`  (miss=9)

### `feilong_zhang/` （1 个，基线缺失 11 条）

- [ ] ❌ `feilong_zhang/fei.ex` ← `feilong-zhang/fei.c`  (miss=11)

### `feixing_shu/` （1 个，基线缺失 12 条）

- [ ] ❌ `feixing_shu/hua.ex` ← `feixing-shu/hua.c`  (miss=12)

### `fenglei_zifa/` （1 个，基线缺失 7 条）

- [ ] ❌ `fenglei_zifa/she.ex` ← `fenglei-zifa/she.c`  (miss=7)

### `fireice_strike/` （1 个，基线缺失 14 条）

- [ ] ❌ `fireice_strike/binghuo.ex` ← `fireice-strike/binghuo.c`  (miss=14)

### `fumo_jian/` （1 个，基线缺失 11 条）

- [ ] ❌ `fumo_jian/foxin.ex` ← `fumo-jian/foxin.c`  (miss=11)

### `fumo_zhang/` （1 个，基线缺失 7 条）

- [ ] ❌ `fumo_zhang/lun.ex` ← `fumo-zhang/lun.c`  (miss=7)

### `furong_jian/` （1 个，基线缺失 9 条）

- [ ] ❌ `furong_jian/luan.ex` ← `furong-jian/luan.c`  (miss=9)

### `guxing_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `guxing_jian/lian.ex` ← `guxing-jian/lian.c`  (miss=10)

### `guyue_chan/` （1 个，基线缺失 9 条）

- [ ] ❌ `guyue_chan/jing.ex` ← `guyue-chan/jing.c`  (miss=9)

### `hanmei_jian/` （1 个，基线缺失 11 条）

- [ ] ❌ `hanmei_jian/leng.ex` ← `hanmei-jian/leng.c`  (miss=11)

### `hansha_sheying/` （1 个，基线缺失 11 条）

- [ ] ❌ `hansha_sheying/zhen.ex` ← `hansha-sheying/zhen.c`  (miss=11)

### `hanwang_qingdao/` （1 个，基线缺失 11 条）

- [ ] ❌ `hanwang_qingdao/ying.ex` ← `hanwang-qingdao/ying.c`  (miss=11)

### `hanxing_bada/` （1 个，基线缺失 7 条）

- [ ] ❌ `hanxing_bada/lastrisk.ex` ← `hanxing-bada/lastrisk.c`  (miss=7)

### `heixue_shenzhen/` （1 个，基线缺失 12 条）

- [ ] ❌ `heixue_shenzhen/luo.ex` ← `heixue-shenzhen/luo.c`  (miss=12)

### `henshan_jian/` （1 个，基线缺失 13 条）

- [ ] ❌ `henshan_jian/huan.ex` ← `henshan-jian/huan.c`  (miss=13)

### `hexing_bifa/` （1 个，基线缺失 9 条）

- [ ] ❌ `hexing_bifa/dian.ex` ← `hexing-bifa/dian.c`  (miss=9)

### `hongye_daofa/` （1 个，基线缺失 7 条）

- [ ] ❌ `hongye_daofa/leiting.ex` ← `hongye-daofa/leiting.c`  (miss=7)

### `houquan/` （1 个，基线缺失 8 条）

- [ ] ❌ `houquan/zhen.ex` ← `houquan/zhen.c`  (miss=8)

### `huilong_bifa/` （1 个，基线缺失 8 条）

- [ ] ❌ `huilong_bifa/cang.ex` ← `huilong-bifa/cang.c`  (miss=8)

### `hujia_daofa/` （1 个，基线缺失 7 条）

- [ ] ❌ `hujia_daofa/xian.ex` ← `hujia-daofa/xian.c`  (miss=7)

### `jidian_jian/` （1 个，基线缺失 6 条）

- [ ] ❌ `jidian_jian/dian.ex` ← `jidian-jian/dian.c`  (miss=6)

### `jinbiao_jue/` （1 个，基线缺失 10 条）

- [ ] ❌ `jinbiao_jue/huan.ex` ← `jinbiao-jue/huan.c`  (miss=10)

### `jingang_quan/` （1 个，基线缺失 12 条）

- [ ] ❌ `jingang_quan/jingang.ex` ← `jingang-quan/jingang.c`  (miss=12)

### `jinguan_yusuo/` （1 个，基线缺失 9 条）

- [ ] ❌ `jinguan_yusuo/suo.ex` ← `jinguan-yusuo/suo.c`  (miss=9)

### `jingyue_bifa/` （1 个，基线缺失 12 条）

- [ ] ❌ `jingyue_bifa/ci.ex` ← `jingyue-bifa/ci.c`  (miss=12)

### `jinshe_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `jinshe_jian/wan.ex` ← `jinshe-jian/wan.c`  (miss=10)

### `jinshe_zhui/` （1 个，基线缺失 11 条）

- [ ] ❌ `jinshe_zhui/tuwu.ex` ← `jinshe-zhui/tuwu.c`  (miss=11)

### `jiuqu_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `jiuqu_jian/wan.ex` ← `jiuqu-jian/wan.c`  (miss=10)

### `jueqing_jian/` （1 个，基线缺失 12 条）

- [ ] ❌ `jueqing_jian/liu.ex` ← `jueqing-jian/liu.c`  (miss=12)

### `kuangfeng_jian/` （1 个，基线缺失 9 条）

- [ ] ❌ `kuangfeng_jian/sao.ex` ← `kuangfeng-jian/sao.c`  (miss=9)

### `kuimang_dao/` （1 个，基线缺失 11 条）

- [ ] ❌ `kuimang_dao/pan.ex` ← `kuimang-dao/pan.c`  (miss=11)

### `kunlun_qifa/` （1 个，基线缺失 11 条）

- [ ] ❌ `kunlun_qifa/liu.ex` ← `kunlun-qifa/liu.c`  (miss=11)

### `lingshe_zhangfa/` （1 个，基线缺失 9 条）

- [ ] ❌ `lingshe_zhangfa/chan.ex` ← `lingshe-zhangfa/chan.c`  (miss=9)

### `liuhe_dao/` （1 个，基线缺失 11 条）

- [ ] ❌ `liuhe_dao/shan.ex` ← `liuhe-dao/shan.c`  (miss=11)

### `longcheng_shendao/` （1 个，基线缺失 11 条）

- [ ] ❌ `longcheng_shendao/feng.ex` ← `longcheng-shendao/feng.c`  (miss=11)

### `longxing_jian/` （1 个，基线缺失 10 条）

- [ ] ❌ `longxing_jian/kong.ex` ← `longxing-jian/kong.c`  (miss=10)

### `luohan_gun/` （1 个，基线缺失 7 条）

- [ ] ❌ `luohan_gun/xiangmo.ex` ← `luohan-gun/xiangmo.c`  (miss=7)

### `luohan_quan/` （1 个，基线缺失 8 条）

- [ ] ❌ `luohan_quan/xiangmo.ex` ← `luohan-quan/xiangmo.c`  (miss=8)

### `luoying_shenjian/` （1 个，基线缺失 12 条）

- [ ] ❌ `luoying_shenjian/sui.ex` ← `luoying-shenjian/sui.c`  (miss=12)

### `luoyun_dao/` （1 个，基线缺失 11 条）

- [ ] ❌ `luoyun_dao/tian.ex` ← `luoyun-dao/tian.c`  (miss=11)

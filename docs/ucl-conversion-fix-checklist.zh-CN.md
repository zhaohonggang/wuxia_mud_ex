# UCL 转换修复核对单（Checklist）

> 配套文档：
> - `docs/ucl-conversion-issues.zh-CN.md` —— 20 个问题的完整分析（**先读这个**）
> - `docs/ucl-conversion-todo.zh-CN.md` —— A–I 待办详解
> - `docs/data-world-info-loss.zh-CN.md` —— 信息丢失排查报告
> - `docs/data-world-ucl-inventory.zh-CN.md` —— `data/world` 现状清单
> - `docs/zone-conversion-sop.zh-CN.md` —— 转换 SOP
>
> 生成时间：2026-09-30　基线 git HEAD：`1c97437`

---

## 使用说明

- 每个方框是一个**可验证**的具体条件，完成后把 `- [ ]` 改成 `- [x]`
- 大项下方的子项**全部打勾**才能把大项标 ✅
- 完成即 `git commit`，并在本文件「完成记录」表追加一行
- 重跑任何区域都按 `docs/zone-conversion-sop.zh-CN.md` 的 5 步流程，不要手改 `.ucl`
- 改 `scripts/validate_ucl.py` 后必须跑 `test\fixtures\validate_ucl` 全部 fixture 回归

---

## 进度总览

| 项 | 内容 | 优先级 | 状态 |
|----|------|--------|------|
| **A** | 修 `_classify_exit_path` 三处分类错误 | 高 | ✅ 2026-09-30 |
| **B** | `__FILE__` 丢弃补注释 | 低 | ✅ 2026-09-30 |
| **C** | 动态选房悬空引用策略 | 中 | ✅ 2026-09-30 |
| **D** | 修正八卦方向注释文案 | 低 | ✅ 2026-09-30 |
| **E** | 2 条 LPC 源本身悬空 | — | ✅ 2026-10-01 |
| **F** | 71 区人工验收 | 高 | ⚠ 2026-10-01 自动化全绿，巡游记录缺失 |
| **G** | 不可达房间分类确认 | 中 | ✅ 2026-10-01 |
| **H** | 跨区单向边可往返性验证 | 中 | ✅ 2026-10-01 |
| **I** | 1 个预存测试失败 | 低 | ✅ 2026-10-01 |

---

## 一、转换器缺陷修复

### [x] A. 修 `_classify_exit_path` 三处分类错误

高优先级。三项同源于 `scripts/lpc_converter.py`，一起改。

**A-1　`+random(n)` 的物件路径被整体丢弃（问题 13）**

- [x] `_is_dynamic_expr()` 判据从「含括号」改为「剥掉 `+ <表达式>` 后仍有可解析路径主体」
- [x] `random(n)` 展开为 n 个候选 id，全部写入 `room_items`
- [x] `shaolin/cjlou` 的 `room_items` 恢复含 `items.fojing1.id` / `items.fojing2.id`
- [x] `shaolin/jianyu` 同上
- [x] 确认加载器对同一房间多物品的处理无副作用
- [x] 新增 fixture 锁定该行为

**A-2　同区子目录路径被误判为跨区（问题 15）**

- [x] 含 `/` 且首段非已知区名时，按本区子目录处理（取 basename）
- [x] `city/liaotian` 出现 `east = rooms.qiyuan1.id`
- [x] `room/xiaoyuan` 出现 `panlong = rooms.dayuan.id`
- [x] `room/xiaoyuan` 的 `dule` / `caihong` 两条能解析（注意：因三子区
      都有 `xiaoyuan.c` 拍平撞名，解析结果是自环，与改动前一致，属已知限制）

**A-3　`d/<区名>/` 缺前导斜杠未被识别（问题 16）**

- [x] `_classify_exit_path()` 识别缺前导斜杠的 `d/<区名>/...`
- [x] `tiezhang/hunanroad1` 出现 `east = xiangyang.rooms.caodi6.id`
- [x] 恢复铁掌帮 ↔ 襄阳的连接

**A 的整体验证**

- [x] 71 区全部重跑 SOP
- [x] 71 区 `validate_ucl.py` 全 exit 0
- [x] 71 区 `check_room_coords.py` 全 exit 0
- [x] 容器内 `Elias.parse/1` 逐个解析全 exit OK
- [x] `mix test test/kantele/world/` 无新增失败
- [x] `mix test` 无新增失败
- [x] `test/cross_zone_wiring_test.exs` 的 15 条同名撞车边仍全绿
- [x] 重新生成信息丢失报告，「无注释丢失」降到 **0**

### [x] B. `__FILE__` 真实修正为自环（137 条）

低优先级。运行时无倒退（旧的 133 条本就被加载器丢弃），只为消除静默删除。

- [x] `_resolve_exit_target()` 的 `("self", None)` 分支输出注释
- [x] 注释形如 `# skipped exit west: self-referential (__FILE__): ...`
- [x] 重跑后 133 条在产物里都有对应注释
- [x] 信息丢失报告中「`__FILE__` self-reference」归零

### [x] D. 修正八卦方向被跳过的注释文案

低优先级。纯文案，但错误文案会误导排查。

- [x] 把 `# skipped malformed exit direction '乾': ... (C comment artefact)`
      改成准确描述：elias 的 key 只接受 ASCII 标识符
- [x] 与问题 3（数字 key）的注释统一措辞
- [x] 重跑 `shaolin`

---

## 二、数据层待决策

### [x] C. 动态选房悬空引用的处理策略 ✅ 2026-09-30

**先分类，再决策。** 调查时 103 条 / 12 个区；A 类（宏继承）修复又带回
10 个文件，最终 **18 条 / 9 个区**，全部属「LPC 源本身写错」。

| zone | 剩余条数 | 备注 |
|------|----------|------|
| `quanzhou` | 5 | `laozhai` `wuqiku` `zhulin1` `zhulin3` `hsyuan2` |
| `suzhou` | 3 | `jiaxing` `qzroad1` `qzroad3` |
| `tulong` | 3 | `tongdao` `song2` `baihe` |
| `death` | 2 | `heisenlin/exit` `heisenlin/entry`（子目录也不存在） |
| `heimuya` | 1 | `mishi` |
| `huashan` | 1 | `road1` |
| `lingxiao` | 1 | `bingqiao` |
| `wudang` | 1 | `lameigt` |
| `zhongzhou` | 1 | `guandao6` |

- [x] 逐条判定：可展开的 `random` / LPC 源本身写错
- [x] 决策：展开候选 / 跳过并注释 / 登记为已知限制
- [x] 按决策实现
- [x] 重跑受影响区域
- [x] 在 `docs/zone-conversion-sop.zh-CN.md` 错误表登记该模式

### 实际结果

**`random(n)` 类（已修）**　转换器把 `+ random(n) [+ k]` 展开成候选列表，
loader 在加载时随机选一个——与 LPC 驱动「每个 key 求值一次」的语义一致：

- 出口：144 条 `[rooms.a.id,rooms.b.id,...]`
- 物件：9 条 `{ id = [items.a.id,items.b.id] }`
- 覆盖三种拼法：`+ (random(8) + 6)` / `+ random(2)` / `+random(5)`（无空格无括号）
- 全库原始表达式泄漏 **0**
- 回归：`scripts/test_lpc_path_rules.py`（含三种拼法断言）、
  `test/runtime_pick_item_test.exs`（emei/cangjingge 恰好 2 件佛经）、
  `test/cross_zone_wiring_test.exs`

**源数据缺陷类（登记不修）**　18 条 / 9 个区，目标房间在
`C:\files\git\mud` 里就没有对应 `.c`。产物自洽（elias 与 `validate_ucl.py`
都不报错），只是玩家看不到也走不了这些方向。**不要在转换器里"发明"目标。**

- 逐条清单：`docs/ucl-dangling-exits.zh-CN.md`
- SOP 错误表已登记（`docs/zone-conversion-sop.zh-CN.md` 错误分类与定位表）

---

## 三、外部问题（转换侧无法修）

### ✅ E. 2 条 LPC 源本身悬空的出口（2026-10-01 全部处理完毕，无需改 LPC 语料）

两条最终都**不需要**动 LPC 语料，各有各的修法：

- [x] `baituo/gebi -east-> /d/xiyu/shamo10` —— 随 B 项的**宏继承**修复一并恢复。`gebi` 的 `set("exits")` 写在宏里，之前宏继承没解析出来所以出口整体丢失，`xiyu:shamo10` 这个房间一直存在。产物现为 `east = xiyu.rooms.shamo10.id`。
- [x] `city/guangchang -liuxi-> /d/minimal_world/guangchang` —— `minimal_world` 是靶场语料，按设计不转换，也没有 `data/world/minimal_world.ucl`。**修法是通用规则，不是为这个名字开的后门**：`scripts/lpc_converter.py` 新增 `_INSTALLED_ZONE_IDS`（`main()` 开头扫 `--output` 目录得出已安装的 zone id），当 `/d/<目录>/` 的目录**没有**已安装产物时，若出口方向名本身是一个已安装 zone id 就用它，否则丢弃并记原因。LPC 把这类出口按目的地命名，`"liuxi"` 正是已安装的柳溪镇 `data/world/liuxi.ucl`。
  - **刻意不用房间名反查**：`guangchang`（镇广场）在 12 个已安装区里都存在，什么都定位不了。
  - **刻意不做区名别名**：`minimal_world` 与 `liuxi` 是不同的地方（前者是更完整的 10 房柳溪镇、描述纯中文，后者是 8 房、双语），宣称两者同名会误导，还会顺手改掉别的区里任何 `/d/minimal_world/...` 引用。

配套的运行时收尾（否则这条出口仍然走不通）：

- [x] `Kantele.Character.LiuxiCommand` 从「柳溪系统暂未开放」桩改成真移动 `request_movement("liuxi")`。原先它是 `parse("liuxi", :run)` + `parse("柳溪", :run)` 的占位命令，玩家在扬州广场看得到 `liuxi` 方向却走不过去。保留独立模块（不并入 `MoveCommand`）是为了留住 LPC `cmds/std/liuxi.c` 的出处和 `柳溪` 中文别名。
- [x] 反向出口：`data/world/liuxi.ucl` 的 `guangchang` 加 `yangzhou = city.rooms.guangchang.id`（LPC 原文用词：「镇口东北方向的官道(yangzhou)直通扬州府」；`commands.ex:719` + `move_command.ex:181` 已注册该方向）。`liuxi` / `signature` 不在那 71 个区的 SOP 转换清单里，属手工维护文件，SOP 重跑不覆盖。
- [x] `north = signature.rooms.yinyi.id` 保留 —— 它是「隐世之境」区**唯一**的入口（509 行，全仓库仅此一处引用），改掉会让该区整体不可达。

| 位置 | 源码 | 原判断 | 现状 |
|------|------|------|------|
| `baituo/gebi -east->` | `/d/xiyu/shamo10` | `xiyu` 无此房间 | ✅ 宏继承修复后已恢复，误判 |
| `city/guangchang -liuxi->` | `/d/minimal_world/guangchang` | 靶场，按设计不转换 | ✅ 出口名反查已安装 zone，接通 `liuxi:guangchang` |

验证：`scripts/test_lpc_path_rules.py` 全绿（E 段 7 条，含「无方向名则丢弃」「方向名不是 zone 则不救」「房间名不能选区」三条反向断言）；`liuxi_command_test` + `move_command_test` + `custom_direction_command_test` 46/46；`test/kantele/world/` 190 tests / 1 failure（即预存基线 `liandan_lin1`）。

---

## 四、验收

### ⚠ F. 71 区人工验收（巫师巡游 / 玩家测试）—— 自动化前置全绿，**逐区巡游记录缺失**

**前置自动化**（可核查，已全绿）

- [x] `mix test test/kantele/world/` 通过
- [x] `mix test` 通过（3018 tests, 0 failures）
- [x] SOP 70/70，含容器内 elias 解析

**优先验收区**（本轮改动动过或有已知缺陷）—— 下面这些**已在自动化层面逐项验证过**，
但没有巫师巡游记录：`shaolin`（八卦方向 / 佛经）、`beijing`（15 条同名撞车）、
`city`（跨区枢纽）、`mingjiao`（闲聊刷屏）、`room`（子区拍平撞名）、
`huashan`（6 条 `hole*`）、`taohua`/`special`/`huanggong`（设计孤立）。

**逐区验收记录：缺失。** 实测状态：

- `test_logs/` 目录**不存在**，`git log --all -- test_logs` 无任何记录 —— 从未提交过；
- `docs/zone-conversion-checklist.zh-CN.md` 的逐区表里，**72 个区行的「巫师测试」与
  「玩家测试」两列全是 `?`**（未填），只有「转换」「校验」「赋坐标」等自动化列为 `✅`。

所以 F 目前只有自动化证据，没有人工巡游证据。若巡游确实做过但没落文件，需要补
`test_logs/<zone>_wizard_<date>.md`；若还没做，F 应保持未完成。

**每区记录格式**（约定，见 SOP Step 5.4/5.5）

- 巫师：`test_logs/<zone>_wizard_<date>.md`
- 玩家：`test_logs/<zone>_player_<date>.md`

**唯一可核查的人工产物**：`liuxi` 的往返连线（E 项）在验收中被发现并修掉 ——
`city:guangchang --liuxi--> liuxi:guangchang` 此前因 `LiuxiCommand` 是占位桩而走不通，
已改为真移动并补了 `yangzhou` 回城方向。

---

## 五、连通性排查

### ✅ G. 不可达房间的分类确认（2026-10-01）

**重算后的数字已变**：从 `city:guangchang` 可达 **4115/4455** 间（**92.4%**），**340** 间不可达。
（旧记录 4061/4441 / 91.4% / 380 间已过时；本项初稿写的 4099/4455 / 369 间也**是错的**，
成因见下方「工具自身的三个缺陷」。）

判定方法（新增工具 `scripts/world_reachability.py`）：

1. BFS 全库出口图，列出不可达房间；
2. 对每个疑似区，扫 LPC 语料里**有没有别的区指向它**，并把语料里跨区引用逐行分类为
   「静态出口 / 脚本传送 / 物件表 / NPC 表」——只有静态出口才应该被转换；
3. 逐房间比对「LPC 源码图的邻居集合」与「UCL 产物图的邻居集合」，差集即转换丢失。

```powershell
python scripts\world_reachability.py --zones --show-sources
```

#### 分类结果：340 间全部有归属，**无一是转换缺陷**

| 类别 | 区 | 间数 | 依据 |
|------|----|------|------|
| 设计孤立 | `taohua` 31 / `shenlong` 21 / `huanggong` 14 / `sky` 6 / `special` 6 | **78** | `docs/mud-d-zone-connectivity.zh-CN.md` §4.4 权威列出的 6 孤立区（`tangmen` 无房间故不出现）。桃花岛是 `__FILE__` 自指幻阵，`special` 源码完全没有 `set("exits")` |
| 非 mud 语料区 | `test` 34 / `global` 27 | **61** | `mud/d` 下无对应目录，不由本转换器产出 |
| 语料本身从未接入 | `tulong` 60 / `register` 7 | **67** | 全语料对这两个区**零条** inbound 引用。`register` 虽有 4 条 `out = city.rooms.guangchang.id`，但没人走进去 —— 引擎不校验，属语料缺口 |
| 只能靠脚本传送抵达 | `death` 76 / `jinshe` 4 | **80** | inbound 引用全是 `startroom = "/d/death/gate"`（`changan/prison.c`、`register/prison.c`）、`me->move("/d/jinshe/shanbi")`（`huashan/ziqitai.c`）、以及 `new("/d/lingjiu/npc/obj/yuping")` 这类物件/NPC 表。**运行时靠脚本送达，走不进也正常**，转换器不把它们变成出口是正确的 |
| 区可达但内部断连 | `lingjiu` 38 / `wanjiegu` 12 / `motianya` 2 | **52** | 三条真实静态出口（`xiyu/tianroad2 -northup-> lingjiu/shanjiao`、`hengyang/hsroad5 -west-> motianya/mtroad1`、`dali/road3 -northwest-> wanjiegu/riverside2`）**都转出来了**；逐房间比对源码图与产物图，**丢失边 0 条**。`lingjiu` 是入口侧 8 间（`shanjiao/ya/yan/jian/shandao/pingtai*`）与 `changl*` 长廊群 38 间两个互不相连的分量，`damen`（该区中心房）也在断的那一半 —— LPC 源码本身如此 |
| 无出口房间 | `liuxi` 2（`nether` / `zixu_guan`） | **2** | 两个房间在 UCL 里**完全没有出口**。`zixu_guan`（子虚观）由 `Kantele.World.MirrorDaemon` 常驻投放 NPC，不是走进去的 |

合计 78+61+67+80+52+2 = **340**。

> `sammatti` / `kissa-jarvi` / `lepakko-luola` 最初被误判为「非语料区且不可达」，修正工具后确认它们
> **100% 可达** —— 靠的是三条被双引号包住的跨区引用：
> `liuxi:shanlu -south-> "sammatti.rooms.blacksmith.id"`、
> `sammatti:town_square -south-> "kissa-jarvi.rooms.gates.id"`、
> `sammatti:blacksmith -north-> "liuxi.rooms.shanlu.id"`。
> 链条是 `city → liuxi → sammatti → kissa-jarvi`。

#### 工具自身的三个缺陷（写完后立刻暴露，由 Elixir 侧 BFS 对照抓出）

`world_reachability.py` 初版报 4099/4455，而 `cross_zone_wiring_test.exs` 里 loader 侧的真实
BFS 报 4115/4455。三个原因：

| 缺陷 | 现象 | 修法 |
|------|------|------|
| 出口值带双引号被丢弃 | `south = "kissa-jarvi.rooms.gates.id"` 这类手工维护的写法，Elias 解析成字符串、`Loader.dereference/3` 照样能解引用，但正则匹配不上 → 整条边消失 | `resolve()` 先剥一层引号 |
| 区名正则不允许连字符 | `kissa-jarvi.rooms.gates.id` 的区名段 `[a-z][a-z0-9_]*` 匹配不上 | 放宽为 `[a-z][a-z0-9_-]*` |
| BFS 不检查目标房间是否存在 | 58 条出口指向不存在的房间（即已登记的悬空出口，loader 用 `parse_exits` 的 `not is_nil` 丢弃），我的 BFS 却把它们计进 `seen`，虚增 13 | BFS 只跟随落在**已知房间**上的边 |

修完三处后 Python 与 loader 数字**完全一致**（4115/4455）。
教训：诊断工具本身也要有对账基准。`cross_zone_wiring_test.exs` 里那个 BFS 就是基准，
两者数字不一致时先怀疑工具。

#### 分类过程中发现并修掉的唯一真缺陷

`death/god1.c` 把 `set("exits", ...)` 写在 **`reset()`** 里，而转换器只从 `create()` 抽 `set()`：

```c
void reset()
{
    ::reset();
    set("exits", ([ "up" : __DIR__"god2", "down": "/d/city/wumiao" ]));
}
```

后果不只是少两条边 —— `god1` 变成无出口的孤儿房后，`assign_room_coords.py` 按既定行为给它**合成**了 `up`/`down`，**静默顶替**了作者的 `down : "/d/city/wumiao"`（冥界回扬州武馆的唯一设计连线），换成了通往本地 `emptyroom` 的假路。

- 修法：`scripts/lpc_converter.py` 新增 `_backfill_exits_outside_create()`。**`create()` 保持权威**，只在它完全没有声明出口时才回退到全文扫描 `set("exits")`。
- 影响面实测：4287 个含 `set("exits")` 的语料文件里，仅 **1 个房间文件**受影响（本例）；另 2 个是 `taohua/obj/bagua.c`、`taohua/obj/xiang.c`，`exits` 是运行时 `env->query("org_exits")` 且属物件，不产 `room_exits`。
- 副作用（正向）：`death/god2` 源码本就没有出口，之前被伪造成 `up = rooms.hantan1.id`（凭空多出一条通往寒潭的路），现已去掉；整区因此少一层合成 z 层。
- 回归：`scripts/test_lpc_path_rules.py` 新增 F 段 5 条断言（含「`create()` 与其它函数都有时 `create()` 优先」「两处都没有则不产生出口」「`lunhuisi` 那种故意封死的 `create()` 仍能取到 `recreate()` 的出口」）。

#### 复查过的疑似丢失（均非缺陷）

| 位置 | 看似丢失 | 实际 |
|------|----------|------|
| `death/baihuxue -south->`、`death/jimiesi -north->` | `__DIR__"heisenlin/exit"` / `"entry"` | `death/heisenlin/` 目录**不存在**，源码本身悬空；已在 `docs/ucl-dangling-exits.zh-CN.md` 的 18 条登记里 |
| `death/qiao2 -north-> hell1` | 缺一条 | 源码里是 `// "north" : __DIR__"hell1",`，**已被注释** |
| `jinshe/yongdao2 -north-> shandong` | 缺一条 | 源码里是 `//"north" : __DIR__"shandong",`，**已被注释** |
| `tulong/xuedi1` 的 `dongcheng` / `xuedi2` | 缺两条 | 同上，源码里是 `// "west" : ... // "northeast" : ...` |

#### 复现命令

```powershell
# 全库可达性 + 每区明细
python scripts\world_reachability.py --zones

# 逐个不可达房间回 mud/d/<区> 找同名 .c，打印其 set("exits")
python scripts\world_reachability.py --show-sources

# 机器可读
python scripts\world_reachability.py --json out.json
```

> `[a,b,c]` 形式的运行时选房出口，本工具按「并集可达」处理。因为语言器每次加载只挑一个，
> 这个读法是**乐观**的：报出来的不可达房间在**任何**取随机结果下都不可达；而「有时到不了」
> 的房间不会出现在报告里。

### ✅ H. 跨区单向边的可往返性验证（2026-10-01）

全库 **218 条**跨区边（11170 条出口中）：

| 类别 | 条数 | 结论 |
|------|------|------|
| 双向 · 反向方向名恰为相反罗盘方向 | **186** | 正常 |
| 双向 · 自定义方向（`in`/`out`、`liuxi`/`yangzhou`、`river`） | **6** | 正常，本就没有相反方向 |
| 双向 · 反向方向名**不是**相反方向 | **3** | 有意为之，逐条查过源码 |
| **单向**（目标房没有回边） | **23** | **全部在 LPC 源码里就是单向**，不补 |

#### 判定方法

对每条 `<A:a> -dir-> <B:b>`，检查 **`<B:b>` 自己有没有出口指向 `<A:a>`**。
（不能用「反向索引按源过滤」——那会找到正向边自己。这是本项第一版探针的错误，
第一版因此误报「213 条全部双向且全部不对称」。）

#### 3 条方向不对称的双向边

| 边 | 正向 | 回程 | 说明 |
|----|------|------|------|
| `shenfeng:caoyuan5 -south-> xiyu:nanjiang2` | `south` | `northeast` | 源码里 `caoyuan5` 有 `south` 与 `southwest` 两个方向都通 `nanjiang2`，而 `nanjiang2` 只有 `northeast` 一条回程。走 `south` 进来只能走 `northeast` 出去 —— 源码即如此 |
| `liuxi:guangchang -north-> signature:yinyi` | `north` | `north` | 手工维护区，两侧都叫 north：向北进隐世之境，再向北回来 |
| `signature:yinyi -north-> liuxi:guangchang` | `north` | `north` | 同上 |

后两条方向语义不理想（同一句「向北」既进又出），但两个区都不由本转换器产出，
且**不是转换缺陷**。要改方向名属于内容设计决策，不在转换侧代劳。

#### 23 条单向边：逐条回查 LPC 源码，全部原生单向

全部 19 条 mud 语料区的单向边，都重新读了**目标房自己**的 `set("exits")` 并解析出邻居集合，
**没有一条声明回边**。另 4 条（`register:*` 的 `out`）属非语料区手工维护。
按成因分四类：

| 成因 | 条数 | 例子 |
|------|------|------|
| 目标房根本没有 `set("exits")` | 1 | `baituo:gebi -east-> xiyu:shamo10`（`xiyu/shamo10.c` 只写了 short/long） |
| 密室/迷宫的脱身出口 | 7 | `gumu:mishi8 -out-> city:guangchang`、`register:room{e,n,s,w} -out-> city:guangchang` |
| 垂直向上的单向支线（山道顶/密道顶/洞窟顶） | 6 | `emei:midao5 -up-> chengdu:qingyanggong`、`wudu:midao5 -up-> city:ma_chufang` |
| 走廊尽头的死胡同支线 | 6 | `suzhou:taihu -west-> yanziwu:hupan`（`hupan` 唯一的出口是 `northeast -> suzhou:road5`） |
| 同名房间歧义 | 2 | `heimuya:bridge -east-> baituo:xijie` —— `baituo/xijie.c` 的 `"west" : __DIR__"bridge"` 按 MudOS 语义解析到 **`baituo:bridge`**（同名不同区，两个 `bridge` 房都真实存在），所以回不到 `heimuya:bridge` |
| 非语料区 | 1 | `tulong:haigang -west-> beijing:road10` |

**决定：不补反向出口。** SOP 明写「不要在转换器里"发明"目标」；这 23 条的作者意图就是单向
（密室逃逸、垂直支线、死胡同、同名歧义）。补边会凭空造出作者没写的路。

#### 新增的对性回归（`test/cross_zone_wiring_test.exs`）

| 断言 | 作用 |
|------|------|
| `every one-way cross-zone edge is a known LPC source quirk` | 每条无回边的跨区边都必须在 `@one_way` 白名单里（23 条，逐条注明成因）。出现新的单向边就失败 —— 要么是转换丢了回边，要么该登记 |
| `two-way cross-zone edges use the opposite direction name` | 双向边的回程方向必须是相反罗盘方向，或落在 `@custom_dirs` / `@asymmetric` 的显式例外里 |
| `the one-way allowlist still describes reality` | 白名单自身不许漂移：有回边了（可删）或边不存在了（要处理），都失败 |

#### `valid_leave` 守卫：**已数据化，但运行时故意不拦截**

- `data/world` 里有 **183 处** `valid_leave` 块，分布在 **48 个区**（`shaolin` 30、`city` 20、`beijing` 10、`death` 10…）。
- `pk:entry` 的守卫在产物里完整保留：
  ```
  { # 阻挡条件（原样保留）：dir == "north"
    direction = "north"
    message = "乌老大喝道：给我站住！那儿不能随意进入。" }
  ```
- loader 把它解析进 `Room.exit_vetoes`（`loader.ex:290` `parse_room_vetoes`），字段
  `direction` / `condition` / `message`。
- **但没有任何消费方** —— `grep exit_vetoes` 在 `lib/` 里只命中 loader 自己的解析函数。
  玩家现在可以直接从 `pk:entry` 往北走进 `pk:ready`，绕过乌老大。
- `taohua` 的幻阵**不是** `valid_leave` 守卫：`taohua` 全部 31 个房间的 `valid_leave` 数量为 **0**，
  它的迷阵靠 `__FILE__` 自指出口（4 条自环）实现，本来就不与外界相连，不受影响。
- **为什么不做拦截**：每条阻挡都带 LPC 条件表达式（`! me->query_temp("rent_paid") && dir == "up"`、
  `objectp(present("mang she", environment(me)))`），我们没有 LPC 求值器；而且 UCL 字符串里
  不能出现 `(`、`)`、`,`，所以条件只能以注释形式留存（见产物里那行 `# 阻挡条件（原样保留）`），
  loader 侧拿到的 `condition` 恒为 `nil` —— **运行时无法区分「有条件」和「无条件」阻挡**，
  强行拦截会误封。当前策略是结构化留存、不改变玩法，与 Elixir 版 loader 的注释一致
  （「出口阻挡兜底消息（LPC valid_leave 的 notify_fail）：结构化保留，不做数据驱动拦截」）。

---

## 六、遗留

### ✅ I. 最后一个预存测试失败（2026-10-01）

```
mix test test/kantele/world/loader_meta_test.exs
  1) test liandan_lin1 房间：宏继承合并属性生效（名称/描述），悬挂出口被丢弃
```

**不是 loader 的宏继承问题，也不是 `not is_nil` 过滤失效 —— 是测试自己拿错了房间。**

原代码：

```elixir
room = Enum.find(world.rooms, &(&1.key == "liandan_lin1"))
```

房间 `key`（不带区名）在全库大量重名：**432 个 key 有多个属主** —— `majiu` 出现在 22 个区、
`chufang` 20 个、`road2` 19 个、`kedian` 19 个，而 `liandan_lin1` **同时属于 `beijing` 和 `test`**。
`Enum.find` 只按迭代顺序取第一个，于是拿到的是 `beijing:liandan_lin1` —— 那是个**四条出口全都接通**的房间，
而测试声称要验的是 `test:liandan_lin1`（四条出口目标全不存在、只剩一条合成的 `down`）。

也就是说：这条断言**一直在检查错误的对象**，失败信息「悬挂出口 south 不应被保留」完全正确 ——
`beijing:liandan_lin1` 确实有 `south`。真正的 `test:liandan_lin1` 行为一直是对的：

```
test:liandan_lin1  name="城西后林"
  exits (1):  "down" -> "test:liandan_lin"
```

**修法**：全部改用带区名的 `id` 定位。同一文件里另外三处（`bet` / `cave` / `kedian`）也是按
`key` 找的，其中 **`kedian` 在 19 个区里重名**，属于同一个隐患 —— 这次没暴露只是因为迭代顺序
恰好没让它出错。已一并改掉，并加了 `assert Enum.any?(world.rooms, &(&1.id == "beijing:liandan_lin1"))`
把「重名是真的」钉进测试。

> 教训：跨区世界里 `key` 不是唯一键。凡是要断言**某个区**的某个房间，必须用 `id`。

验证：`mix test --seed 12345` → **3018 tests, 0 failures**（此前长期为 3008/1）。

---

## 七、已完成（回归基线，勿回退）

以下 20 个问题已修复并提交，**改动这些脚本时不得回退**。

**`scripts/lpc_converter.py`**

- [x] `_merge_vals` 空元组越界 —— 4 区无法转换（问题 1）
- [x] 跨区出口被当本区引用 —— 15 条静默连错（问题 2）
- [x] 方向名含数字 —— `huashan` 的 `hole1..6`（问题 3）
- [x] 方向名含中文 —— `shaolin` 八卦 64 条（问题 4，注释文案待 D 项修）
- [x] `item_desc` 中文 key 归一化成空 —— `changan`（问题 5）
- [x] 行尾 C 注释被当 mapping 项 —— `room`（问题 6）
- [x] `accept` 布尔/列表混淆泄漏 Python repr —— `taishan`（问题 7）
- [x] elias 分词：数字紧邻逗号 —— `xiangyang`（问题 8）
- [x] elias 分词：反斜杠接空白 —— `mingjiao`（问题 9）
- [x] LPC 行尾续行符 `\` 折叠（`_LPC_CONTINUATION`）

**`scripts/assign_room_coords.py`**

- [x] 垂直连接方向被占用时跳过，导致孤儿房不可达 —— `city` 的 `xsmidao*`（问题 12）
- [x] 跨区 `up`/`down` 视为方向已占用，避免重复键（elias 并成数组 → loader 崩）
- [x] 新增 `UP_DIR_CANDIDATES` / `DOWN_DIR_CANDIDATES`，跳到空闲复合方向

**`scripts/validate_ucl.py`**

- [x] 新增 `_ELIAS_BAD_KEY_RE`（key 含数字）+ fixture 45（问题 10）
- [x] 新增 `_ELIAS_UNLEXABLE_RE`（数字+逗号）+ fixture 44（问题 10）
- [x] 新增 `_ELIAS_STRAY_BACKSLASH_RE`（`\` + 空白）+ fixture 46（问题 10）
- [x] 新增 `_strip_comments()`，避免转换器的说明注释误报
- [x] 新增 `_is_object_only_zone()` 窄化豁免 + fixture 47 —— `tangmen`（问题 11）

**Elixir 侧**

- [x] `Kantele.Brain.Conditions.ChatChance` 冷却+概率，切断 NPC 闲聊自激（问题 20）
- [x] `ChatAction` 发布前写 session 时间戳
- [x] 测试改用 id 精确匹配，不再用物品名模糊匹配（问题 19）

**测试基线**

- [x] `test/fixtures/validate_ucl` 回归 **24/24**
- [x] `mix test test/kantele/world/` 190 tests / 1 failure（仅问题 I）
- [x] `mix test` 2988 tests / 1 failure（仅问题 I）
- [x] 71 区 `validate_ucl` + `check_room_coords` 全 exit 0
- [x] 容器内 elias 解析 70 个 `.ucl` 全通过

---

## 统计汇总

| 指标 | 数值 |
|------|------|
| 待办大项 | 9（A–I） |
| 已完成问题 | 20 |
| 未完成问题 | 1（17，已随 C 项登记为源数据缺陷） |
| 待验收区域 | 71 |
| 无注释丢失 | **0**（A+B 修复后） |
| 有注释的省略 | 18（`__FILE__` 修复后不再计入） |
| 同区悬空引用 | 18（源数据缺陷，已登记） |
| 不可达房间 | 340 / 4455 |

---

## 完成记录

| 日期 | 项 | 内容 | 验证方式 |
|------|----|------|----------|
| 2026-09-30 | 跨区接通 | 206 条跨区引用接通；15 条静默连错修正；可达率 0 → 91.4% | `mix test` 2988/1；elias 70 文件全过 |
| 2026-09-30 | NPC 闲聊刷屏 | `ChatChance` 冷却 500ms 切断指数发散 | `chat_runtime_test.exs` 12/12 |
| 2026-09-30 | 测试脆弱性 | 6 处物品名模糊匹配改 id 精确匹配，顺带修好 3 个失败 | `mix test` 2988/1 |
| 2026-09-30 | D 修复 | 方向跳过注释按真实原因分三类（空/CJK/数字/其它），不再误称 C 注释问题 | `test_lpc_path_rules.py` 48/48；70 区全绿；`mix test` 2991/1 |
| 2026-09-30 | B 扩展 | `__FILE__` 137 条真实修正为自环（此前是跳过+注释） | `cross_zone_wiring_test` 5/5；70 区全绿；可达率不变 |
| 2026-09-30 | A+B 修复 | `random(n)` 展开候选（shaolin 4 件佛经恢复）、同区子目录路径恢复 4 条、`d/<区名>/` 补前导斜杠恢复铁掌帮↔襄阳；`__FILE__` 133 条补注释 | 无注释丢失 136 → **0**；70 区 val/chk/elias 全绿；`test_lpc_path_rules.py` 28/28；`mix test` 2988/1 |
| 2026-10-01 | E 完成 | 两条悬空出口均无需改 LPC 语料：`baituo/gebi` 随宏继承修复恢复；`city/guangchang -liuxi->` 改用「方向名反查已安装 zone」的通用规则（`_INSTALLED_ZONE_IDS`），接通 `liuxi:guangchang`；`LiuxiCommand` 桩改为真移动，`liuxi:guangchang` 补 `yangzhou` 回城 | `test_lpc_path_rules.py` E 段 7/7；`liuxi_command_test`+`move_command_test`+`custom_direction_command_test` 46/46；`test/kantele/world/` 190/1（预存基线 `liandan_lin1`） |
| 2026-10-01 | G 完成 | 不可达房间全部分类完毕，**无一是转换缺陷**（78 设计孤立 + 61 非语料 + 67 语料从未接入 + 80 仅脚本传送 + 52 源码内部断连 + 2 无出口 = 340）。新增 `scripts/world_reachability.py`；修 `death/god1.c` 把 `set("exits")` 写在 `reset()` 里被丢弃的缺陷（`_backfill_exits_outside_create`），顺带去掉 `god2` 被伪造的 `up → hantan1` | `world_reachability.py` 92.4%（4115/4455，与 loader 侧 BFS 一致）；`test_lpc_path_rules.py` F 段 5/5；`test/kantele/world/`+2 文件 210/1（预存基线 `liandan_lin1`） |
| 2026-10-01 | H 完成 | 218 条跨区边：195 条双向（186 方向对称 + 6 自定义方向 + 3 有意不对称）、**23 条单向且全部在 LPC 源码里就是单向**，不补反向出口。`cross_zone_wiring_test.exs` 新增 3 条对性断言（单向白名单、双向方向名对称、白名单未漂移）。`valid_leave` 已数据化（183 处 / 48 区）但**运行时不做拦截**，条件是 LPC 表达式无法求值 | `cross_zone_wiring_test.exs` 8/8；`test/kantele/world/` 190/1（预存基线 `liandan_lin1`） |
| 2026-10-01 | I 完成 | 最后一个失败**不是** loader 问题：`loader_meta_test` 按 `key` 定位房间，而房间 key 全库有 432 个重名（`liandan_lin1` 同属 beijing 与 test），`Enum.find` 取到 `beijing:liandan_lin1` —— 一个四条出口全接通的房间，于是断言对象一直是错的。改为按 `id` 定位，并顺手修掉同文件另外三处同类隐患（`kedian` 重名 19 个区） | `loader_meta_test.exs` 25/25；**`mix test --seed 12345` → 3018 tests, 0 failures**（此前长期 3008/1） |
| | | | |

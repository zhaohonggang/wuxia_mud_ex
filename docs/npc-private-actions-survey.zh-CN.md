# NPC 私有动作勘查（P5-1 NPC 通道）

> 只读勘查。脚本：`scripts/survey_npc_private_actions.py`
> 结构化结果：`scripts/tmp/npc_private_actions.json`（当前剩余）
> 　　　　　　`scripts/tmp/npc_private_actions.baseline.json`（接线前基线）
> 复现：
> ```
> python scripts/survey_npc_private_actions.py
> python scripts/survey_npc_private_actions.py \
>     --ignore-global chazhang,convert,cun,deposit,duihuan,qu,transfer,withdraw,zhuan \
>     --out scripts/tmp/npc_private_actions.baseline.json
> ```

## 1. 结论摘要

| 指标 | 接线前基线 | 当前剩余 |
|---|---:|---:|
| 全局命令 verb（`commands.ex` 的 `parse`） | 394 | 403 |
| NPC `.c` 文件（`*/npc/*.c`，**不含 `npc/obj/`**） | 1299 | 1299 |
| 其中含 `add_action` 的文件 | 225 | 225 |
| `add_action` 调用总数 | 565 | 565 |
| 不同 verb | 108 | 108 |
| 已由全局命令覆盖 | 31 个 / 373 次（66%） | **40 个 / 449 次（79%）** |
| 私有 verb（全局表里没有） | 77 个 / 192 次 | **68 个 / 116 次** |
| 其中移动/方向类（出口系统管） | 0 | 0 |
| 私有 handler 本地未定义（继承/头文件里的） | 15 | 15 |
| 基类动作（多 NPC 共用一份实现） | 2 | 0（已接线） |
| **死功能（不需要移植）** | **1 个 / 10 次** | **1 个 / 10 次** |
| 疑似已有实现、只缺顶层动词接线 | 18 个 / 99 次 | 7 个 / 20 次 |

按顶层分区（私有调用次数，当前）：`d/` 61、`adm/` 42、`b/` 9、`clone/` 2、`u/` 2。
**`adm/` 是巫师工具（鲁班/风/裁判等），不属玩家玩法，应排除**：`adm/` 分区里的私有调用共 **42 次**（含 `bi`/`show`/`choose`/`decide` 等跨区 verb 落在 `adm/` 的那部分）；其中**只在 `adm/` 注册的 verb 是 31 个 / 34 次**（见 §4 排除项）。下面的工作量表按**分区口径**剔 42 次。

**把噪音剔干净后的真实工作量**（按**分区**算，不是按 verb 算 —— 一个 verb 可能既有
`adm/` 又有 `d/` 的注册者，只剔 `adm/` 那部分调用）：

| 口径 | verb | 调用 |
|---|---:|---:|
| 私有总计 | 68 | 116 |
| − `adm/` 分区里的调用（巫师工具） | — | −42 |
| = 玩家可达（有非 `adm/` 注册者的 verb / 非 `adm/` 调用） | 37 | **74** |
| − 死功能（`join`，函数体开头就 `return notify_fail`） | −1 | −10 |
| = **玩家可达、真需实现** | **36** | **64** |
| − `ride*` 十连（马童快速旅行，**一份实现覆盖 10 个动词**） | −10 | −10 |
| = 需要独立设计的动作数 | **26** | **54** |

## 2. 与上一版的差异（数字变动的三个原因）

上一版报告写的是「NPC 1863 文件 / 578 调用 / 私有 81 个 200 次」，本版全部变了。原因有三个，都不是「世界变了」：

1. **分类器修正（真实错误）**：`d/<zone>/npc/obj/*.c` 是**物品**目录（乐器、面具、箱子…），
   共 564 个文件。上一版只判「路径里有 `/npc/`」就当成 NPC，把 13 次 `add_action`
   算进了 NPC 通道。其中最关键的是 `play`（琴/箫）—— 它**不是 NPC 动作**，
   是乐器对象注册的，`inherit/misc/_qin.c` 的 `play_qin` 只是被乐器 inherit。
   → 脚本改成 `kind_of/1` 按目录判型，NPC 文件数 1863 → 1299。
2. **钱庄别名已接线（`6944ffaf`）**：脚本读的是**当前**的 `commands.ex`，所以每接一个
   动词别名，同一个 verb 就从「私有」挪到「已覆盖」。钱庄那 9 个（`cun`/`qu`/`deposit`/
   `withdraw`/`convert`/`duihuan`/`transfer`/`zhuan`/`chazhang`）接好后，
   **76 次调用从私有转成覆盖**，私有 192 → 116。
   → 为能横向比较，脚本加了 `--ignore-global`，可冻结接线前的基线（上表左列）。
3. **`.h` 也扫了（真实修正）**：LPC 有把 handler 定义在头文件再 `#include` 的写法。
   `d/beijing/npc/matong.c` 的 10 个 `do_rideXX` 全在 `matongXX.h` 里，
   上一版只扫 `.c`，把它们误判成 `undefined`。

## 3. 为什么不能按 UCL 的 `add_actions` 逐 NPC 回填

R9 已确认 UCL 里的 `init.add_actions` 是**基类继承动词**：2024 个 NPC / 3617 条，但只有 77 个不同 verb，`list`+`buy` 占 62%（已由 shop 通道覆盖）。

本次在 **handler 层**发现了同一现象的第二重证据：大量 NPC 只 `add_action("do_deposit", "deposit")`，**函数体并不在自己文件里**，而是来自共享基类或 `#include` 的头文件。15 个 handler 属这种情况：

| handler | 注册它的 NPC 数 | 定义处 |
|---|---:|---|
| `do_convert` | 10 | `feature/banker.c`、`inherit/room/bank.c` |
| `do_deposit` | 10 | `feature/banker.c`、`inherit/room/bank.c` |
| `do_transfer` | 2 | `feature/banker.c` |
| `do_join` | 10 | `kungfu/class/yunlong/tiandihui.h` |
| `do_rideXX`（10 个） | 各 1（同一个马童 NPC） | `d/beijing/npc/matongXX.h` |

**推论**：NPC 私有动作的正确单位是「基类 / 共享功能模块 / 头文件」，不是「NPC 文件」。逐 NPC 移植会把同一份逻辑抄 10 遍。

## 4. 三档分类（本勘查的核心产出）

### 第 1 档：已有实现，只缺顶层动词接线 — ✅ 已完成（`6944ffaf`）

`BankCommand` 已完整实现存 / 取 / 查 / 兑换（`Kantele.Npc.Banker` 就是 `banker.c` 的移植），但只注册了 `bank` / `银行` 两个顶层动词。而 LPC 的 NPC 是把子命令当**独立顶层动词**注册的：

| verb | 基线调用次数 | 现状 |
|---|---:|---|
| `duihuan` | 13 | ✅ 已接 → `BankCommand.convert` |
| `withdraw` | 11 | ✅ 已接 → `BankCommand.withdraw` |
| `convert` / `cun` / `deposit` / `qu` | 各 10 | ✅ 已接 |
| `transfer` / `zhuan` | 各 1 | ✅ 已接 |
| `chazhang` | 10 | ✅ 已接 → `BankCommand.show` |

合计 **76 次调用**，改动只在「拆词 → 转调」，没有复制任何存取逻辑。`check` **没有**被接管（它在 Kantele 已是全局命令「查看某人」，需目标参数，抢了会让玩家在任意房间的 `check` 改道钱庄）；`chexiao`（1 次，只在 `adm/npc/luban.c`，巫师工具）**未接**。

> 接线时踩到两个 router 坑，后续补动词都会遇到：
> ① 同一个 verb 用**同一个函数名**注册两次会因默认参数重复定义而编译失败
> （`parse` 宏按 `parsep_<verb>_<fun>` 生成函数）→ 裸动词要用 `<fun>_bare`。
> ② `Router.parse_text/4` **不要求 leftover 为空**，只写字面量的裸注册会
> 前缀匹配掉更长的动词（`qu` 会抢走 `quanjia`/`quest`/`quit`）→ 裸形式必须加 `eos()`。

### 第 2 档：一份实现覆盖多个动词

**`ride*` 十连（10 个 verb / 10 次调用）** —— `d/beijing/npc/matong.c` 注册
`ridedl`/`rideem`/`ridefs`/`ridefz`/`ridehz`/`ridesz`/`ridexy`/`rideyd`/`rideyl`/`rideyz`
十个动词，实现是 10 个 62 行、几乎逐字相同的头文件（`matongdl.h` … `matongyz.h`）。

语义：**马童快速旅行**（八卦门专属）。检查门派 → 检查是否已在骑乘 → `random(3)` 抽马名 →
沿 `front_yard → gate → di_anmen → dahejiewest → bingying → majiu` 逐房间 `move` 并
`tell_room` 播报「骑着某马一路招摇疾驰而过」→ 落点「跃下马来」。
10 个头文件只差**目的地**（最后一个 `move` 的路径）与马名池，属典型的「参数化一份实现」。

### 第 3 档：真新实现，逐动作写（玩家可达 36 个 verb / 64 次）

| verb | 次数 | 语义（据 handler 名与源文件） |
|---|---:|---|
| `bi` | 14 | 比武 / 比划（`do_bi` / `do_bihua` / `begin`）。**深度依赖任务状态**：倚天屠龙记的阿大/阿二/阿三要 `query_temp("win_aer")`、`present("shelf")`、倚天剑在手才肯打 |
| `decide` | 5 | 拍卖 / 抽签决策（`do_decide` / `decide_withdraw`） |
| `compare` | 4 | 赌场比大小（`b/tulong`，`do_compare` 直接 `kill_ob` 开打） |
| `show` | 4 | 展示（3/4 在 `adm/`，`do_show` 只是 `show_desc()` 的一层皮） |
| `yun` | 4 | 运功 / 琴韵（**纯输出**，最便宜） |
| `choose` | 3 | 选（兽商 / 马商，`do_choose` / `do_selete`） |
| `yao` | 3 | 摇（骰子 / 签） |
| `bian` | 2 | 灵蛇变身（handler 名叫 `convert`，**不是**钱庄动作） |
| `bihua` / `copy` / `exchange` / `mine` / `serve` | 各 2 | 比划 / 抄录 / 兑换 / 挖矿 / 上菜 |
| `kneel` / `move` / `peiyao` / `puzzle` / `read` / `recopy` / `recover` / `sew` / `sign` / `task` / `txbw` / `unjoin` / `zhanbu` | 各 1 | 一次性动作 |
| `ride*` ×10 | 各 1 | 见第 2 档 |

> 表按 **verb 粒度**统计（一个 verb 可能同时有 `adm/` 与 `d/` 的注册者，如 `show` 4 次里 3 次在 `adm/`、
> `choose` 3 次里 2 次在 `adm/`）。「36 个 / 64 次」是只数**非 `adm/` 分区**的调用、再剔掉死功能后的总量。

### 排除项

- **`adm/` 专属 verb 31 个 / 34 次**（若按**分区口径**、含跨区 verb 落在 `adm/` 的调用则为 42 次）：鲁班（房屋建造/改名/拆除）、风（拍卖行）、公平子（比武裁判）等巫师工具，不属玩家玩法。
- **`join` 10 次 —— 死功能**：`kungfu/class/yunlong/tiandihui.h` 的 `do_join` 第一句就是
  `return notify_fail("天地会正在清理叛徒，不对外招人。\n");`，后面整段入会逻辑（威望/神值/堂口随机）**永远不执行**。玩家敲 `join` 只会得到这句话，**不需要移植**。
  （脚本的 `dead` 字段自动检测：第一个 `return` 之前无分支、且其后仍有大段代码。）

## 5. 物品侧（`/obj/`，不属于 NPC 通道，但同样没接线）

`d/<zone>/npc/obj/` 与 `/obj/` 是**物品**，它们的 `add_action` 走的是物品通道，Kantele 侧**目前没有任何 `actions` 入口**（见后续计划的 item `actions` UCL 条目）。

| 指标 | 数值 |
|---|---:|
| 物品 `.c` 文件 | 1426 |
| `add_action` 调用 | 158 |
| 不同 verb | 58 |
| 私有 verb | 42 个 / 72 次 |

私有 verb 前 10：`play=11`、`move=6`、`du=5`、`xi=4`、`read=4`、`pretend=3`、`bian=2`、`tear=2`、`dian=2`、`wish=1`。

最大一块是 `play`（琴/箫/筝，11 次）—— 全部委托给 `SKILL_D("tanqin-jifa")->play()`，
物品侧只提供 `valid_as_qin()` 之类的判定；`play_xiao`/`play_zheng` 是同一份逻辑的变体。
**这是物品通道的第一个候选，与 NPC 通道无关。**

## 6. NPC 分发层已落地 + `yun` 首个样板（2026-10-17）

钱庄别名能一行搞定，是因为它落在**已有**的 `BankCommand`（全局命令模块）上。
剩下的 NPC 私有动词必须在「玩家敲了动词、房间里有个 NPC 注册了这个动词」
时被触发。本轮已打通这个分发层：

| 阶段 | 状态 | 内容 |
|---|---|---|
| `Kantele.World.NpcAction` 行为契约 | ✅ 已落地 | `lib/kantele/world/npc_action.ex`；`run(conn, params)`，`params` 含 `:verb`/`:trailing`/`:room_id`/`:npc` |
| `Kantele.World.NpcActionDispatcher` | ✅ 已落地 | `lib/kantele/world/npc_action_dispatcher.ex`；`extract_verb/1` + `resolve/3` + `dispatch/3`，`lookup_fun` 可注入 |
| `Kantele.World.NpcActionHandlers` 注册表 | ✅ 已落地 | `lib/kantele/world/npc_action_handlers.ex`；房间级 `lookup(room_id, verb)`，初始 4 个 `yun` 条目 |
| `command_controller.ex:recv/2` 接线 | ✅ 已落地 | 在 `RoomActionDispatcher.dispatch` 之后、`Commands.call` **之前**插入 NPC 分发 |
| 首个样板 `yun` | ✅ 已落地 | `lib/kantele/world/npc_actions/yun.ex`；`arg == "roar"` → `Helpers.broadcast_vision/3` 广播，否则 `:not_handled` |

**关键设计决策（与房间通道对称，空注册表 → P7 dormant，对全局命令零影响）：**

- `NonPlayerMeta.init.add_actions` 已被 loader 读入（`parse_enter_init/1`，存的是**玩家输入的 verb**），现在由 `NpcActionDispatcher` 消费。
- `room` 进程的 `state.private.characters` 里是**完整**的 NPC 结构体（含 `meta.init.add_actions`），`Kalevala.World.Room.Context.new/1` 只清空 `inventory`、`meta` 完整保留。
- 注册表按 **`room_id`**（UCL 房间 id，重启不变）索引，**不使用** `Character.generate_id()`（运行期随机 id，重启就变）。
- `yun` 覆盖 4 个注册（殷素素：`tulong:huichang_back`/`tulong:huichang`；赵一伤：`tulong:jiulou`/`tulong:was_dayuan`），LPC 源 `d/tulong/tulong/npc/yin.c`、`d/tulong/yitian/npc/zhao.c` 均按 `arg == "roar"` → `message_vision` + `return 1`，否则 `return 0`。
- 新增测试 3 个文件约 30 条用例（dispatcher / handlers / yun），经 `elixirc` 编译验证；全量 `mix test` 因沙箱环境缺 `:ssl_verify_fun`（与本次代码无关）暂未跑通，后续会话需补验证。

**下一步（在本文档 §7 顺序中已标示）**：继续 NPC 私有动作，`ride*` 十连为下一批。

## 7. 推荐执行顺序（按「收益 / 成本」重排）

1. ~~**钱庄动词别名**（76 次，只缺接线）~~ — ✅ **已完成（`6944ffaf`）**
2. ~~**纯输出型 `yun`（4 次）** + NPC 分发层~~ — ✅ **已完成（2026-10-17，分发层 + `yun` 样板落地）**
3. **`ride*` 十连（10 次 / 1 份实现）** —— 参数化马童快速旅行；需要 `move` + `tell_room`
   的连续播报，是「一份实现覆盖 N 动词」的样板。（下一批）
4. **`bi` / `compare` / `yao` / `decide`（26 次）** —— 比武、赌场、拍卖，有状态与随机性，
   且 `bi` 深度依赖任务状态，最贵，最后做。
5. **`adm/` 分区 42 次直接排除**（巫师工具；其中专属 verb 31 个 / 34 次）。
6. **`join` 10 次直接排除**（死功能）。
7. **物品侧 `play`（11 次）另开一条通道**，不混进 NPC 计划。

## 8. 已知局限

- **「疑似已有实现」是字符串匹配，会假阳性**。脚本对 verb 和 handler 去 `do_` 前缀后的名字都做匹配，所以 `d/baituo/npc/lingshe.c` 的 `bian` 因 handler 叫 `convert` 被误判为钱庄动作 —— 实际是「灵蛇变身」（`convert("ling she")`）。**每个 hint 都要回源确认语义**。
- **`dead` 检测是启发式的**：只认「第一个 `return` 前无分支 + 其后仍有 ≥80 字符代码」。
  反向漏报（死代码藏在 `if` 里）不查；`//` 注释掉的 `return` 不参与判断。
- **handler 体分类是启发式的**（关键词命中：`write`/`message` = 纯输出，`->set`/`->move`/`clone_object` = 改状态，`kill_ob`/`->die` = 战斗）。注释里的关键词会影响判定；`->start_busy` 被**特意排除**在战斗之外（钱庄、比武招亲都会用它占用玩家），单列 `busy` 字段供 B2 参考。
- **继承解析只做一层**：pass 2 在全部 `.c`+`.h` 里按「带返回类型的函数定义」找 handler 定义处，不展开 `inherit` 链。若某 handler 定义在更深的基类里，会记为 `undefined`（当前为 0 个）。
- **`b/` 不是备份**：`d/beijing/huiying.c` 的 `up` 出口指向 `/b/yitian/jiulou`，`d/beijing/road10.c` 的 `east` 指向 `/b/tulong/haigang`，是**可达区域**（倚天屠龙记副本），其 9 次私有调用要算进工作量。
- 语料里没有 `d/liuxi`（新手区在 Kantele 侧另有来源），本勘查只覆盖 LPC 语料。

## 9. 与 shop 通道的关系

R9 的结论「NPC 通道从基类入手」在这一轮得到验证，且 **shop 那一半已完成**（`NpcShopEvent` + `Room.ShopRequestEvent`，见 `c85fa7a9`）：

- `list`(1096) + `buy`(1094) 覆盖了 UCL `add_actions` 的 62%，已走 shop 通道；
- 通用动词（`hit`/`fight`/`beg`/`steal` 等）多数已有全局命令 —— 本次勘查量化了这一比例：**449/565 = 79% 的 `add_action` 调用落在已有全局命令上**（接线前是 66%）；
- 真正剩下的私有动作只有 116 次调用，只数非 `adm/` 分区并剔除死功能后 **64 次**，其中 10 次还是「一份实现覆盖十个动词」的马童。

## 10. 顺带发现（未修）：`BankCommand.convert` 的成交文案金额不对

接 `duihuan` 时核对到：`bank convert 5 silver to coin` 实际把 5 两白银换成
**500 文铜钱**（`Banker.do_convert` 的 `to_amount = div(amount * from_base, to_base)`），
但提示写成 `to_value = denom_base(to) * amount` = 5 → 「你把五两白银兑换成了五文铜钱。」

LPC 的 `do_convert` 文案是两个**各自单位的数量**（`chinese_number(amount)` + 源单位 /
`chinese_number(amount * bv1 / bv2)` + 目标单位）。要改对需要 `Money` 暴露一个
「按单位格式化数量」的函数（现在只有按**总价值**格式化的 `money_str/1`，
`chinese/1` 与 `unit_of/1` 都是私有的），所以本轮没有顺手改 —— 见 progress §14 R11。

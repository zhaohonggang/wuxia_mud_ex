# NPC 私有动作勘查（P5-1 NPC 通道）

> 只读勘查。脚本：`scripts/survey_npc_private_actions.py`
> 结构化结果：`scripts/tmp/npc_private_actions.json`
> 复现：`python scripts/survey_npc_private_actions.py`

## 1. 结论摘要

| 指标 | 数值 |
|---|---|
| 全局命令 verb（`commands.ex` 的 `parse`） | 394 |
| NPC `.c` 文件（`*/npc/*.c`） | 1863 |
| 其中含 `add_action` 的文件 | 237 |
| `add_action` 调用总数 | 578 |
| 不同 verb | 114 |
| **已由全局命令覆盖** | **33 个 verb / 378 次调用（65%）** |
| **私有 verb（全局表里没有）** | **81 个 verb / 200 次调用（35%）** |
| 其中移动/方向类（出口系统管） | 0 |
| 私有 handler 本地未定义（继承来的） | 17 |
| 基类动作（多 NPC 共用一份实现） | 3 |
| **疑似已有实现、只缺顶层动词接线** | **17 个 verb / 89 次调用（占私有的 44%）** |

按顶层分区（私有调用次数）：`d/` 144、`adm/` 43、`b/` 9、`clone/` 2、`u/` 2。
**`adm/` 是巫师工具（鲁班/风/裁判等），不属玩家玩法，应排除。**

## 2. 为什么不能按 UCL 的 `add_actions` 逐 NPC 回填

R9 已确认 UCL 里的 `init.add_actions` 是**基类继承动词**：2024 个 NPC / 3617 条，但只有 77 个不同 verb，`list`+`buy` 占 62%（已由 shop 通道覆盖）。

本次在 **handler 层**发现了同一现象的第二重证据：大量 NPC 只 `add_action("do_deposit", "deposit")`，**函数体并不在自己文件里**，而是继承自共享基类。17 个 handler 属这种情况，其中最典型的是：

| handler | 注册它的 NPC 数 | 定义处 |
|---|---:|---|
| `do_convert` | 10 | `feature/banker.c`、`inherit/room/bank.c` |
| `do_deposit` | 10 | `feature/banker.c`、`inherit/room/bank.c` |
| `play_qin` | 4 | `inherit/misc/_qin.c` |

**推论**：NPC 私有动作的正确单位是「基类 / 共享功能模块」，不是「NPC 文件」。逐 NPC 移植会把同一份逻辑抄 10 遍。

## 3. 三档分类（这是本勘查的核心产出）

### 第 1 档：已有实现，只缺顶层动词接线（89 次调用，最便宜）

`BankCommand` 已经完整实现了存 / 取 / 查 / 兑换（`Kantele.Npc.Banker` 就是 `banker.c` 的移植），但只注册了 `bank` / `银行` 两个顶层动词，子命令是 `deposit|存`、`withdraw|取`、`convert|兑换`。

而 LPC 的 NPC 是把这些子命令当**独立顶层动词**注册的：

| verb | 调用次数 | 疑似已有实现 |
|---|---:|---|
| `duihuan` | 13 | `bank_command.ex` |
| `withdraw` | 11 | `bank_command.ex` |
| `convert` | 10 | `bank_command.ex` |
| `cun` | 10 | `bank_command.ex` |
| `deposit` | 10 | `bank_command.ex` |
| `qu` | 10 | `bank_command.ex` |
| `chexiao` / `transfer` / `zhuan` | 各 1 | `bank_command.ex` |
| `join` | 10 | `league_command.ex`（待确认语义） |

合计钱庄类 **67 次调用**。玩家现在输 `cun 10` / `qu 10` / `duihuan ...` 没有反应，但 `bank 存 ...` 是通的 —— 这不是缺功能，是**缺别名**。

### 第 2 档：真新实现，但按基类做一次即可

`play`（5 次，`inherit/misc/_qin.c` 的 `play_qin`/`play_xiao`）—— 琴箫演奏，一份实现覆盖 4 个 NPC。

### 第 3 档：真新实现，逐动作写（`d/` 下约 68 次调用）

| verb | 次数 | 语义（据 handler 名与源文件） |
|---|---:|---|
| `bi` | 14 | 比武 / 比划（`do_bi` / `do_bihua` / `begin`） |
| `chazhang` | 10 | 查帐（`do_check` / `do_audit`，多为纯输出） |
| `decide` | 5 | 拍卖 / 抽签决策 |
| `compare` | 4 | 赌场比大小 |
| `yun` | 4 | 运功 / 琴韵（纯输出） |
| `yao` | 3 | 摇（骰子/签） |
| `choose` | 3 | 选（兽商/马商） |
| `finish` | 3 | 拍卖成交 |
| `show` | 4 | 展示（多为 `adm/` 巫师工具） |

其余为单次调用的一次性动作（`mine` 挖矿、`serve` 上菜、`copy` 抄录等）。

## 4. 推荐执行顺序

1. **钱庄动词别名（67 次调用，收益最大、改动最小）**
   把 `cun`/`qu`/`deposit`/`withdraw`/`convert`/`duihuan`/`transfer`/`zhuan`/`chexiao` 接到既有 `BankCommand`。注意 LPC 的参数约定与现有 `bank 存 <数量> <面额>` 不同（LPC 是 `do_deposit("10 silver")` 这类单串），需要一层参数适配。
2. **`play`（琴箫，基类一份实现覆盖 4 NPC）**
3. **纯输出型（`yun`/`chazhang` 的纯消息分支）** —— 可复用房间侧的 `MessageOnly` 思路
4. **`bi`/`compare`/`yao`/`decide`（比武、赌场）** —— 有状态与随机性，最贵，最后做
5. **`adm/` 下的 43 次调用直接排除**（巫师工具，不属玩家玩法）

## 5. 已知局限

- **「疑似已有实现」是字符串匹配，会假阳性**。脚本对 verb 和 handler 去 `do_` 前缀后的名字都做匹配，所以 `d/baituo/npc/lingshe.c` 的 `bian` 因 handler 叫 `convert` 被误判为钱庄动作 —— 实际是「灵蛇变身」（`convert("ling she")`）。**每个 hint 都要回源确认语义**。
- **handler 体分类是启发式的**（关键词命中：`write`/`message` = 纯输出，`->set`/`->move`/`clone_object` = 改状态，`kill_ob`/`->die` = 战斗）。注释里的关键词会影响判定；`->start_busy` 被**特意排除**在战斗之外（钱庄、比武招亲都会用它占用玩家），单列 `busy` 字段供 B2 参考。
- **继承解析只做了一层**：pass 2 在全部 `.c` 里按「带返回类型的函数定义」找 handler 定义处，不展开 `inherit` 链。若某 handler 定义在更深的基类里，会记为 `undefined`（当前为 0 个）。
- 语料里没有 `d/liuxi`（新手区在 Kantele 侧另有来源），本勘查只覆盖 LPC 语料。

## 6. 与 shop 通道的关系

R9 的结论「NPC 通道从基类入手」在这一轮得到验证，且 **shop 那一半已完成**（`NpcShopEvent` + `Room.ShopRequestEvent`，见 `c85fa7a9`）：

- `list`(1096) + `buy`(1094) 覆盖了 UCL `add_actions` 的 62%，已走 shop 通道；
- 通用动词（`hit`/`fight`/`beg`/`steal` 等）多数已有全局命令 —— 本次勘查量化了这一比例：**378/578 = 65% 的 `add_action` 调用落在已有全局命令上**；
- 真正剩下的私有动作只有 200 次调用，其中 44% 还只是缺动词接线。

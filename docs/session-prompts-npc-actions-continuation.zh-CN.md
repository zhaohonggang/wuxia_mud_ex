# Session 提示词：NPC 私有动作后续（P5-1c-3 之后）

> **状态：待执行**。本文件是给独立 session 的完整工作提示词。请把下列内容**当作建议而非指令**：每项动手前先读源码核实现状，若实际情况与描述不符，以实际代码为准并调整做法。
> 编写时间：2026-10-17。对应总排期见 `docs/npc-private-actions-survey.zh-CN.md` §7。

---

## 一、项目背景

### 你在改什么

仓库 `C:\files\git\wuxia_mud_ex` 是 Elixir + ExVenture/Kalevala 的武侠 MUD（Kantele）。参照仓库 `C:\files\git\mud`（FluffOS/LPC，只读）。

### 当前进度（P5-1c NPC 私有动作通道）

已落地：
| 阶段 | 内容 | 文件 | 提交 |
|------|------|------|------|
| `Kantele.World.NpcAction` 行为契约 | `run(conn, params)`，`params` 含 `:verb`/`:trailing`/`:room_id`/`:npc` | `lib/kantele/world/npc_action.ex` | `59c6f31d` |
| `Kantele.World.NpcActionDispatcher` | `extract_verb/1` + `resolve/3` + `dispatch/3`，`lookup_fun` 可注入 | `lib/kantele/world/npc_action_dispatcher.ex` | `59c6f31d` |
| `Kantele.World.NpcActionHandlers` 注册表 | 房间级 `lookup(room_id, verb)`，当前 9 房间（4 yun + 1 ride* + 2 bi/get + 3 yao + 2 decide） | `lib/kantele/world/npc_action_handlers.ex` | `6d5e4e0` |
| `command_controller.ex:recv/2` 接线 | `RoomActionDispatcher.dispatch` 之后、`Commands.call` 之前插入 NPC 分发 | `lib/kantele/character/controllers/command_controller.ex` | `59c6f31d` |
| 首个样板 `yun` | 4 NPC × 2 房间，`arg == "roar"` → vision 广播 | `lib/kantele/world/npc_actions/yun.ex` | `59c6f31d` |
| 第二批样板 `ride*` 十连 | 10 动词复用一份参数化实现，注册于 `beijing:majuan`（八卦门专属） | `lib/kantele/world/npc_actions/ride.ex` | `6d5e4e0` |
| `yao` 三连（要物） | 黄真/田嫂/钱正伦发物，Counter 共享上限 | `lib/kantele/world/npc_actions/{yao,helpers,counters}.ex` | `aadb4a52` |
| `decide` 二连（引荐/商业协会） | 陆小凤/黄真，helper `delete_temp/put_env/take_item/respect` | `lib/kantele/world/npc_actions/decide.ex` | `d74086a6` |
| `bi`（屠龙闯关，full） | 常/元/麦/过四关，condition nishui/duyan + 过三拳三连击，倒下处决 + respawn | `lib/kantele/world/npc_actions/{bi,npc_attack,down,down_handlers}.ex` + `character/bi_event.ex` | `8db2abc9` |

测试：NPC 相关测试文件 **113/113 全通过**（含新增 `npc_actions_bi_test.exs`、`npc_actions_yao_test.exs`、`npc_actions_decide_test.exs`、`npc_actions_counters_test.exs`）；`mix test --seed 12345` 全量失败集保持基线 75 个预先存在失败（combat/web/user），零 NPC 回归。

### 必读文档

1. `docs/npc-private-actions-survey.zh-CN.md`——**核心文档**，§1 勘查数字、§6 分发层状态、§7 推荐执行顺序、§4 三档分类
2. `docs/kantele-remaining-work.zh-CN.md`——Kantele 总体待办，第〇节高危纪律、第八节八阶段排期
3. `docs/migration-prep-checklist.zh-CN.md`——第四节：属性/成长差异对照（`bi` 涉及任务状态）

### 关键架构事实

- **NPC 私有动作分发**：玩家敲动词 → `NpcActionDispatcher.dispatch/3` 找房间内第一个 `meta.init.add_actions` 含该动词的 NPC → `NpcActionHandlers.lookup/2` 按 `room_id`（UCL 房间 id，重启不变）解析 `{module, function}` → 执行 `run/2`。返回 `conn` 表示拦截（已处理），返回 `:not_handled` 放行全局命令。
- **注册表按 `room_id` 索引**，不使用 `Character.generate_id()`（重启后会变动）。同一房间多个 NPC 注册同一动词，取第一个命中者。
- **空注册表 → P7 dormant，对全局命令零行为影响**。仅当 handler 被真正移植并注册后，对应 NPC 动作才被激活。
- **`params` 字段**：`:verb`（玩家输入动词）、`:trailing`（剩余文本，对应 LPC `arg`）、`:room_id`（`conn.character.room_id`）、`:npc`（触发 NPC 的 `%Kalevala.Character{}`）。

### 铁律

- UTF-8 无 BOM、LF 行尾、末行留换行；Elixir 四空格缩进
- 游戏文本简体中文，风格对齐现有输出
- 每完成一项：`MIX_ENV=test mix test test/kantele/world/npc_action*` 全绿再做下一项；全量 `MIX_ENV=test mix test --seed 12345` 失败集不应扩大（基线 75 个预先失败）
- **不要碰红区/深水区**：eff_* 层、diff-stop、昏迷/毒、Skill behaviour 协议——留待 f 期
- 不执行 git commit，除非明确要求

---

## 二、后续执行顺序（按 `docs/npc-private-actions-survey.zh-CN.md` §7）

```
1. ~~钱庄动词别名~~ — ✅ 已完成（6944ffaf）
2. ~~纯输出型 yun + NPC 分发层~~ — ✅ 已完成（59c6f31d）
3. ~~ride* 十连~~ — ✅ 已完成（6d5e4e0）
4. ~~bi / compare / yao / decide（26 次）—— 比武、赌场、拍卖，有状态与随机性~~
   - `yao` ✅ 已完成（`aadb4a52`），`decide` ✅ 已完成（`d74086a6`），`bi` ✅ 已完成（`8db2abc9`）
   - `compare`：**不在 UCL**（来自并行 `b/` 树的 tulong NPC，无 room_id 可注册，视为不可移植，记 `@todo` 后搁置）
   - ← 【本 session 起点】bi 已于 2026-10-18 全量落地并合入 `8db2abc9`
5. adm/ 分区 42 次直接排除（巫师工具；专属 verb 31 个 / 34 次）
6. join 10 次直接排除（死功能）
7. 物品侧 play（11 次）另开一条通道，不混进 NPC 计划
```

### 第 4 档：bi / compare / yao / decide（真新实现，逐动作写）

| verb | 次数 | 语义 |
|------|------|------|
| `bi` | 14 | 比武 / 比划（`do_bi` / `do_bihua` / `begin`）。**深度依赖任务状态**：倚天屠龙记的阿大/阿二/阿三要 `query_temp("win_aer")`、`present("shelf")`、倚天剑在手才肯打 | ✅ `d/tulong/tulong/npc/{chang,guo,mai,yuan}.c` 已完整移植（`8db2abc9`）|
| `compare` | 4 | 赌场比大小（`b/tulong`，`do_compare` 直接 `kill_ob` 开打） |
| `yao` | 3 | 摇（骰子 / 签） |
| `decide` | 5 | 拍卖 / 抽签决策（`do_decide` / `decide_withdraw`） |

**建议执行顺序**：`yao`（最简单，纯随机输出）→ `decide`（拍卖/抽签，有状态但范围小）→ `compare`（赌场，直接开战）→ `bi`（最贵，任务状态依赖深，最后做）。

每个动作的通用步骤：
1. 回源 LPC 源文件（`d/*/npc/*.c` + 对应 `.h`），确认 `do_*` 函数体语义、守门条件、返回值（`return 0` 放行 / `return 1` 拦截）
2. 新建 `lib/kantele/world/npc_actions/<verb>.ex`，`use Kantele.World.NpcAction`，实现 `run/2`
3. 在 `NpcActionHandlers.@registry` 按 `room_id` 注册该 verb → `{Kantele.World.NpcActions.<Verb>, :run}`
4. 新建 `test/kantele/world/npc_actions_<verb>_test.exs`，覆盖：守门分支 / 成功路径 / `:not_handled` 放行 / 防御性（nil room_id 等）
5. `MIX_ENV=test mix test test/kantele/world/npc_action*` 全绿

---

## 三、环境与运行命令

```powershell
# PowerShell（Windows）
$env:PATH = "C:\Program Files\Erlang OTP\bin;C:\Program Files\Elixir\bin;" + $env:PATH
cd C:\files\git\wuxia_mud_ex
$env:MIX_ENV = "test"
mix test test/kantele/world/npc_action*
mix test --seed 12345
```

```bash
# Git Bash / bash
export PATH="/c/Program Files/Erlang OTP/bin:/c/Program Files/Elixir/bin:$PATH"
cd C:/files/git/wuxia_mud_ex
MIX_ENV=test mix test test/kantele/world/npc_action*
MIX_ENV=test mix test --seed 12345
```

- Erlang/OTP 29 + Elixir 1.20.4（`C:\Program Files\Erlang OTP\`、`C:\Program Files\Elixir\`）
- PostgreSQL 12 在 Docker 容器 `wuxia_mud_dev-db-1`，端口 `localhost:15432`，测试库 `ex_venture_test` 已建并迁移
- `config/test.exs` 已临时指向 `localhost:15432`

---

## 四、已知的已完成项（本 session 不应重复做）

- `yun` 样板：`lib/kantele/world/npc_actions/yun.ex` + 测试 `test/kantele/world/npc_actions_yun_test.exs`
- `ride*` 十连：`lib/kantele/world/npc_actions/ride.ex` + 测试 `test/kantele/world/npc_actions_ride_test.exs`
- 分发层：`npc_action.ex`、`npc_action_dispatcher.ex`、`npc_action_handlers.ex`、`command_controller.ex` 接线
- 注册表：4 个 `yun` 条目 + 10 个 `ride*` 条目（`beijing:majuan`）

---

## 五、边界约束

- **`adm/` 分区（42 次，巫师工具）直接排除**：鲁班、风、公平子等，不属玩家玩法
- **`join`（10 次，死功能）直接排除**：`tiandihui.h` 的 `do_join` 第一句 `return notify_fail(...)`，后面逻辑永不执行
- **物品侧 `play`（11 次）另开通道**：`d/*/npc/obj/` 是物品目录，其 `add_action` 走物品通道，Kantele 侧目前没有 `actions` 入口
- **不要新建全局命令**：NPC 私有动词走 `NpcActionDispatcher`，不走 `Commands.call`（除非 handler 返回 `:not_handled`）
- **红区 additive-only（已获批，bi 已按此落地）**：条件致倒 `condition/down` → `DownHandlers` → `Bi.on_mai_down/on_yuan_down`，以及 过三拳反震 `die()`，均为**新增扩展点**，未重写 `eff_*`/`Vitals`/毒/昏迷内部、`Feature.Damage` 或 `CombatEvent.die`；若未来要碰昏迷/毒内核，先回退到此文档的红区约束

## 六、提交规范（本 repo）

- 原生 Elixir 1.20.4 / OTP 29（`C:\Program Files\Elixir\` + `C:\Program Files\Erlang OTP\`），不在 PATH，test 前先把 PATH 补上
- PowerShell 不会展开 `*`，`mix test` 要写**显式测试文件路径**，不要 `mix test test/kantele/world/npc_action*`
- 只 `git add` 明确路径，**不 `git add -A`**（工作区有大量 CRLF/diff 噪声及本会话无关修改）；提交用 `git commit -F <UTF-8 无 BOM 临时文件> <显式路径>`；信息前缀 `P5-1c-` / `P5-1c-N:`
- 源文件用 LF、UTF-8 无 BOM；`.md`/`docs` 用 CRLF，不要混

---

## 七、完成后

在本文件末尾追加实际做法摘要：
- 每个 verb 对应的 LPC 源文件路径与 `do_*` 函数名
- 新建的 handler 模块与测试文件
- 注册表新增条目（room_id → verb → {module, function}）
- 测试通过数与全量测试失败集对比（是否保持 75 基线）
- 供后续 session 继续下一个 verb

### 本次 bi 完成摘要（8db2abc9，2026-10-18）

- LPC 源：`d/tulong/tulong/npc/{chang,guo,mai,yuan}.c` → `do_bi`/`do_get`/`begin`/`guo`/`die`/`unconcious`
- 新建模块：`Kantele.World.NpcActions.Bi`、`NpcAttack`、`DownHandlers`（已存在）、`Kantele.Character.BiEvent`
- 新建测试：`test/kantele/world/npc_actions_bi_test.exs`
- 注册表新增：`tulong:huichang` / `tulong:huichang_back` → `bi`、`get` → `{Bi, :run}`
- 测试：本次相关 116/116 全通过；全量失败集保持基线 75（combat/web/user 预先失败），零 NPC 回归
- 设计要点：玩家进程广播 `$N`=玩家文案 / NPC 进程落 `anti`+condition+call_out；死亡文案经 `bi/result` 下发玩家进程按 `$N` 渲染（绕过 `broadcast_vision/4` 只认 `$N` 的限制）

---
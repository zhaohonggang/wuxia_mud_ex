# LPC 注册/转世流程迁移到 Elixir 端口（ExVenture/Kantele）的可行性分析

> ## 📌 归档声明 · 全库待办清零（2026-11-12）
>
> 本文件为**历史过程文档 / 阶段性快照**。文中出现的 `⬜` `⏸` `🟡` `🟠` `🔴` `⚠️` `[ ]`
> `TODO` `未做` `待办` `待确认` `不确定` `依赖` `阻塞` `后续` `留待` `暂缓` `推迟` `挂起`
> 等字样，**一律是撰写当时的状态快照，不代表当前待办**。
>
> 截至 2026-11-12 全库代码待办已清零：所有条目或已实现并回归通过，或已由用户决议不做 /
> 已证实不可实施 / 已定性为保真降级。**本文件不含任何剩余待办项**；复选框已统一按
> 「已结案」勾选（结案 = 已实现 / 已决议不做 / 已证实不可实施），原文保留作历史取证，无需排期。
>
> **唯一状态入口**：`.workbuddy-ai/memory/MEMORY.md` 与
> `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。本文件其余状态描述一律不再代表现状。


> 前置文档：[`LPC-新用户注册与转世重生机制分析.zh-CN.md`](./LPC-新用户注册与转世重生机制分析.zh-CN.md)
> 本文回答一个问题：**能否在 Elixir 端口里，像 LPC 那样以「游戏内问答」形式设置玩家属性/性别/人格，
> 而不改动网页注册页？** 并给出各项的迁移难度评估。
>
> **迁移状态**：✅ 已落地（见 `EX-注册与转世迁移计划.zh-CN.md`，Phase 0–3 全部完成；「游戏内问答设属性、网页注册页零改动」结论已验证）。

---

## 1. 结论先行

**可以，而且这是最自然的落点。** 理由：

1. **网页注册页只建「账号」，不碰角色属性。** `Web.RegistrationController.create` 调 `ExVenture.Users.create(params)`，
   模板字段仅 `username / email / password / password_confirmation`（`lib/web/templates/registration/new.html.eex`）。
   账号与角色是两张表（`users` → `playable_characters` → `characters`），网页注册只写 `users`。
2. **角色是「游戏内」创建的**，且引擎已内置问答机制。`LoginController.build_character`
   在登录时现场拼出 `%Character{... meta: %PlayerMeta{...}}`，登录流程本身就是一段
   `prompt` + `put_session` + `put_controller` 的状态机——这正是 LPC `input_to` 的等价物。
3. 因此「游戏内问答设属性」完全在引擎内闭环，**网页注册页零改动**即可实现。

---

## 2. Elixir 端口相关架构（已核实）

### 2.1 网页注册 = 账号层（不碰角色）
| 文件 | 作用 |
|---|---|
| `lib/web/controllers/registration_controller.ex:18` | `Users.create(params)` 仅建账号 |
| `lib/web/templates/registration/new.html.eex` | 字段：username/email/password/password_confirmation |
| `lib/ex_venture/users.ex:35-36` | `has_many(:characters, through: [:playable_characters, :character])`（关联存在，但 `create` 不自动建角色） |

### 2.2 游戏内登录 = 角色创建 + 问答状态机（LPC `logind.c` 的等价）
`lib/kantele/character/controllers/login_controller.ex`：
- `init`（20-25）：`prompt(LoginView, "name", %{})` 向客户端发问
- `recv`（41-52）：按 `get_session(conn, :login_state)` 做状态分支（`:username`→`:password`→`:character`）
- `process_character`（92-122）：`build_character()` 拼角色 → `Records.apply_to_character` → `put_character` → `move` → **`put_controller(CommandController)`**
- `build_character`（157-182）：角色初值写死默认：`stats: Stats.new()`、`vitals: Vitals.new()`、`coins: 100`，**未设 gender / character**

> 关键原语（来自 `Kalevala.Character.Controller`）：`prompt/4`、`put_controller/2`、
> `put_session/3`、`get_session/2`、`put_character/2`。这就是 LPC `input_to` 的框架级等价实现，
> 与传输层无关（WebSocket 客户端已在使用，见 `Kalevala.Websocket.Handler`）。

### 2.3 数据模型（属性/性别/人格的落点）
| LPC 概念 | Elixir 端口落点 | 位置 |
|---|---|---|
| `str/dex/con/int/per` 先天属性 | `Stats` 结构体字段 `str/dex/con/int`（默认 20）+ `reborn` 加成 map | `lib/kantele/character/stats.ex:9,43-60` |
| `gender` 性别 | `meta.env.gender` | `records.ex`（`set()` 类属性 → `meta.env`） |
| `character` 人格/天性 | `meta.character` | `PlayerMeta`（`character.ex` moduledoc） |
| 角色整体持久化 | `Kantele.Character.Records.save/1` | `lib/kantele/character/records.ex:147` |

---

## 3. 具体迁移映射与难度

### 3.1 新玩家「游戏内问答」设性别+属性（对应 LPC `logind.c` 的 `get_gender` + 属性初值）
**难度：低–中（约 1–2 天，含测试）**

实现方式（不动网页）：
1. 新增 `SetupController`（或就地扩展 `LoginController`）。
2. 在 `process_character` 末尾，对**首次登录**角色把 `put_controller(CommandController)`
   改为 `put_controller(SetupController)`：
   - `SetupController.init` → `prompt` 选性别（m/f），回写 `meta.env.gender`；
   - `recv` 状态机下一步 → `prompt` 分配属性点（或直接采用 LPC 默认
     `str/dex/con/int=14, per=20`，见 logind.c:698-702）；
   - 写回 `character.meta.stats` → `Records.save(character)` → `put_controller(CommandController)`。
3. **首登判定**：用 `meta.env.gender == nil` 或新增 `meta.setup_done` 标志区分新/老玩家。

可行性要点：引擎已有完整问答原语；数据字段（`env.gender` / `Stats`）已存在；
只需一段状态机 + 几张 prompt 模板 + 一次 `Records.save`。

### 3.2 转世重生（对应 LPC `updated.c` 的 `zhuan_player`）
**难度：中–高（约 3–5 天，含测试）**

实现方式：新增 `reborn` 命令（或管理员指令），按 `zhuan_player` 逻辑翻译：
- 设 `meta.character = "国士无双"`（updated.c:515）；
- 重置 `vitals` / `stats` / `marks` / `family` / `quest` / `env` 等记录；
- 删全部技能、`reborn/count += 1`、随机 `reborn.{str,con,int,dex} +1`；
- 赠转世特技；`Records.save` 持久化。

可行性要点：
- 数据模型**已全部就位**（`meta.character`、`Stats.reborn`、`vitals` 重置、技能删除接口），
  翻译多为机械搬运，无结构性障碍。
- **附带收益**：实现转世即解锁 4 个「包含门」技能（先天功/刀剑归真/三无三不手/五斗米神功）
  当前因 `meta.character` 不落盘、无赋值入口而不可学——转世补上 `meta.character` 赋值入口后，
  这 4 个技能即从「不可学」变为「转世后可学」，与 LPC 一致（见 `C-PVE27-valid_learn-长尾补全进度.zh-CN.md`）。
- 主要工作量在「清记录」要触及多个子系统（门派/任务/技能/marks），需逐个对接。

### 3.3 普通玩家「自选人格/天性」（对应 LPC 中**不存在**的能力）
**注意：这是新功能，不是迁移。** LPC 全库仅 NPC 注册 + 转世设 `character`，
普通玩家无任何设定入口（详见前置文档 §2.3）。因此：
- 若目标是「让普通玩家像选性别一样选天性」——属于**新增特性**，需自行设计可选值、UI、
  持久化与 `valid_learn` 读取（端口 `meta.character` 已能读，接入成本小）。
- 若目标是「 faithful 迁移」——**无需做**，因为 LPC 本就没有普通玩家设天性的路径。

---

## 4. 风险与前提

| 风险/前提 | 说明 | 缓解 |
|---|---|---|
| 首登 vs 老玩家判定 | 必须先区分，否则老玩家每次登录都重走问答 | `meta.env.gender == nil` 或 `setup_done` 标志 |
| 问答结果持久化 | 不 `Records.save` 则断线即丢 | SetupController 末步强制 `save` |
| Web 客户端渲染 | 问答状态机用于 WebSocket 行式客户端，需确认 prompt 在网页 MUD 客户端正常渲染 | `LoginController` 已同样在用，可直接复用 |
| 传输层 | 当前游玩走 WebSocket（Phoenix channel/socket），非传统 telnet；「游戏内」= 网页 MUD 客户端内 | 问答机制与传输无关；若要独立 telnet 服务端是另一层传输工作，不阻塞本任务 |
| 转世清记录覆盖面 | `zhuan_player` 删 40+ 类记录，逐子系统对接易漏 | 列清单逐条映射（可参考前置文档的行号索引） |

---

## 5. 推荐落地顺序

1. **先做 3.1（游戏内新玩家问答设性别+属性）**：改动小、风险低、完全不碰网页，
   且能立即验证「问答原语 + 持久化」闭环。
2. **再做 3.2（转世）**：顺带解锁 4 个包含门技能，闭合 known limitation。
3. **3.3（普通玩家自选天性）按需**：属新增特性，非迁移必需，建议单独立项。

---

## 6. 关键代码行号索引

| 文件:行 | 含义 |
|---|---|
| `lib/web/controllers/registration_controller.ex:18` | 网页注册仅 `Users.create`（账号层） |
| `lib/web/templates/registration/new.html.eex` | 网页字段仅 username/email/password |
| `login_controller.ex:20-25` | `init` → `prompt` 发问（input_to 等价） |
| `login_controller.ex:41-52` | `recv` 按 `login_state` 状态机 |
| `login_controller.ex:92-122` | `process_character` → `put_controller(CommandController)` |
| `login_controller.ex:157-182` | `build_character` 角色默认初值（无 gender/character） |
| `login_controller.ex:184-190` | `register_and_subscribe_character_channel` |
| `stats.ex:9,43-60` | `Stats`：`str/dex/con/int` + `reborn` 加成 |
| `records.ex:147` | `Records.save` 持久化（`meta` 含 character/env/vitals…） |
| `users.ex:35-36,163` | `Users` 账号 schema（含 characters 关联，`create` 不建角色） |

---

*参照：`LPC-新用户注册与转世重生机制分析.zh-CN.md`（LPC 侧）、
`C-PVE27-valid_learn-长尾补全进度.zh-CN.md`（valid_learn 性格门口径与 4 包含门技能结论）。*

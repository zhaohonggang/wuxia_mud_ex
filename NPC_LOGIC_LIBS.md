# NPC 纯逻辑库文档

> 这些模块为**纯函数库**，不持有状态、不直接落盘。NPC 行为由 UCL 数据（`goods`/`inquiries`/`coagents`/`guarder`/`kind` 等）驱动，宿主（命令/事件层）负责副作用（消息、落盘、状态更新）。

---

## 1. Kantele.Npc.Banker

> 对应 LPC `feature/banker.c`：银号存取汇兑纯逻辑

### 概念

- **扁平铜钱**：玩家身上钱唯一存量是 `meta.coins`（整数，铜钱数）
- **money_map**：面额枚数 `%{"gold" => g, "silver" => s, "coin" => c}`，由 `Money.split/1` 从扁平铜钱拆分
- **balance**：钱庄存款（铜钱数，存放于 `meta.bank_coins`）

### API

| 函数 | 签名 | 说明 |
|------|------|------|
| `check/1` | `check(balance) :: {:empty} \| {:balance, total}` | 查余额 |
| `convert/4` | `convert(money_map, amount, from, to) :: {:ok, new_map} \| {:error, reason}` | 面额兑换 |
| `deposit/4` | `deposit(money_map, balance, amount, what) :: {:ok, new_balance, new_map} \| {:error, reason}` | 存款 |
| `withdraw/4` | `withdraw(money_map, balance, amount, what) :: {:ok, new_balance, new_map} \| {:error, reason}` | 取款 |
| `transfer/3` | `transfer(balance, amount, what) :: {:ok, new_balance, value} \| {:error, reason}` | 转账 |

### 面额与 Money.normalize

- 面额：`gold=10000, silver=100, coin=1`
- `Money.normalize/1` 确保三面额键全存在（缺省 0），移除值为 0 的键

### 宿主职责（`Kantele.Character.BankCommand`）

1. `Money.split(meta.coins)` 得到 `money_map`
2. 调用 `Banker.xxx` 得到 `{:ok, new_balance, new_map}`
3. `Money.total_value(new_map)` 还原扁平铜钱 → 更新 `meta.coins`
4. `PlayerMeta.put_bank_coins(new_balance)` 更新存款
4. `Records.save(character)` 落盘
5. 渲染回复文案

---

## 2. Kantele.Npc.Master

> 对应 LPC `feature/master.c`：师门掌门/师父纯逻辑

### API

| 函数 | 签名 | 说明 |
|------|------|------|
| `prevent_learn?/3` | `prevent_learn?(my_family, me_family, asker_family) :: boolean` | 是否阻止学习：非嫡传但同门派 -> 阻止 |
| `attempt_detach/3` | `attempt_detach(my_family, asker_family, old_family) :: {:noop} \| {:detach, %{penalty?: bool}}` | 叛师处理决策 |

### 判定逻辑

- `prevent_learn?`：非本门嫡传（`!is_apprentice_of?`）且问者有门派且同门派 -> `true`（阻止）
- `attempt_detach`：若非我弟子 -> `{:noop}`；否则 `penalty? = old_family == nil or old_family != asker_family`，返回 `{:detach, %{penalty?: penalty?}}`

### 宿主职责（`Kantele.Character.DetachEvent`）

1. 接收 `family/detach-result` 事件
2. `penalty? == true`：降武功（各技能 -1 到最小 1）、清 `gongxian`
3. 清 `meta.family`，落盘
4. 渲染回复文案

---

## 3. Kantele.Npc.Quester

> 对应 LPC `feature/quester.c`：任务发布 NPC 纯逻辑

### API

| 函数 | 签名 | 说明 |
|------|------|------|
| `is_quester?/1` | `is_quester?(_self) :: true` | 任务 NPC 识别 |
| `ask_quest/2` | `ask_quest(self, who) :: {:ok, quest} \| {:error, reason}` | 请求任务，委托 `Kantele.Quest.ask_quest` |
| `cancel_quest/2` | `cancel_quest(self, who) :: {:ok, file} \| {:error, reason}` | 取消任务，委托 `Kantele.Quest.cancel_quest` |

### 宿主职责（`NpcShopEvent.detach/ask_quest/cancel_quest`）

1. `NpcAskEvent` 接收玩家 `quest/ask` / `quest/cancel` 事件
2. 解析目标 NPC，调用 `Quester.ask_quest/cancel_quest`
3. 返回 `quest/ask-result` / `quest/cancel-result` 事件给玩家进程

### 任务数据来源

- NPC `meta.quest`：`%{file: "quest_x", ...}` 任务规格
- `Kantele.Quest` 服务处理进度、前置链、互斥、里程碑奖励

---

## 4. Kantele.NPC.Horseboss

> 对应 LPC `horseboss.c`：马夫 NPC 售卖坐骑完整流程

### 物种配置

19 种坐骑，各含：`name`（中文名）、`suffix`（召唤 ID 后缀）、`unit`（量词）、`base`（基础属性 str/con/dex/int）

### 流程（多步向导）

| 步骤 | 函数 | 参数 | 临时状态 |
|------|------|------|----------|
| 1. 问候 | `greet/2` | `(npc, player)` | — |
| 2. 选物种 | `start_purchase/3` | `(npc, player, species_key)` | `chosen_species` |
| 3. 选性别 | `choose_gender/3` | `(npc, player, gender)` | `pet_gender` |
| 4. 选 ID | `choose_id/3` | `(npc, player, id)` | `pet_id` |
| 5. 选名字 | `choose_name/3` | `(npc, player, name)` | `pet_name` |
| 6. 选描述/完成 | `choose_desc/3` | `(npc, player, desc)` | 清理 temp |
| 取消 | `cancel/2` | `(npc, player)` | 清理 temp |

### 临时状态键

| 键 | 含义 |
|------|------|
| `chosen_species` | 已选物种 atom |
| `pet_gender` | `"male" \| "female"` |
| `pet_id` | 召唤 ID（小写字母/下划线，3-20 字符） |
| `pet_name` | 中文名（2-12 个汉字） |
| `pet_desc` | 描述（可选，≤60 字） |

### 价格与需求

- 售价：100 金 = 1,000,000 铜币（`@price`）
- 训练技能要求：≥ 30 级（`@training_req`）

### 最终生成

1. `full_id = base_id <> "_" <> species_suffix`
2. 属性随机：`base_attr + rand(-10..10)`，最小 1
2. `Kantele.Mount.create_mount/1` 生成模板
3. `Kantele.Mount.give_mount/2` 生成实例并加入背包
4. 清理临时状态，返回成功文案

### 识别接口

```elixir
def is_horseboss?(%{meta: %{kind: "horseboss"}}), do: true
def is_horseboss?(%{meta: %{horseboss: true}}), do: true
def is_horseboss?(_), do: false
```

---

## 宿主调用方式统一

| 模块 | 调用方 | 典型调用链 |
|------|--------|------------|
| `Banker` | `BankCommand` | 命令解析 → `Banker.xxx` → 更新 meta/coins/bank_coins → `Records.save` |
| `Master` | `DetachEvent` | `family/detach` → `Master.attempt_detach` → `family/detach-result` → 玩家侧执行惩罚 |
| `Quester` | `NpcAskEvent` | `quest/ask` / `quest/cancel` → `Quester.ask_quest/cancel_quest` → `quest/ask-result` / `cancel-result` |
| `Horseboss` | `HorseCommand` | `horse <npc> ...` 多步 → `Horseboss.xxx` 更新 temp → `choose_desc` 完成 → `Mount.give_mount` |

---

## 设计原则

1. **纯函数**：无副作用、可测试、返回 `{:ok, ...} \| {:error, reason}`
2. **无状态**：不持有 GenServer 状态，所有状态在 `meta.temp` / `meta` 传递
3. **宿主负责副作用**：消息发送、落盘、状态更新、消息渲染
4. **数据驱动**：NPC 行为由 UCL 配置（`goods`/`inquiries`/`coagents`/`guarder`/`kind`/`quest`/`teach`/`turn_in` 等）决定
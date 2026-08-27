# class_wudang_zhang 框架能力需求文档

本文档记录 `class_wudang_zhang` 样本完整迁移所需的框架级能力扩展。
当前迁移产物为纯函数实现 (`class_wudang_zhang.ex`)，无副作用，需框架提供以下能力方可在游戏中真正运行。

---

## 1. 可执行问询系统

### 现状
- UCL `inquiries` 仅支持 `keyword -> 静态字符串` 映射
- 无法执行条件判断、状态变更、物品给予

### 需求
扩展 `Room.AskRequestEvent` 或引入 `Npc.AskHandler` 行为协议：

```elixir
# 建议接口
defmodule ExKantele.Behaviour.AskHandler do
  @callback can_handle(player :: Player.t(), keyword :: String.t()) :: boolean()
  @callback check(player :: Player.t(), keyword :: String.t()) :: {:ok, effects :: [Effect.t()]} | {:error, String.t()}
  @callback execute(player :: Player.t(), keyword :: String.t(), effects :: [Effect.t()]) :: {:ok, String.t()} | {:error, String.t()}
end
```

### Effect 类型
```elixir
%{type: :set_perform, key: "taiji-quan/zhen", value: true}
%{type: :add_gongxian, delta: -800}
%{type: :improve_skill, skill: "taiji-quan", exp: 1_500_000}
%{type: :add_learned_points, delta: 100}
%{type: :set_flag, key: "can_learn/jiuyang-shengong/wudang", value: true}
%{type: :give_item, item_id: "zhenwu_jian", unique_check: true}
%{type: :unlock_skill, skill: "wudang-jiuyang"}
%{type: :recruit, family: "武当派", generation: 2}
%{type: :message, text: "..."}
```

### 问询流程
1. 玩家输入 `ask zhang about 鹤嘴劲`
2. 框架查找 NPC 注册的 `AskHandler`
3. 调用 `check/2` → 返回 effects 或拒绝原因
4. 若通过，调用 `execute/3` → 应用 effects，返回最终文本
5. 文本发送给玩家

---

## 2. 玩家 Perform/绝技 标记持久化

### 现状
- 玩家数据模型无 `performs` / `can_perform` 字段
- 无技能绝技解锁记录

### 需求
在 `Player` schema 增加：
```elixir
# 格式: "skill_name/perform_name" => true
field :performs, :map, default: %{}
# 或嵌入结构
field :can_perform, :map, default: %{
  "taiji-quan" => %{"zhen" => true, "yin" => false}
}
```

### 使用场景
- `handle_ask` 返回 `set_perform` effect 时写入
- `Skill.can_perform?/2` 查询
- `CombatEngine` 验证 perform 前置条件

---

## 3. 唯一物品实例注册与追踪

### 现状
- 物品仅有模板，无实例身份
- 无法实现「真武剑在谁手中」「环境中是否存在」查询

### 需求
引入 `Item.Registry` (GenServer/ETS)：

```elixir
defmodule ExKantele.Item.Registry do
  # 注册唯一物品实例
  @spec register_unique(item_id :: String.t(), template_id :: String.t(), owner :: Player.t() | nil, location :: String.t()) :: {:ok, Instance.t()} | {:error, :already_exists}

  # 查找唯一物品当前持有者/位置
  @spec locate_unique(item_id :: String.t()) :: {:ok, %{holder: Player.t() | nil, location: String.t(), instance: Instance.t()}} | :not_found

  # 转移所有权
  @spec transfer_unique(item_id :: String.t(), from :: Player.t() | nil, to :: Player.t() | String.t()) :: :ok | {:error, :not_found}

  # 销毁实例
  @spec destroy_unique(item_id :: String.t()) :: :ok
end
```

### 使用场景
- `ask_jian` 给予真武剑前：`locate_unique("zhenwu_jian")` 检查是否已存在、在谁手中
- 玩家下线/销毁/重置时自动清理
- `accept_object` 回收真武剑时：`destroy_unique/1`

---

## 4. 技能学习守门钩子

### 现状
- `Skill.learn/2` 无前置条件检查点
- `recognize_apprentice` 逻辑无处挂载

### 需求
在 `Skill` 行为增加回调：

```elixir
defmodule ExKantele.Behaviour.Skill do
  @callback can_learn?(player :: Player.t(), teacher :: Npc.t() | nil) :: {:ok, :allowed} | {:error, String.t()}
  @callback on_learn(player :: Player.t(), teacher :: Npc.t() | nil, from_level :: integer(), to_level :: integer()) :: :ok
end
```

### 使用场景
- `wudang-jiuyang` 实现 `can_learn?` 检查 `can_learn/jiuyang-shengong/wudang` 标记
- 师父 NPC 通过 `teacher` 参数验证传承关系
- 非师父传授、未解锁、邪派(shen<0) 均拦截

---

## 5. NPC 战斗 AI 系统

### 现状
- `chat_chance_combat` / `chat_msg_combat` 仅为数据字段
- 战斗引擎不解析、不执行

### 需求
`CombatEngine` 在每回合调用 NPC AI：

```elixir
defmodule ExKantele.Combat.AI do
  @spec decide_action(npc :: Npc.t(), target :: Character.t(), context :: map()) ::
    {:perform, skill_action :: String.t()} | {:exert, function :: String.t()} | :idle
end
```

### 解析规则
- `perform_action:sword.chan` → `{:perform, "sword.chan"}`
- `exert_function:recover` → `{:exert, "recover"}`
- 支持权重/条件：`chat_chance_combat` 控制触发概率

### 使用场景
- 张三丰 120% 概率每回合从 16 个动作中随机选择
- 通用化：所有 NPC 可定义 combat AI 表

---

## 6. 玩家 Gongxian (门派贡献) 系统

### 现状
- 玩家无 `gongxian` 字段
- 无门派贡献增减接口

### 需求
```elixir
# Player schema
field :gongxian, :integer, default: 0

# Family 模块
defmodule ExKantele.Family do
  def add_gongxian(player, delta) :: {:ok, new_value} | {:error, :not_in_family}
  def spend_gongxian(player, cost) :: {:ok, new_value} | {:error, :insufficient}
end
```

### 使用场景
- 绝技传授扣除 gongxian
- 师门任务奖励 gongxian
- `attempt_apprentice` 可检查 gongxian 门槛

---

## 7. 玩家 Shen (正气/阴气) 系统

### 现状
- `Player` 已有 `shen` 字段但无语义常量

### 需求
定义阈值常量与查询函数：

```elixir
defmodule ExKantele.Alignment do
  @good_threshold 500
  @evil_threshold -500

  def good?(shen), do: shen > @good_threshold
  def evil?(shen), do: shen < @evil_threshold
  def neutral?(shen), do: shen >= @evil_threshold and shen <= @good_threshold
  def title(shen) do
    cond do
      shen > 10000 -> "大侠"
      shen > 5000 -> "侠士"
      shen > 500 -> "良善"
      shen > -500 -> "普通"
      shen > -5000 -> "恶徒"
      shen > -10000 -> "巨恶"
      true -> "魔头"
    end
  end
end
```

### 使用场景
- 问询/收徒/真武剑给予的 `shen >= X` 判定
- `Alignment.title/1` 生成称谓

---

## 8. 多阶段绝技传授 (太极图模式)

### 现状
- 单次问询即授技，无进度累积

### 需求
支持 `multi_stage: true` 的 perform：

```elixir
%{
  type: :grant,
  perform: "taiji-quan/tu",
  stages: 10,           # 需触发 10 次
  per_stage: [
    message: "你对太极图有了一点领悟。",
    add_learned_points: 100
  ],
  on_complete: [
    message: "你学会了道家密技「太极图」。",
    set_perform: "taiji-quan/tu",
    improve_skills: [...],
    add_gongxian: -3000
  ]
}
```

### 实现
- `Player.flags["perform_progress/taiji-quan/tu"]` 记录当前阶段
- 每次 `ask` 通过检查后递增，达标触发 `on_complete`

---

## 9. 条件式物品给予

### 现状
- `give_item` 无条件执行

### 需求
```elixir
%{
  type: :conditional_give,
  item_id: "zhenwu_jian",
  fallback_item: "changjian",
  conditions: %{
    unique_item_check: true,              # 唯一物品注册表中不存在
    current_owner_not_player: true,       # 当前持有者不是玩家本人
    current_owner_not_my_disciple: true   # 当前持有者不是我的弟子
  }
}
```

### 执行逻辑
1. `Registry.locate_unique(item_id)` 获取当前状态
2. 逐项验证 conditions
3. 全满足 → 创建实例给玩家，注册表登记
4. 任一不满足 → 给予 fallback_item + 提示信息

---

## 10. 玩家 Learned Points (潜能/已学点数) 系统

### 现状
- 无 `learned_points` / `potential` 双轨制

### 需求
```elixir
# Player schema
field :learned_points, :integer, default: 0
field :potential_limit, :integer, default: 10000

# 接口
defmodule ExKantele.Player do
  def can_afford_learned_points(player, cost) :: boolean()
  def spend_learned_points(player, cost) :: {:ok, new_value} | {:error, :insufficient}
end
```

### 使用场景
- 太极图第 1 阶段扣除 100 learned_points
- `valid_learn` 检查潜能上限

---

## 11. NPC 不可被击倒

### 现状
- `unconcious` 回调无标准扩展点

### 需求
```elixir
defmodule ExKantele.Behaviour.Character do
  @callback on_unconcious(character :: Character.t(), killer :: Character.t() | nil) ::
    {:override, :die | :revive | :ignore} | {:continue, effects :: [Effect.t()]}
end
```

### 使用场景
- 张三丰 `unconcious -> die()` (原文件直接调用 die)
- 其他 NPC 可自定义：原地复活、逃跑、触发剧情

---

## 12. 师门/门派关系查询

### 现状
- `Player.family` 仅存基础信息
- 无「我的弟子」「我的师父」「同门」查询

### 需求
```elixir
defmodule ExKantele.Family do
  def my_disciples(player) :: [Player.t()]
  def my_master(player) :: Player.t() | nil
  def fellow_disciples(player) :: [Player.t()]
  def is_disciple_of?(player, master_id) :: boolean()
end
```

### 使用场景
- `ask_jian` 检查「当前持有者是否我的弟子」
- `recognize_apprentice` 验证传承链
- 师门任务、师门贡献统计

---

## 实现优先级建议

| 优先级 | 能力 | 影响样本 | 复杂度 |
|--------|------|----------|--------|
| P0 | 可执行问询系统 | 所有带逻辑 NPC | 高 |
| P0 | Perform 持久化 | 所有绝技传授 NPC | 中 |
| P1 | 唯一物品注册表 | zhenwu_jian, 任务唯一物品 | 高 |
| P1 | 技能学习守门 | wudang-jiuyang 等限制技能 | 中 |
| P2 | 战斗 AI 执行 | 所有 chat_msg_combat NPC | 高 |
| P2 | Gongxian/Shen 系统 | 门派 NPC | 低 |
| P3 | 多阶段绝技 | 太极图等 | 中 |
| P3 | 条件式给物 | 真武剑类 | 中 |
| P4 | Learned Points | 太极图等 | 低 |
| P4 | 不可击倒钩子 | 张三丰等 | 低 |
| P5 | 师门关系查询 | 门派管理 | 中 |

---

## 迁移产物清单

```
class_wudang_zhang/
├── zhang_sanfeng.ucl      # 完整 NPC 数据 (46 技能、属性、装备、战斗AI表)
├── class_wudang_zhang.ex  # 纯函数行为模块 (13问询+收徒+接物+战斗AI+九阳+真武剑)
├── zhenwu_jian.ucl        # 真武剑唯一物品模板
└── FRAMEWORK_REQUIREMENTS.md  # 本文档
```

所有 `.ex` 函数为**纯函数**，输入 `Player.t()` + 参数，返回 `{:ok, effects}` 或 `{:error, reason}`，无副作用，便于测试与框架集成。
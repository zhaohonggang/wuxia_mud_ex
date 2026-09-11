# API 参考手册 — Kantele 核心模块

> 面向开发者的快速查阅：核心模块、公开 API、事件契约、数据结构。

---

## 1. 世界与加载

### `Kantele.World.Loader`
```elixir
# 加载所有 world 数据 (UCL 文件)
@spec load() :: Kantele.World.t()

# 解析单个 UCL 文件
@spec load_data_file(path :: String.t(), zone_id :: String.t()) :: {:ok, term()} | {:error, Kantele.World.LoaderError}
```

### `Kantele.World` (GenServer/Supervisor)
```elixir
# 启动世界监督树
@spec start_link(opts :: Keyword.t()) :: Supervisor.on_start()

# 房间 flag 查询
@spec room_flags(room_id :: String.t()) :: [String.t()]

# 出生点房间
@spec start_room_id() :: String.t()
```

### `Kantele.World.ZoneCache`
```elixir
# 获取区域数据
@spec get(zone_id :: String.t()) :: {:ok, Kalevala.World.Zone.t()} | {:error, :not_found}

# 获取所有区域 ID
@spec keys() :: [String.t()]
```

---

## 2. 任务系统

### `Kantele.Quest` (纯函数状态机)
```elixir
@spec new() :: %{}  # %{todo: %{}, solved: [], quest_count: 0}

@spec set_todo(state, spec, opts \\ []) :: {:ok, state} | {:error, reason}
@spec del_todo(state, quest_file) :: state
@spec set_solved(state, spec) :: {:ok, state} | {:error, :invalid}
@spec del_solved(state, quest_file) :: state

@spec chain_open?(state, spec) :: boolean()
@spec mutex_open?(state, spec) :: boolean()
@spec repeatable?(spec) :: boolean()
@spec is_solved(state, spec) :: boolean()

@spec check_timeout(state, now \\ :os.system_time(:second)) :: [{quest_file, task}]
@spec cancel_with_penalty(state, spec) :: {:ok, state} | {:error, :not_found}

# 序列化/反序列化
@spec serialize(state) :: map()
@spec deserialize(data) :: state
```

**Quest Spec 结构:**
```elixir
%{
  file: "quest_id",           # 必填
  type: "chain" | "kill" | "item" | "deliver" | "supply" | "search" | "explore",
  chain: ["pre1", "pre2"],    # 前置任务列表
  mutex: ["mutex1"],          # 互斥任务
  repeatable: false,          # 是否可重复
  limit: 1800,                # 时限秒数 (0=无限制)
  level: 1,                   # 任务等级
  master_name: "NPC名",       # 发布者
  master_id: "zone:npc",      # 发布者 ID
  kill: ["monster_id"],       # 击杀目标
  item: ["item_id"],          # 送物目标
  reward: %{...}              # 奖励配置
}
```

### `Kantele.Character.Events.QuestEvent`
**事件主题:**
- `quest/ask-result` — 玩家请求任务结果
- `quest/turnin-request` — 玩家交付物品请求
- `quest/report` — 玩家汇报击杀进度
- `quest/cancel-result` — 取消任务结果

**数据结构:**
```elixir
# ask-result
%{ok: true, npc_name: "周不通", quest: %{file: "xxx", ...}}
%{ok: false, reason: :chain_blocked, npc_name: "周不通"}

# turnin-request
%{vendor_name: "阿婆", quest: "song-yupai", item_id: "liuxi:yupai", ...}
```

---

## 3. NPC 与交互

### `Kantele.Character.Events.NpcAskEvent`
**处理流程:**
1. `find_answer(inquiries, keyword)` — 包含匹配
2. 答语类型分发:
   - 文本 → `publish_tell`
   - map (脚本化) → `handle_scripted_answer` → 发 `npc/give`/`npc/learn`/`npc/faction`/`npc/register_summon`
   - atom → `handle_special_answer` (如子虚道人)
3. `turn_in` → `quest/turnin-request`
4. `quest` → `Quester.ask_quest/cancel_quest`
5. `quest_daemon` → 开放任务分发

**脚本化问询 map 字段:**
```elixir
%{
  "reply" => "文案",           # 必填，回话文本
  "give" => "item_id",         # 给物品
  "learn_skill" => "skill_id", # 传授技能
  "family" => "门派名",         # 拜师
  "gongxian" => 10,            # 贡献度
  "register_summon" => true    # 登记召唤
}
```

### `Kantele.Character.Events.NpcScriptEvent` (玩家侧)
```elixir
# npc/give — 给物品入包
def give_result(conn, %{data: %{npc_name, item_id, asker_id}})

# npc/learn — 学会技能 (首学 1 级)
def learn_result(conn, %{data: %{npc_name, skill, asker_id}})

# npc/faction — 拜入门派 + 贡献
def faction_result(conn, %{data: %{npc_name, family, gongxian, asker_id}})

# npc/register_summon — 登记召唤 (新)
def register_result(conn, %{data: %{npc_name, item_id, asker_id, keyword}})
```

---

## 4. 战斗系统

### `Kantele.Character.Combat`
```elixir
@spec new() :: %Combat{}

@spec receive_damage(character, type :: :qi | :jing | :neili, amount) ::
  {:ok, character} | {:error, :dead}

@spec add_killed(state, spec, killed_file, amount) :: state
@spec get_killed(state, spec, killed_file) :: integer()
```

### `Kantele.Character.Events.CombatEvent`
**事件:** `combat/attack`, `combat/skill`, `combat/die`, `combat/damage`

---

## 5. 物品与背包

### `Kantele.World.Items` (Kalevala.Cache)
```elixir
@spec put(id :: String.t(), item :: Kalevala.World.Item.t()) :: :ok
@spec get(id :: String.t()) :: {:ok, Kalevala.World.Item.t()} | {:error, :not_found}
@spec get!(id) :: Kalevala.World.Item.t()
@spec keys() :: [String.t()]
```

### `Kantele.World.Item.Instance`
```elixir
%{
  id: "unique_instance_id",
  item_id: "zone:item_key",
  created_at: DateTime.t()
}
```

---

## 6. 核心守护进程

### `Kantele.World.MirrorDaemon` (宝镜任务)
```elixir
@impl Behaviour
def start_round(state, opts \\ []) :: {:ok, state} | {:error, :round_already_active}

def stop_round(state) :: {:ok, state}
def status(state) :: %{
  round_number: integer(),
  round_active: boolean(),
  tasks_alive: integer(),
  total_completed: integer(),
  all_completed: boolean()
}

def on_task_completed(server \\ __MODULE__, task_name, player) :: :ok
```

**关键字段:**
- `spawn_queue` — 待生成任务队列 (异步模式)
- `sync: true` — 测试同步模式，立即全部生成

### `Kantele.World.Story` (剧情叙事)
```elixir
@impl Behaviour
def prompt() :: String.t()
def init_state() :: map()
def start_story(state, opts \\ []) :: {:ok, state} | {:error, reason}
def stop_story(state) :: {:ok, state}
def tick(state) :: {:ok, state} | {:error, reason}
```

### `Kantele.World.Invasion` (入侵事件)
```elixir
@impl Behaviour
def start_wave(state) :: {:ok, state} | {:error, reason}
def stop_wave(state) :: {:ok, state}
def status(state) :: %{
  current_wave: integer(),
  wave_active: boolean(),
  total_killed: integer(),
  record: map()
}
```

---

## 7. 事件总线契约

### 核心主题
| 主题 | 发送方 | 接收方 | 说明 |
|------|--------|--------|------|
| `npc/give` | NpcAskEvent | NpcScriptEvent | 给物品 |
| `npc/learn` | NpcAskEvent | NpcScriptEvent | 学技能 |
| `npc/faction` | NpcAskEvent | NpcScriptEvent | 拜师 |
| `npc/register_summon` | NpcAskEvent | NpcScriptEvent | 登记召唤 |
| `quest/turnin-request` | NpcAskEvent | QuestEvent | 交付物品 |
| `quest/ask-result` | QuestEvent | 玩家 | 接任务结果 |
| `quest/report` | 玩家 | QuestEvent | 汇报击杀 |
| `combat/attack` | 玩家 | CombatEvent | 发起攻击 |
| `room/look` | 玩家 | Room | 查看房间 |
| `waidi` | Daemon | Channel | 入侵/宝镜广播 |

### 通用事件结构
```elixir
%Kalevala.Event{
  topic: "topic/name",
  data: %{
    # 业务字段...
  },
  from_pid: pid(),
  acting_character: character()
}
```

---

## 8. 常用工具函数

### `Kantele.Character.Records`
```elixir
@spec save(character :: Kalevala.Character.t()) :: :ok | {:error, reason}
```

### `Kantele.Character.PlayerMeta`
```elixir
@spec quests(meta) :: map()
@spec put_quests(meta, quests) :: meta
@spec stats(meta) :: Kantele.Character.Stats.t()
```

### `Kantele.Communication`
```elixir
@spec announce(channel, text) :: :ok | {:error, reason}
@spec publish(channel, event, subscribers) :: :ok | {:error, reason}
@spec subscribe(channel, pid, opts \\ []) :: :ok | {:error, reason}
@spec subscribers(channel) :: [{pid, options}]
```

### `Kantele.World.Room`
```elixir
@spec start_room(room, item_instances, config) :: {:ok, pid} | {:error, reason}
@spec global_name(room) :: {:global, {module, room_id}}
```

---

## 9. 常见错误码

| 原子 | 含义 | 来源 |
|------|------|------|
| `:chain_blocked` | 前置任务未完成 | Quest.set_todo |
| `:mutex_blocked` | 互斥任务进行中 | Quest.set_todo |
| `:full` | 任务列表已满 (默认 20) | Quest.set_todo |
| `:duplicate` | 已在进行中 | Quest.set_todo |
| `:done` | 已完成且不可重复 | Quest.set_todo |
| `:invalid` | 非有效任务 spec | Quest.set_todo |
| `:round_already_active` | 轮次已在进行 | MirrorDaemon.start_round |

---

## 10. 测试工具

### `Kalevala.ConnTest`
```elixir
def build_conn(character \\ default_player())
def assert_receive(pattern, timeout \\ 1000)
def refute_receive(pattern, timeout \\ 1000)
```

### `Kantele.Quest` 测试辅助
```elixir
defp complete(state, %{file: file}) do
  {:ok, s} = Quest.set_solved(state, %{file: file})
  s |> Quest.del_todo(file) |> Quest.bump_quest_count()
end
```

---

*文档版本: 2026-09-11 | 对应代码版本: kalevala 分支 HEAD*
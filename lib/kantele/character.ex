defmodule Kantele.Character.PlayerMeta do
  @moduledoc """
  Specific metadata for a character in Kantele

  - `coins` 铜钱（A10/N2 货币；运行态在 meta，落盘 character_metadata.coins）
  - `family` 师徒/门派 `%{name: "柳溪派", master_id: ..., master_name: ...}`（A11/N5 v0）
  - `wimpy` 自动逃跑阈值（0-80，0 关闭；cmds/usr/wimpy.c）
  - `leader` 跟随对象 `%{id, name, pid}`（cmds/std/follow.c；运行态）
  - `followers` 跟随者列表 `[%{id, name, pid}]`（运行态，不落盘）
  - `nickname` 昵称（cmds/usr/nick.c；落盘 metadata.nickname）
  - `title` 玩家头衔（cmds/usr/title.c 玩家展示层；落盘）
  - `option` 界面选项位图 `%{"brief_room" => 1, ...}`（cmds/usr/option.c；落盘）
  - `alias_commands` 自定义别名 `%{"sc" => "score", ...}`（cmds/usr/alias.c；落盘）
  - `team` 队伍 `%{id, leader_pid, members: [%{id, name, pid}]}`（cmds/std/team.c；运行态）
  - `riding` 座骑（运行态）：`%{instance_id, item_id, name}` 或缺省 nil（cmds/std/ride.c）
  """

  defstruct [
    :reply_to,
    :vitals,
    :stats,
    :combat,
    :coins,
    :family,
    :wimpy,
    :leader,
    :nickname,
    :title,
    :option,
    :alias_commands,
    :team,
    :riding,
    :team_pending,
    temp: %{},
    followers: [],
    damage: %{},
    attack_killer: [],
    attack_want_kills: [],
    attack_enemy: [],
    attack_next_action: nil,
    attack_default_object: nil,
    attack_default_function: nil,
    attack_competitor: nil,
    override: %{},
    quests: nil,
    bank_coins: nil
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:vitals])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end

  # ---- damage 状态（会话级，对应 LPC F_DAMAGE，不落盘、不进房间视图）----
  @doc "伤害追踪状态：last_damage_from/name, defeated_by/who, ghost, defeat_player[]"
  def damage_state(%__MODULE__{damage: dmg}), do: dmg

  def put_damage(%__MODULE__{} = meta, dmg), do: %{meta | damage: dmg}

  def update_damage(%__MODULE__{} = meta, fun) do
    %{meta | damage: fun.(meta.damage || %{})}
  end

  # ---- attack 状态（会话级，对应 LPC F_ATTACK，不落盘、不进房间视图）----
  @doc "攻击/仇恨状态：killer/want_kills/enemy/next_action/competitor"
  def attack_state(%__MODULE__{
        attack_killer: killer,
        attack_want_kills: want_kills,
        attack_enemy: enemy,
        attack_next_action: next_action,
        attack_default_object: default_object,
        attack_default_function: default_function,
        attack_competitor: competitor
      }) do
    %{
      killer: killer,
      want_kills: want_kills,
      enemy: enemy,
      next_action: next_action,
      default_object: default_object,
      default_function: default_function,
      competitor: competitor
    }
  end

  def put_attack(%__MODULE__{} = meta, attack) do
    %{meta |
      attack_killer: attack.killer || [],
      attack_want_kills: attack.want_kills || [],
      attack_enemy: attack.enemy || [],
      attack_next_action: attack.next_action,
      attack_default_object: attack.default_object,
      attack_default_function: attack.default_function,
      attack_competitor: attack.competitor
    }
  end

  def update_attack(%__MODULE__{} = meta, fun) do
    current = attack_state(meta)
    new_attack = fun.(current)
    put_attack(meta, new_attack)
  end

  # ---- override 钩子注册表（对应 LPC F_ACTION set_override/run_override）----
  #
  # 存放于 `meta.override`，为**会话级**运行态（不落盘、不进房间视图）。
  # 用途：玩家 unconsious/die/win/lost 等钩子被 NPC/物品临时覆盖（如张三丰
  # 的"不可击倒"）。`run_override/2` 取走并删除该钩子，返回是否执行过。
  #
  # 与原版返回 `(*fun)(this_object())` 不同，本框架以纯数据方式记录"钩子存在性"，
  # 由宿主组件决定执行内容。

  @doc "读所有 override"
  def override(%__MODULE__{override: o}), do: o

  @doc "注册一个 override 钩子（覆盖同名）"
  def set_override(%__MODULE__{} = meta, index, marker),
    do: %{meta | override: Map.put(meta.override, index, marker)}

  @doc "查询某个 override 是否存在"
  def query_override(%__MODULE__{override: o}, index), do: Map.get(o, index)

  @doc "执行并移除一个 override 钩子；返回 {是否存在, 剔除后的 meta}"
  def run_override(%__MODULE__{} = meta, index) do
    case Map.pop(meta.override, index) do
      {nil, _} -> {false, meta}
      {marker, rest} -> {marker, %{meta | override: rest}}
    end
  end

  @doc "删除一个 override 钩子"
  def delete_override(%__MODULE__{} = meta, index),
    do: %{meta | override: Map.delete(meta.override, index)}

  # ---- temp 存储（对应 LPC get_temp/put_temp/delete_temp）----
  #
  # 存放于 `meta.temp`，为**会话级**运行态：不落盘（Records.save 不写 temp）、
  # 不进房间视图（Trim 只保留 :vitals）。用途：冷却时间戳、炼制/向导进度、
  # attempt_hit 计数、rent_paid 等一次性/会话数据。

  @doc "取临时值（LPC get_temp/2）；缺省返回 nil"
  def get_temp(%__MODULE__{temp: temp}, key), do: Map.get(temp, key)

  @doc "取临时值，缺省返回给定默认值"
  def get_temp(%__MODULE__{temp: temp}, key, default), do: Map.get(temp, key, default)

  @doc "写临时值（LPC set_temp/put_temp/3）"
  def put_temp(%__MODULE__{} = meta, key, value),
    do: %{meta | temp: Map.put(meta.temp, key, value)}

  @doc "临时数值自增（LPC add_temp/3，缺省按 0 起步累加）"
  def add_temp(%__MODULE__{} = meta, key, delta \\ 1) do
    %{meta | temp: Map.update(meta.temp, key, delta, &(&1 + delta))}
  end

  @doc "删除临时值（LPC delete_temp/2）"
  def delete_temp(%__MODULE__{} = meta, key),
    do: %{meta | temp: Map.delete(meta.temp, key)}

  # ---- quest 进度（运行态，Kantele.Quest 状态；nil 懒初始化）----
  @doc "任务进度状态（缺省按空 Kantele.Quest 兜底）"
  def quests(%__MODULE__{} = meta) do
    meta.quests || Kantele.Quest.new()
  end

  @doc "写任务进度状态"
  def put_quests(%__MODULE__{} = meta, quest_state),
    do: %{meta | quests: quest_state}

  # ---- 钱庄存款（运行态，banker.c 充裕余额；nil 懒初始化 0，暂不落盘）----
  @doc "钱庄存款（铜钱；缺省 0）"
  def bank_coins(%__MODULE__{} = meta) do
    meta.bank_coins || 0
  end

  @doc "写钱庄存款（铜钱）"
  def put_bank_coins(%__MODULE__{} = meta, value),
    do: %{meta | bank_coins: value}
end

defmodule Kantele.Character.NonPlayerMeta do
  @moduledoc """
  Specific metadata for a world character in Kantele

  - `goods` 出售商品 item id 列表（A10/N2 商店；nil = 非商人）
  - `inquiries` 问答表 `%{关键词 => 回答}`（A10/N4；nil = 无问答）
  - `teach` 教学配置（A11/D4）：`%{family: 门派名, teach_skills: %{技能 => %{max: 上限,
    gongxian: 价目}}, no_teach: [...]}`；本期只解析落位供展示，消费端等 b 期 learn 重构
  - `turn_in` 任务交付（A11/N6 v0）：`%{quest: id, item: item_id, prompt: 引导文案,
    rumor: 播报文案, rewards: %{exp:, potential:, score:, weiwang:, coins:}}`
   - `loot` 击杀掉落 item id 列表（A11/N6：黑虎掉玉牌）
   - `quest` 任务发布规格（A11/N6 v1）：`%{file:, kill:[], item:[]}`
   - `coagents` 帮手列表（coagent.c）：`[coagent_id]`，受击时通知这些帮手前来助战
  """

  defstruct [
    :initial_events,
    :vitals,
    :zone_id,
    :stats,
    :combat_config,
    :combat,
    :goods,
    :inquiries,
    :teach,
    :turn_in,
    :loot,
    :quest,
    :coagents
  ]

  defimpl Kalevala.Meta.Trim do
    def trim(meta) do
      Map.take(meta, [:vitals])
    end
  end

  defimpl Kalevala.Meta.Access do
    def get(meta, key), do: Map.get(meta, key)

    def put(meta, key, value), do: Map.put(meta, key, value)
  end
end

defmodule Kantele.Character.NPCConfig do
  @moduledoc """
  NPC 战斗相关的静态配置，由世界数据 `.ucl` 的 `combat` 块解析而来
  """

  defstruct [
    :attitude,
    :spawn_room_id,
    :respawn_delay,
    no_kill: false,
    apply: %{}
  ]

  def new(), do: %__MODULE__{apply: %{}, attitude: nil, no_kill: false, spawn_room_id: nil, respawn_delay: nil}
end

defmodule Kantele.Character.InitialEvent do
  @moduledoc """
  初始事件（对应 LPC initial_event）
  """
  defstruct [:data, :delay, :topic]
end
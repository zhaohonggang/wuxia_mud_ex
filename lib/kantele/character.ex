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
    damage: %{}
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

  # ---- temp 存储（对应 LPC get_temp/put_temp/delete_temp/add_temp）----
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
    :loot
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

defmodule Kantele.Character.Vitals do
  @moduledoc """
  Character vital information

  武侠四条气血线：

  - `qi` 气血，归零即死亡
  - `jing` 精力，影响行动（对应 LPC jing；learn/study 消耗）
  - `jingli` 精力修为，由吐纳炼精提升（对应 LPC jingli；非回复线）
  - `neili` 内力，施展绝招/运功消耗
  """

  @derive Jason.Encoder
  defstruct [
    :qi,
    :max_qi,
    :base_qi,
    :jing,
    :max_jing,
    :base_jing,
    :jingli,
    :max_jingli,
    :neili,
    :max_neili,
    :base_neili
  ]

  @doc """
  玩家默认体质：够在黑虎手下逃命几回合

  `base_*` 为创伤不会跌破的下限，自然回复会把 max_* 缓慢回涨到 base
  """
  def new() do
    %__MODULE__{
      qi: 150,
      max_qi: 150,
      base_qi: 150,
      jing: 120,
      max_jing: 120,
      base_jing: 120,
      jingli: 0,
      max_jingli: 0,
      neili: 200,
      max_neili: 200,
      base_neili: 200
    }
  end

  @doc """
  受到直接伤害（对应 LPC receive_damage/2），气血最低打到 0
  """
  def damage(%__MODULE__{} = vitals, :qi, amount) when amount >= 0 do
    %{vitals | qi: max(vitals.qi - amount, 0)}
  end

  def damage(%__MODULE__{} = vitals, :jing, amount) when amount >= 0 do
    %{vitals | jing: max(vitals.jing - amount, 0)}
  end

  def damage(%__MODULE__{} = vitals, :jingli, amount) when amount >= 0 do
    %{vitals | jingli: max(vitals.jingli - amount, 0)}
  end

  @doc """
  创伤削减上限（对应 LPC receive_wound/2 对 eff_qi 的效果），同时夹住当前值
  """
  def wound(%__MODULE__{} = vitals, :qi, amount) when amount >= 0 do
    max_qi = max(vitals.max_qi - amount, 1)
    vitals = %{vitals | max_qi: max_qi}
    %{vitals | qi: min(vitals.qi, max_qi)}
  end

  @doc """
  治疗效果（对应 LPC receive_heal/3）：把当前值向 max_* 回补，不超过上限

  与 `damage` 相反，只抬当前值、不动创伤上限。
  """
  def heal(%__MODULE__{} = vitals, :qi, amount) when amount >= 0,
    do: %{vitals | qi: min(vitals.qi + amount, vitals.max_qi)}

  def heal(%__MODULE__{} = vitals, :jing, amount) when amount >= 0,
    do: %{vitals | jing: min(vitals.jing + amount, vitals.max_jing)}

  def heal(%__MODULE__{} = vitals, :neili, amount) when amount >= 0,
    do: %{vitals | neili: min(vitals.neili + amount, vitals.max_neili)}

  @doc """
  驱除创伤（对应 LPC receive_curing/4 对 eff_* 的效果）：把被 `wound` 削低的
  max_* 向上回补，天花板封在 base_*，并夹住当前值不超新上限
  """
  def curing(%__MODULE__{} = vitals, :qi, amount) when amount >= 0 do
    max_qi = min(vitals.max_qi + amount, vitals.base_qi)
    %{vitals | max_qi: max_qi, qi: min(vitals.qi, max_qi)}
  end

  def curing(%__MODULE__{} = vitals, :jing, amount) when amount >= 0 do
    max_jing = min(vitals.max_jing + amount, vitals.base_jing)
    %{vitals | max_jing: max_jing, jing: min(vitals.jing, max_jing)}
  end

  def curing(%__MODULE__{} = vitals, :neili, amount) when amount >= 0 do
    max_neili = min(vitals.max_neili + amount, vitals.base_neili)
    %{vitals | max_neili: max_neili, neili: min(vitals.neili, max_neili)}
  end

  @doc """
  自然回复：非战斗中缓慢恢复三条线（简化 heal_up/9）

  创伤削减的 max_* 会缓慢向 base_* 回涨
  """
  def regenerate(%__MODULE__{} = vitals, stats, fighting?) do
    con = stats.con

    vitals
    |> regen(:qi, div(con * 2 + 10, regen_scale(fighting?)), vitals.max_qi)
    |> regen(:jing, div(con + 5, regen_scale(fighting?)), vitals.max_jing)
    |> regen(:neili, div(con * 2 + force_bonus(stats), regen_scale(fighting?)), vitals.max_neili)
    |> recover_max(:max_qi, :base_qi, max(div(con, 2), 1))
    |> recover_max(:max_jing, :base_jing, max(div(con, 2), 1))
    |> recover_max(:max_neili, :base_neili, max(div(con, 2), 1))
  end

  @doc """
  根据当前内功等级重算内力上限（对应 LPC query_max_neili）

  force 基础 + 特殊内功加成；每次打坐/练功后调用。
  """
  def recalculate_max_neili(%__MODULE__{} = vitals, stats) do
    alias Kantele.Character.NeiliLimit

    new_max = NeiliLimit.current(stats)

    # 打坐可蓄力到 2×max，重算时夹住当前值不超新上限×2
    neili = min(vitals.neili, new_max * 2)

    %{vitals | max_neili: new_max, neili: neili}
  end

  defp force_bonus(stats), do: div(Map.get(stats.skills, "force", 0), 3)
  defp regen_scale(true), do: 4
  defp regen_scale(false), do: 1

  defp regen(vitals, _key, _amount, 0), do: vitals

  defp regen(vitals, key, amount, max) do
    current = Map.get(vitals, key)

    # 打坐可让内力暂时蓄到 2×上限，自然回复只向上回补、不向下削减
    if current < max do
      %{vitals | key => min(current + amount, max)}
    else
      vitals
    end
  end

  defp recover_max(vitals, max_key, base_key, amount) do
    base = Map.get(vitals, base_key)
    max = Map.get(vitals, max_key)

    # 仅在创伤削减过上限（max < base）时回涨并夹住当前值；
    # 健康态（含打坐蓄力超上限的内力）一律不动，避免回复侵蚀积蓄
    if is_integer(base) and base > max do
      new_max = min(max + amount, base)
      vitals = %{vitals | max_key => new_max}
      clamp_current(vitals, max_key)
    else
      vitals
    end
  end

  defp clamp_current(vitals, :max_qi), do: %{vitals | qi: min(vitals.qi, vitals.max_qi)}
  defp clamp_current(vitals, :max_jing), do: %{vitals | jing: min(vitals.jing, vitals.max_jing)}
  defp clamp_current(vitals, :max_neili), do: %{vitals | neili: min(vitals.neili, vitals.max_neili)}
end

defmodule Kantele.Character.Stats do
  @moduledoc """
  角色的成长属性（对应 LPC dbase 中的 str/dex/con/int/combat_exp/potential/skills）

  - `skills` 基础技能等级表，如 `%{"sword" => 12, "dodge" => 3}`
  - `mapped` 技能映射，如 `%{"sword" => "liuxin-jian"}`（对应 map_skill）
  - `performs` 已学会的绝招，如 `MapSet.new(["liuxin-jian/liu"])`

  江湖数值（A11/链E 地基，对应 LPC score/weiwang/gongxian/shen）：

  - `score` 江湖阅历
  - `weiwang` 威望
  - `gongxian` 门派贡献（拜师后击杀/任务累积）
  - `shen` 正邪（正数为正道；本期只存不用）
  """

  defstruct [
    :str,
    :dex,
    :con,
    :int,
    :combat_exp,
    :potential,
    :learned_points,
    :skills,
    :mapped,
    :performs,
    :score,
    :weiwang,
    :gongxian,
    :shen
  ]

  def new() do
    %__MODULE__{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 1000,
      potential: 100,
      learned_points: 0,
      score: 0,
      weiwang: 0,
      gongxian: 0,
      shen: 0,
      # 新手起步：基本技能够用（空手命中野猪级别的怪），特技靠拜师
      skills: %{"unarmed" => 60, "sword" => 60, "dodge" => 60, "parry" => 60, "force" => 20},
      mapped: %{},
      performs: MapSet.new()
    }
  end

  @doc """
  查询技能等级，未习得为 0
  """
  def skill(%__MODULE__{} = stats, name), do: Map.get(stats.skills, name, 0)

  @doc """
  查询某用法的有效等级：基本等级 + 映射特技等级（对应 LPC query_skill 不带 raw）

  如 force 基本内功 30 级映射 liuxi-neigong 30 级时，有效 force 为 60。
  """
  def effective(%__MODULE__{} = stats, usage) do
    case mapped(stats, usage) do
      nil ->
        skill(stats, usage)

      special_id ->
        skill(stats, usage) + skill(stats, special_id)
    end
  end

  @doc """
  可用潜能 = 总潜能 - 已消耗（对应 LPC `potential - learned_points`，learn.c:124）

  learned_points 是累计已用点数；potential 是累计总获得。
  """
  def available_potential(%__MODULE__{} = stats),
    do: max((stats.potential || 0) - (stats.learned_points || 0), 0)

  @doc "记一笔潜能消耗（learn/practice 成功后调用），返回新 stats"
  def spend_potential(%__MODULE__{} = stats, cost) when cost >= 0,
    do: %{stats | learned_points: (stats.learned_points || 0) + cost}

  @doc """
  可用潜能（对应 LPC `query("potential")`，即花费型潜能池）

  等于 `available_potential/1`：总潜力减去已学点数。
  """
  def potential(%__MODULE__{} = stats), do: available_potential(stats)

  @doc """
  潜能上限（对应 LPC potential_limit）：以已学点数为基准的浮动上限

  预置简化为 `learned_points + 100`（对照 wudang_zhang 的守卫阈值）；
  到期原型可替换为存储字段。
  """
  def potential_limit(%__MODULE__{} = stats),
    do: (stats.learned_points || 0) + 100

  @doc """
  增减可用潜能（对应 LPC `add("potential", delta)`）

  - `delta >= 0`：发放潜能，累计总潜力增加
  - `delta < 0`：消耗可用潜能，记入已学点数
  """
  def add_potential(%__MODULE__{} = stats, delta) when delta >= 0,
    do: %{stats | potential: (stats.potential || 0) + delta}

  def add_potential(%__MODULE__{} = stats, delta) when delta < 0,
    do: %{stats | learned_points: (stats.learned_points || 0) + abs(delta)}

  @doc """
  提升潜能（对应 LPC improve_potential/2）：发放可用潜能

  发放额被封在 `potential_limit` 之内，避免越上限。
  """
  def improve_potential(%__MODULE__{} = stats, gain) when gain >= 0 do
    room = max(potential_limit(stats) - potential(stats), 0)
    add_potential(stats, min(gain, room))
  end

  @doc """
  提升技能一级并返回 {new_stats, gained_level?}
  """
  def improve_skill(%__MODULE__{} = stats, name) do
    skills = Map.update(stats.skills, name, 1, &(&1 + 1))
    {%{stats | skills: skills}, true}
  end

  @doc """
  查询某用法的映射特技，如 usage 为 "sword" 时返回 "liuxin-jian"
  """
  def mapped(stats, usage), do: Map.get(stats.mapped, usage)

  def perform_known?(%__MODULE__{} = stats, perform_id),
    do: MapSet.member?(stats.performs, perform_id)

  def learn_perform(%__MODULE__{} = stats, perform_id) do
    %{stats | performs: MapSet.put(stats.performs, perform_id)}
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
  Initial events to kick off when a character starts
  """

  defstruct [:data, :delay, :topic]
end

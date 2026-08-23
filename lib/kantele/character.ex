defmodule Kantele.Character.PlayerMeta do
  @moduledoc """
  Specific metadata for a character in Kantele
  """

  defstruct [:reply_to, :vitals, :stats, :combat]

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

defmodule Kantele.Character.NonPlayerMeta do
  @moduledoc """
  Specific metadata for a world character in Kantele
  """

  defstruct [:initial_events, :vitals, :zone_id, :stats, :combat_config, :combat]

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

  武侠风格的三条气血线：

  - `qi` 气血，归零即死亡
  - `jing` 精力，影响行动
  - `neili` 内力，施展绝招/运功消耗
  """

  @derive Jason.Encoder
  defstruct [:qi, :max_qi, :jing, :max_jing, :neili, :max_neili]

  @doc """
  玩家默认体质：够在黑虎手下逃命几回合
  """
  def new() do
    %__MODULE__{
      qi: 150,
      max_qi: 150,
      jing: 120,
      max_jing: 120,
      neili: 200,
      max_neili: 200
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

  @doc """
  创伤削减上限（对应 LPC receive_wound/2 对 eff_qi 的效果），同时夹住当前值
  """
  def wound(%__MODULE__{} = vitals, :qi, amount) when amount >= 0 do
    max_qi = max(vitals.max_qi - amount, 1)
    vitals = %{vitals | max_qi: max_qi}
    %{vitals | qi: min(vitals.qi, max_qi)}
  end

  @doc """
  自然回复：非战斗中缓慢恢复三条线（简化 heal_up/9）
  """
  def regenerate(%__MODULE__{} = vitals, stats, fighting?) do
    con = stats.con

    vitals
    |> regen(:qi, div(con * 2 + 10, regen_scale(fighting?)), vitals.max_qi)
    |> regen(:jing, div(con + 5, regen_scale(fighting?)), vitals.max_jing)
    |> regen(:neili, div(con * 2 + force_bonus(stats), regen_scale(fighting?)), vitals.max_neili)
  end

  defp force_bonus(stats), do: div(Map.get(stats.skills, "force", 0), 3)
  defp regen_scale(true), do: 4
  defp regen_scale(false), do: 1

  defp regen(vitals, _key, _amount, 0), do: vitals

  defp regen(vitals, key, amount, max) do
    %{vitals | key => min(Map.get(vitals, key) + amount, max)}
  end
end

defmodule Kantele.Character.Stats do
  @moduledoc """
  角色的成长属性（对应 LPC dbase 中的 str/dex/con/int/combat_exp/potential/skills）

  - `skills` 基础技能等级表，如 `%{"sword" => 12, "dodge" => 3}`
  - `mapped` 技能映射，如 `%{"sword" => "liuxin-jian"}`（对应 map_skill）
  - `performs` 已学会的绝招，如 `MapSet.new(["liuxin-jian/liu"])`
  """

  defstruct [:str, :dex, :con, :int, :combat_exp, :potential, :skills, :mapped, :performs]

  def new() do
    %__MODULE__{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 0,
      potential: 100,
      skills: %{"unarmed" => 1, "sword" => 1, "dodge" => 1, "parry" => 1, "force" => 1},
      mapped: %{},
      performs: MapSet.new()
    }
  end

  @doc """
  查询技能等级，未习得为 0
  """
  def skill(%__MODULE__{} = stats, name), do: Map.get(stats.skills, name, 0)

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
    no_kill: false,
    apply: %{}
  ]

  def new(), do: %__MODULE__{apply: %{}, attitude: nil, no_kill: false, spawn_room_id: nil}
end

defmodule Kantele.Character.InitialEvent do
  @moduledoc """
  Initial events to kick off when a character starts
  """

  defstruct [:data, :delay, :topic]
end

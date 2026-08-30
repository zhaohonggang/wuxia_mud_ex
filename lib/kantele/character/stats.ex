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
  查询某用法的映射特技，如 usage 为 "sword" 时返回 "liuxin-jian"
  """
  def mapped(stats, usage), do: Map.get(stats.mapped, usage)

  def perform_known?(%__MODULE__{} = stats, perform_id),
    do: MapSet.member?(stats.performs, perform_id)

  def learn_perform(%__MODULE__{} = stats, perform_id) do
    %{stats | performs: MapSet.put(stats.performs, perform_id)}
  end

  @doc """
  根据 combat_exp 计算技能上限（对应 LPC skill.c sadjust：上限 = combat_exp^3/10）
  """
  def skill_limit(exp) when is_integer(exp) and exp >= 0 do
    # combat_exp 的立方根 * 10 (近似值)
    # 这里使用整数运算近似：exp / 1000 ^ (1/3) * 10
    # 简化版：上限 = exp 的立方根 * 10
    limit = :math.pow(exp / 1000.0, 1.0 / 3.0) * 10
    floor(limit)
  end

  @doc """
  提升技能等级（对应 LPC improve_skill）：技能 +1，返回 {新stats, 是否升级成功}

  技能等级上限由调用方在适当地方校验（如 level_gate）；此处只负责 +1。
  """
  def improve_skill(%__MODULE__{} = stats, skill_name) do
    new_skills = Map.update(stats.skills, skill_name, 1, &(&1 + 1))
    {%{stats | skills: new_skills}, true}
  end
end

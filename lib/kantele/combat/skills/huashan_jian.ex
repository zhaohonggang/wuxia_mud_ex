defmodule Kantele.Combat.Skills.HuashanJian do
  @moduledoc """
  华山剑法（对照 kungfu/skill/huashan-jian.c）

  招式表为纯数据（@actions，取 LPC action 表中的 6 式静态招式）。
  第 7 式「极意」（lvl 200，力/攻/闪/架/伤按 force/sword/dodge/parry 动态生成）
  依赖出招时的属性，暂以 TODO(migrate) 留待 query_action 拿到 stats 后补齐。
  hit_ob「紫霞剑气」（华山+狂风快剑+紫霞神功均 300 且映射齐全时的额外创伤）
  需要引擎提供命中钩子，见 TODO(migrate)。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N使一招「有凤来仪」，手中$w剑光暴长，向$n的$l刺去",
      "force" => 70,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "有凤来仪"
    },
    %{
      "action" => "$N剑随身转，一招「无边落木」罩向$n的$l",
      "force" => 120,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "无边落木"
    },
    %{
      "action" => "$N舞动$w，一招「鸿飞冥冥」挟著无数剑光刺向$n的$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "鸿飞冥冥"
    },
    %{
      "action" => "$N手中$w龙吟一声，祭出「平沙落雁」往$n的$l刺出数剑",
      "force" => 190,
      "attack" => 30,
      "parry" => 28,
      "dodge" => 35,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "平沙落雁"
    },
    %{
      "action" => "$N手中$w剑光暴长，一招「金玉满堂」往$n$l刺去",
      "force" => 220,
      "attack" => 40,
      "parry" => 33,
      "dodge" => 40,
      "damage" => 55,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "金玉满堂"
    },
    %{
      "action" => "$N手中$w化成一道光弧，直指$n$l，一招「白虹贯日」发出虎哮龙吟刺去",
      "force" => 260,
      "attack" => 50,
      "parry" => 40,
      "dodge" => -20,
      "damage" => 90,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "白虹贯日"
    }
  ]

  @impl true
  def id(), do: "huashan-jian"

  @impl true
  def valid_enable(usage), do: usage == "sword" or usage == "parry"

  # TODO(migrate): LPC valid_learn 还要求 max_neili >= 100 且手持剑（query_temp weapon）
  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内力不够，没有办法练华山剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的华山剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 31}

  @doc "按等级加权随机选一式（招式表 + NewRandom）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def perform_list() do
    %{"jie" => Kantele.Combat.Skills.Performs.HuashanJian.Jie}
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> action["skill_name"]
    end
  end
end

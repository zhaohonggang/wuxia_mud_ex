defmodule Kantele.Combat.Skills.TanTui do
  @moduledoc """
  武学实装「tan-tui」（源 tan-tui.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/tan_tui/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左脚猛地飞起，一式「一步三环」，脚尖踢向$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "一步三环"
    },
    %{
      "action" => "$N左脚顿地，右脚一式「三步九转」，猛地踹向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 25,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "三步九转"
    },
    %{
      "action" => "$N两臂舒张，右脚横踢，既猛且准，一式「十二连环」踢向$n",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "十二连环"
    },
    %{
      "action" => "$N突然跃起，双足连环圈转，一式「双打奇门」，攻向$n的全身",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "双打奇门"
    },
    %{
      "action" => "$N双脚交叉踢起，一式「环变中盘」，脚脚不离$n的面门左右",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "环变中盘"
    },
    %{
      "action" => "$N一个侧身，右脚自上而下「绳挂一条鞭」，照$n的面门直劈下来",
      "force" => 260,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 45,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "绳挂一条鞭"
    },
    %{
      "action" => "$N使一式「十字绕三尖」，双足忽前忽后，迅猛无及踹向$n的胸口",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "十字绕三尖"
    },
    %{
      "action" => "$N开声吐气，大喝一声，一式「犀牛望月转回还」，双脚猛踢$n",
      "force" => 330,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "犀牛望月转回还"
    }
  ]

  @impl true
  def id(), do: "tan-tui"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 51}

  # LPC `valid_learn(object me)`（源 tan-tui.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "学习十二路潭腿必须空手。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功火候不够，无法学十二路潭腿。\n"}

      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力太弱，无法练十二路潭腿。\n"}

      Stats.skill(stats, "unarmed") < lvl ->
        {:error, "你基本拳脚火候不够，无法领会更高深的十二路潭腿。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
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
      action -> Map.get(action, "skill_name")
    end
  end

  @impl true
  def perform_list() do
    %{
      "wang" => Kantele.Combat.Skills.Performs.TanTui.Wang
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

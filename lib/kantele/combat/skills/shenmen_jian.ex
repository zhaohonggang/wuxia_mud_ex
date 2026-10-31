defmodule Kantele.Combat.Skills.ShenmenJian do
  @moduledoc """
  武学实装「shenmen-jian」（源 shenmen-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/shenmen_jian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N身形斜飞，手中$w轻轻点向$n的腕部",
      "force" => 60,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 20,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N长跃而起，$w猛然下刺，直打$n腕部的神门穴",
      "force" => 74,
      "attack" => 0,
      "parry" => 13,
      "dodge" => 25,
      "damage" => 9,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w自上而下反刺，模拟冰轮横空、清光铺地的光景",
      "force" => 86,
      "attack" => 27,
      "parry" => 17,
      "dodge" => 15,
      "damage" => 17,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w颤动来回挥削，只幌得$n眼花撩乱，浑不知从何攻来",
      "force" => 89,
      "attack" => 31,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 21,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w由内自外一刺，左手虚击，身形一晃，$w已搭在$n腕部",
      "force" => 107,
      "attack" => 38,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 29,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N左掌横摆胸前，右手中$w轻轻挥拂，直取$n的神门要穴",
      "force" => 130,
      "attack" => 29,
      "parry" => 37,
      "dodge" => 35,
      "damage" => 28,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w中宫直入，携着强大的劲道攻向$n的$l",
      "force" => 160,
      "attack" => 42,
      "parry" => 40,
      "dodge" => 45,
      "damage" => 39,
      "lvl" => 0,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "shenmen-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 52, neili: 58}

  # LPC `valid_learn(object me)`（源 shenmen-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    neili = neili_of(character)

    cond do
      Stats.skill(stats, "force") < 60 ->
        {:error, "你的内功火候不到，无法学习神门十三剑。\n"}

      not is_nil(neili) and neili < 300 ->
        {:error, "你的内力太差，无法学习神门十三剑。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的神门十三剑。\n"}

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

  @impl true
  def perform_list() do
    %{
      "ci" => Kantele.Combat.Skills.Performs.ShenmenJian.Ci
    }
  end

  # LPC `me->query("neili")`：当前内力（vitals）
  defp neili_of(%{meta: %{vitals: %{neili: n}}}) when is_integer(n), do: n
  defp neili_of(_character), do: nil
end

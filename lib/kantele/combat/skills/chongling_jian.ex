defmodule Kantele.Combat.Skills.ChonglingJian do
  @moduledoc """
  武学实装「chongling-jian」（源 chongling-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/chongling_jian/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手中$w一抖，一招「青梅如豆」使出，眼中柔情万千，向$n的$l刺去",
      "force" => 70,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "青梅如豆"
    },
    %{
      "action" => "$N身法陡快，一招「雾中初见」倒使上来，$w直指$n$l",
      "force" => 120,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "雾中初见"
    },
    %{
      "action" => "$N手中$w反转回来，似攻非攻，但剑身突转，刺向$n，心中似乎藏有万千感慨",
      "force" => 160,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "雨后乍逢"
    },
    %{
      "action" => "$N长叹一声，跨步向前，使一招「同生共死」，手中$w斜刺而出，不守不防，誓将生死置之度外",
      "force" => 280,
      "attack" => 60,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "同生共死"
    }
  ]

  @impl true
  def id(), do: "chongling-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 31}

  # LPC `valid_learn(object me)`（源 chongling-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够，没有办法练冲灵剑法。\n"}

      Stats.skill(stats, "huashan-jian") < 100 ->
        {:error, "你华山剑法火候不够，无法练冲灵剑法。\n"}

      Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你必须先找一把剑才能学习冲灵剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法火候有限，无法领会更高深的冲灵剑法。\n"}

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

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

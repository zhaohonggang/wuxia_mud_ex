defmodule Kantele.Combat.Skills.SijiJianfa do
  @moduledoc """
  武学实装「siji-jianfa」（源 siji-jianfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/siji_jianfa/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N使一式「春暖花开」，手中$w由左至右横扫向向$n的$l",
      "force" => 60,
      "attack" => 5,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 33,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N踏上一步，「夏日炎炎」，手中$w盘旋飞舞出一道剑光刺向$n的$l",
      "force" => 120,
      "attack" => 15,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 51,
      "lvl" => 40,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w一抖，一招「秋风萧瑟」，斜斜一剑反腕撩出，攻向$n的$l",
      "force" => 150,
      "attack" => 64,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 85,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w连绕数个大圈，一式「冬掣寒星」，一道剑光飞向$n的$l",
      "force" => 180,
      "attack" => 95,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 125,
      "lvl" => 120,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "siji-jianfa"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 125, neili: 125}

  # LPC `valid_learn(object me)`（源 siji-jianfa.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    neili = neili_of(character)

    cond do
      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法火候不到，无法学习四季剑法。\n"}

      Stats.skill(stats, "force") < 30 ->
        {:error, "你的内功火候不到，无法学习四季剑法。\n"}

      not is_nil(neili) and neili < 200 ->
        {:error, "你的内力太差，无法学习四季剑法。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的四季剑法。\n"}

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

  # LPC `me->query("neili")`：当前内力（vitals）
  defp neili_of(%{meta: %{vitals: %{neili: n}}}) when is_integer(n), do: n
  defp neili_of(_character), do: nil
end

defmodule Kantele.Combat.Skills.ShaolinJiuyang do
  @moduledoc """
  武学实装「shaolin-jiuyang」（源 shaolin-jiuyang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 2 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：exert_function_file, practice_skill, valid_force
  - perform/exert 路由骨架见 tmp/perf_out/shaolin_jiuyang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N飞身一跃而起，身法陡然加快，朝着$n$l快速攻出数十拳",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N沉身运气，一拳击向$n，刹那间，$N全身竟浮现出一道金光",
      "force" => 0,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 0,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "shaolin-jiuyang"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  # LPC `valid_learn(object me)`（源 shaolin-jiuyang.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    gender = gender_of(character)

    cond do
      Stats.skill(stats, "yinyang-shiertian") > 0 ->
        {:error, "你已将九阳神功融汇贯通，合成了普天之下最强的武功，不必再分开学习了。\n"}

      Stats.skill(stats, "jiuyang-shengong") > 0 ->
        {:error, "你已将三种九阳神功全部融汇贯通，不必再分开学习了。\n"}

      (gender == "无性") and (Stats.skill(stats, "shaolin-jiuyang") > 9) ->
        {:error, "你无根无性，阴阳不调，难以领会高深的少林九阳神功。\n"}

      Stats.con(stats) < 34 ->
        {:error, "你的先天根骨孱弱，无法修炼少林九阳神功。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功太差，无法学习少林九阳神功。\n"}

      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力修为太浅，无法学习少林九阳神功。\n"}

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

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"
end

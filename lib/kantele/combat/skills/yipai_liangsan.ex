defmodule Kantele.Combat.Skills.YipaiLiangsan do
  @moduledoc """
  武学实装「yipai-liangsan」（源 yipai-liangsan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 2 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yipai_liangsan/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一掌拍向$n，没有什么章法",
      "force" => 100,
      "attack" => -50,
      "parry" => -50,
      "dodge" => -50,
      "damage" => -50,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N深深吸了一口气，双掌划了一个圈子，缓缓拍向$n，掌力有如排山倒海一般",
      "force" => 700,
      "attack" => 400,
      "parry" => 30,
      "dodge" => -20,
      "damage" => 300,
      "lvl" => 150,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "yipai-liangsan"

  @impl true
  def valid_enable(usage), do: usage in ["strike"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 100}

  # LPC `valid_learn(object me)`（源 yipai-liangsan.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练一拍两散必须空手。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，不能强行修习一拍两散。\n"}

      (Stats.int(stats) < 28) or (Stats.con(stats) < 28) ->
        {:error, "你的先天条件不够，无法练习一拍两散。\n"}

      not is_nil(max_neili) and max_neili < 2500 ->
        {:error, "你的内力还不够强，无法修习一拍两散。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法火候水平有限，无法领会更高深的一拍两散。\n"}

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
end

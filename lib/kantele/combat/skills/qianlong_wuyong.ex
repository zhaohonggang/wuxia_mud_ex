defmodule Kantele.Combat.Skills.QianlongWuyong do
  @moduledoc """
  武学实装「qianlong-wuyong」（源 qianlong-wuyong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/qianlong_wuyong/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N左掌聚成拳状，右掌一招「潜龙勿用」缓缓推向$n的$l",
      "force" => 280,
      "attack" => 0,
      "parry" => 30,
      "dodge" => -10,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "qianlong-wuyong"

  @impl true
  def valid_enable(usage), do: usage in ["strike"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 40}

  # LPC `valid_learn(object me)`（源 qianlong-wuyong.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    personality = personality_of(character)

    cond do
      Stats.skill(stats, "xianglong-zhang") > 0 ->
        {:error, "你已经学全十八掌了，不必再单独学习。\n"}

      personality == "阴险奸诈" ->
        {:error, "你心中暗想：这武功难练得紧，学它做甚？\n"}

      Stats.str(stats) < 36 ->
        {:error, "你的先天膂力孱弱，难以修炼降龙十八掌。\n"}

      Stats.con(stats) < 32 ->
        {:error, "你的先天根骨孱弱，难以修炼降龙十八掌。\n"}

      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不够，难以修炼降龙十八掌。\n"}

      not is_nil(max_neili) and max_neili < 3000 ->
        {:error, "你的内力修为不足，难以修炼降龙十八掌。\n"}

      Stats.skill(stats, "strike") < 180 ->
        {:error, "你的基本掌法火候不够，难以修炼降龙十八掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的降龙十八掌。\n"}

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

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil
end

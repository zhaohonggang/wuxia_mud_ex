defmodule Kantele.Combat.Skills.YuyueYuyuan do
  @moduledoc """
  武学实装「yuyue-yuyuan」（源 yuyue-yuyuan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 1 式、valid_enable、practice_cost、valid_learn。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill（valid_learn 已迁移）
  - perform/exert 路由骨架见 tmp/perf_out/yuyue_yuyuan/
  """

  use Kantele.Combat.Skill
  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N使出「鱼跃于渊」，身形飞起，双掌并在一起向$n的$l劈下",
      "force" => 240,
      "attack" => 0,
      "parry" => -5,
      "dodge" => 10,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "震伤"
    }
  ]

  @impl true
  def id(), do: "yuyue-yuyuan"

  @impl true
  def valid_enable(usage), do: usage in ["strike"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 40}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  # LPC `valid_learn(object me)`（源 yuyue-yuyuan.c）—— 降龙十八掌 14 个子招共用同一门槛。
  # 源里全部用 `query("character")` 判天性；`query_skill("force")` 为 1 参形式，
  # 按本仓约定映射到 `Stats.effective/2`（含 enable 加成），其余 `query_skill(x, 1)`
  # 为 2 参原始值，映射到 `Stats.skill/2`。
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "xianglong-zhang") > 0 ->
        {:error, "你已经学全十八掌了，不必再单独学习。\n"}

      personality_of(character) == "阴险奸诈" ->
        {:error, "你心中暗想：这武功难练得紧，学它做甚？\n"}

      Stats.query_str(stats) < 36 ->
        {:error, "你的先天膂力孱弱，难以修炼降龙十八掌。\n"}

      Stats.query_con(stats) < 32 ->
        {:error, "你的先天根骨孱弱，难以修炼降龙十八掌。\n"}

      Stats.effective(stats, "force") < 300 ->
        {:error, "你的内功火候不够，难以修炼降龙十八掌。\n"}

      not is_nil(max_neili) and max_neili < 3000 ->
        {:error, "你的内力修为不足，难以修炼降龙十八掌。\n"}

      Stats.skill(stats, "strike") < 180 ->
        {:error, "你的基本掌法火候不够，难以修炼降龙十八掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法水平有限，无法领会更高深的降龙十八掌。\n"}

      true ->
        :ok
    end
  end

  # LPC `me->query("max_neili")`：在 Vitals，不在 Stats；缺失视为「无上限数据」不拦截
  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  # LPC `me->query("character")`：天性/人格（PlayerMeta.character；未设 → nil，等价 LPC 0）
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :character)
  defp personality_of(_character), do: nil
end

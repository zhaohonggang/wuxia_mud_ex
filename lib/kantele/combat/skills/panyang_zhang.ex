defmodule Kantele.Combat.Skills.PanyangZhang do
  @moduledoc """
  武学实装「panyang-zhang」（源 panyang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine
  - perform/exert 路由骨架见 tmp/perf_out/panyang_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N划身错步，一式「洪炉焚天」，双掌内拢外托，攻向$n的左肩",
      "force" => 70,
      "attack" => 5,
      "parry" => 38,
      "dodge" => 38,
      "damage" => 1,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "洪炉焚天"
    },
    %{
      "action" => "$N一式「举火烧天」，双掌以迅雷不及掩耳之势，劈向$n的两额太阳穴",
      "force" => 95,
      "attack" => 8,
      "parry" => 43,
      "dodge" => 43,
      "damage" => 4,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "举火烧天"
    },
    %{
      "action" => "$N使一式「偷星换日」，劲气弥漫，双掌如轮，一环环向$n的后背斫去",
      "force" => 120,
      "attack" => 13,
      "parry" => 51,
      "dodge" => 51,
      "damage" => 8,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "偷星换日"
    },
    %{
      "action" => "$N一式「烈阳繁生」，双掌似让非让，似顶非顶，气浪如急流般使$n陷身其中",
      "force" => 140,
      "attack" => 15,
      "parry" => 65,
      "dodge" => 65,
      "damage" => 12,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "烈阳繁生"
    }
  ]

  @impl true
  def id(), do: "panyang-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 20, neili: 40}

  # LPC `valid_learn(object me)`（源 panyang-zhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练攀阳掌必须空手。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候不够，不能练攀阳掌。\n"}

      not is_nil(max_neili) and max_neili < 50 ->
        {:error, "你的内力太弱，无法练攀阳掌。\n"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法太差，无法领会更高深的攀阳掌。\n"}

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
      "pan" => Kantele.Combat.Skills.Performs.PanyangZhang.Pan
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

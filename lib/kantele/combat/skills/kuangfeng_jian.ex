defmodule Kantele.Combat.Skills.KuangfengJian do
  @moduledoc """
  狂风快剑（对照 `kungfu/skill/kuangfeng-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  招式表为纯数据（`@actions`，取 LPC `action` 表的 4 式静态招式），选招用
  `Kantele.Combat.Skill.pick_action/3`（LPC `NewRandom` 加权，`level > lvl`
  严格过滤）。

  绝招实现见 `lib/kantele/combat/skills/performs/kuangfeng_jian/`。

  练招消耗 `practice_cost`（LPC 扣 qi 60 / neili 36，须持剑）与学习门槛 `valid_learn/2`
  （含 max_neili>=200；原 /1 版因无 vitals 漏判此项）已按 LPC 迁移（2026-10-30）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N纵身跃起手中$w轻挥，斩向$n后颈",
      "force" => 160,
      "attack" => 35,
      "parry" => 40,
      "dodge" => 80,
      "damage" => 125,
      "lvl" => 0,
      "skill_name" => "风平浪静",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w连话三个弧形，向$n的右臂齐肩斩落",
      "force" => 180,
      "attack" => 55,
      "parry" => 52,
      "dodge" => 95,
      "damage" => 148,
      "lvl" => 30,
      "skill_name" => "风起云涌",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N轻吁一声，刷刷刷刷四剑，向$n胸，腹，腰，肩四处连刺",
      "force" => 220,
      "attack" => 81,
      "parry" => 18,
      "dodge" => 123,
      "damage" => 195,
      "lvl" => 60,
      "skill_name" => "风卷残云",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N仰天一声清啸，斜行向前，$w横削直击，迅捷无比，击向$n的$l",
      "force" => 280,
      "attack" => 108,
      "parry" => 20,
      "dodge" => 152,
      "damage" => 230,
      "lvl" => 90,
      "skill_name" => "风流云散",
      "damage_type" => "割伤"
    }
  ]

  @impl true
  def id(), do: "kuangfeng-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=200, dodge>=90, dex>=28, sword>=kuangfeng-jian
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力修为不够，无法修习狂风快剑。\n"}

      Stats.skill(stats, "dodge") < 90 ->
        {:error, "你的基本轻功火候太浅，无法修习狂风快剑。\n"}

      stats.dex < 28 ->
        {:error, "你的身法还不够灵活，无法修习狂风快剑。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的狂风快剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 36（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 36}

  @doc "按等级加权随机选一式（招式表 + NewRandom）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  # 狂风快剑无动态招式表，query_action/3 与 /2 行为一致（忽略 attacker）
  @impl true
  def query_action(_level, rng, _attacker), do: query_action(_level, rng)

  @impl true
  def perform_list() do
    %{
      "sao" => Kantele.Combat.Skills.Performs.KuangfengJian.Sao,
      "yong" => Kantele.Combat.Skills.Performs.KuangfengJian.Yong
    }
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "当前等级对应的最高招式名（query_skill_name，LPC `level >= lvl`）"
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

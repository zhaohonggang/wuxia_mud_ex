defmodule Kantele.Combat.Skills.EmeiJian do
  @moduledoc """
  峨眉剑法（对照 `kungfu/skill/emei-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/emei_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=100 / force>=20 / sword>=emei-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 25 / neili 1，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「飞燕入林」，手中$w轻轻颤动，一剑自上而下扎向$n的$l",
      "force" => 120,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 0,
      "skill_name" => "飞燕入林"
    },
    %{
      "action" => "$N身形不动，一招「虚式分金」，手中$w向前下反刺，一剑指向$n的$l",
      "force" => 120,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 10,
      "skill_name" => "虚式分金"
    },
    %{
      "action" => "$N右手$w先向前刺，使出一式「凤凰挚窝」，剑光如匹练般泄向$n的$l",
      "force" => 140,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 20,
      "skill_name" => "凤凰挚窝"
    },
    %{
      "action" => "$N碎步急进，提剑沿剑身方向疾速上刺，一招「轻罗小扇」直取$n的$l",
      "force" => 150,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 30,
      "skill_name" => "轻罗小扇"
    },
    %{
      "action" => "$N平剑斜洗，臂圆剑直，一式「玉女穿梭」，$w连绵不绝刺向$n的$l",
      "force" => 130,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 40,
      "skill_name" => "玉女穿梭"
    },
    %{
      "action" => "$N屈腕抬臂，剑由前向后上方抽带，一式「黑沼灵狐」直刺向$n的$l",
      "force" => 120,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 50,
      "skill_name" => "黑沼灵狐"
    },
    %{
      "action" => "$N抱剑当胸，正反搅动，右手$w一式「顺水推舟」，刺向$n的$l",
      "force" => 110,
      "dodge" => 15,
      "lvl" => 60,
      "skill_name" => "顺水推舟"
    },
    %{
      "action" => "$N侧身退步，左手剑指划转，一记「伊人消魂」自下上撩指向$n的$l",
      "force" => 150,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 70,
      "skill_name" => "伊人消魂"
    }
  ]

  @impl true
  def id(), do: "emei-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=100 / force>=20 / sword>=emei-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的峨嵋剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 25 / neili 1（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 25, neili: 1}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"xian" => Kantele.Combat.Skills.Performs.EmeiJian.Xian}
  end
  def actions(), do: @actions

end

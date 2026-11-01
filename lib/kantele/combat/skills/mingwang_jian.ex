defmodule Kantele.Combat.Skills.MingwangJian do
  @moduledoc """
  明王剑法（对照 `kungfu/skill/mingwang-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/mingwang_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=400 / force>=70 / sword>=mingwang-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 50 / neili 58，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N怒目圆睁，使出一招「不动」，手中$w一抖，直刺$n的$l",
      "force" => 100,
      "dodge" => -10,
      "damage" => 30,
      "lvl" => 0,
      "skill_name" => "不动"
    },
    %{
      "action" => "$N使出一式「起手出剑」，足下一滑，剑芒闪向$n的$l",
      "force" => 140,
      "dodge" => 5,
      "damage" => 30,
      "lvl" => 30,
      "skill_name" => "起手出剑"
    },
    %{
      "action" => "$N使出一招「山崩」，纵身跃入半空，$w如山崩般劈向$n的$l",
      "force" => 180,
      "dodge" => -10,
      "damage" => 40,
      "lvl" => 50,
      "skill_name" => "山崩"
    },
    %{
      "action" => "$N使出「千旋转」，将$w舞得如纺车一般，忽然一剑刺向$n的$l",
      "force" => 220,
      "dodge" => 10,
      "damage" => 48,
      "lvl" => 70,
      "skill_name" => "千旋转"
    },
    %{
      "action" => "$N使出一招「降魔舞」，全身劲气贯于$w中，剑气直指$n的$l",
      "force" => 250,
      "dodge" => 10,
      "damage" => 54,
      "lvl" => 90,
      "skill_name" => "降魔舞"
    },
    %{
      "action" => "$N单足独立，使出一式「鹤舞」，一道剑光如白影般向$n的$l扫去",
      "force" => 280,
      "dodge" => 15,
      "damage" => 60,
      "lvl" => 120,
      "skill_name" => "鹤舞"
    },
    %{
      "action" => "$N使出一招「龙腾」，手中$w便如游龙一般扑向$n的$l",
      "force" => 300,
      "dodge" => 20,
      "damage" => 66,
      "lvl" => 140,
      "skill_name" => "龙腾"
    },
    %{
      "action" => "$N飞身一跃，居高临下使出「花雨满天」，顿时剑尖如雨刺向$n的$l",
      "force" => 320,
      "dodge" => 25,
      "damage" => 80,
      "lvl" => 160,
      "skill_name" => "花雨漫天"
    }
  ]

  @impl true
  def id(), do: "mingwang-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=400 / force>=70 / sword>=mingwang-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 400 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 70 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的不动明王剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 58（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 58}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "ruo" => Kantele.Combat.Skills.Performs.MingwangJian.Ruo,
      "xiang" => Kantele.Combat.Skills.Performs.MingwangJian.Xiang
    }
  end
  def actions(), do: @actions

end

defmodule Kantele.Combat.Skills.BoyunSuowu do
  @moduledoc """
  拨云锁雾（对照 `kungfu/skill/boyun-suowu.c`）

  拳脚载体：`valid_enable("hand")`、`valid_enable("dodge")`、`valid_enable("parry")`；
  仅可学不可练。`valid_force` 接受 碧云心法 共存。

  绝招实现见 `lib/kantele/combat/skills/performs/boyun_suowu/`。

  学习门槛 `valid_learn/2`（biyun-xinfa>=10 / max_neili>=100）与
  练招消耗 `practice_cost`（LPC 扣 qi 25 / neili 100，空手）已按 LPC 迁移（2026-10-30）。
  LPC 的「空手（query_temp("weapon")）」检查未在 `valid_learn` 建模
  （学习/练习本就空手，由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N双手飘浮不定,突然从不可以思意的角度，拍向$n的胸口",
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 10,
      "skill_name" => "云里雾里"
    },
    %{
      "action" => "$N长啸一声，平地飞起三丈，居高临下脚上头下，双手重叠在一起，运劲压向对手，$n大惊失色",
      "dodge" => 60,
      "damage" => 50,
      "skill_name" => "拨开云雾"
    },
    %{
      "action" => "$n眼前一花，失去$N的身影，只听见身后响起一阵掌风，只见$N双手同时拍中$n背门要害",
      "dodge" => 70,
      "damage" => 40,
      "skill_name" => "迷云幽雾"
    },
    %{
      "action" => "$N掌指齐出，拍拿并施，拿向$n的三路要害",
      "dodge" => 90,
      "damage" => 50,
      "lvl" => 10,
      "skill_name" => "云深雾泽"
    },
    %{
      "action" => "$N运气狂哮，四面八方出现无数掌影，一掌突出，夹着雷霆万钧之式拍向$n",
      "dodge" => 120,
      "damage" => 100,
      "lvl" => 80,
      "skill_name" => "漫天云雾"
    }
  ]

  @impl true
  def id(), do: "boyun-suowu"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "dodge", "parry"]

  @impl true
  def valid_force(force), do: force == "biyun-xinfa"

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 25 / neili 100（空手）"
  @impl true
  def practice_cost(), do: %{qi: 25, neili: 100}

  # LPC `valid_learn(object me)`（源 boyun-suowu.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练拨云锁雾必需空手。\n"}

      Stats.skill(stats, "biyun-xinfa") < 10 ->
        {:error, "你的碧云心法火候不够，无法学拨云锁雾。\n"}

      not is_nil(max_neili) and max_neili < 100 ->
        {:error, "你的内力太弱，无法练拨云锁雾。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "dian" => Kantele.Combat.Skills.Performs.BoyunSuowu.Dian,
      "meng" => Kantele.Combat.Skills.Performs.BoyunSuowu.Meng
    }
  end
  def actions(), do: @actions

end

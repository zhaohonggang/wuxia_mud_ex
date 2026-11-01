defmodule Kantele.Combat.Skills.QingliangJian do
  @moduledoc """
  清凉剑法（对照 `kungfu/skill/qingliang-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/qingliang_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=500 / shaolin-xinfa>=50 / sword>=50）与
  练招消耗 `practice_cost`（LPC 扣 qi 35（不耗内力），须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持剑（weapon skill_type=="sword"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N举剑过顶，弯腰躬身，恭敬一式「清风送暖」，$w向$n的$l轻轻刺去，",
      "force" => 120,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 0
    },
    %{
      "action" => "突然间剑光一吐，长剑化作一道白虹，$N使出一式「风清似水」，剑气古朴，$w直刺$n的$l",
      "force" => 140,
      "dodge" => 15,
      "damage" => 50,
      "lvl" => 10
    },
    %{
      "action" => "$N左手向外一分，右手$w向右掠出一招「风声四起」，剑气森然地向$n的$l挥去",
      "force" => 200,
      "dodge" => 15,
      "damage" => 60,
      "lvl" => 20
    },
    %{
      "action" => "$N一剑从空中疾劈而下，招式看似平平无奇，但呼的一声响，实有石破天惊的气势，一招「凉风决」$w如虹地刺向$n的$l",
      "force" => 240,
      "dodge" => 10,
      "damage" => 70,
      "lvl" => 30
    },
    %{
      "action" => "$N一柄$w自半空中横过，剑身似曲似直，如一件活物一般，一式「清水凉风」奔腾矫夭，气势雄浑地斩向$n的$l",
      "force" => 270,
      "dodge" => 10,
      "damage" => 80,
      "lvl" => 40
    },
    %{
      "action" => "$N威仪整肃一式「玉井天池」，$w轰然一动，犹如千军万马奔驰而来，疾疾刺向$n的$l",
      "force" => 280,
      "dodge" => 5,
      "damage" => 90,
      "lvl" => 50
    },
    %{
      "action" => "$N剑转一式「叠翠浮青」，俨然长枪大戟，黄沙千里，$w电闪雷鸣，将$n笼罩于重重剑气之中",
      "force" => 300,
      "dodge" => 5,
      "damage" => 110,
      "lvl" => 60
    },
    %{
      "action" => "$N剑尖向下，一招「清风影动」，$w忽然急转直上，剑气将$n的上身要害团团围住",
      "force" => 380,
      "dodge" => -5,
      "damage" => 135,
      "lvl" => 70
    }
  ]

  @impl true
  def id(), do: "qingliang-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=500 / shaolin-xinfa>=50 / sword>=50
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "shaolin-xinfa") < 50 ->
        {:error, "你的少林心法火候太浅。\n"}

      Stats.skill(stats, "sword") < 50 ->
        {:error, "你的基本剑法火候尚浅。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 35（不耗内力，须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 35, neili: 0}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"ming" => Kantele.Combat.Skills.Performs.QingliangJian.Ming}
  end
  def actions(), do: @actions

end

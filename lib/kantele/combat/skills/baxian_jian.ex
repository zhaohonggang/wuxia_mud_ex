defmodule Kantele.Combat.Skills.BaxianJian do
  @moduledoc """
  八仙剑法（对照 `kungfu/skill/baxian-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/baxian_jian/`。

  学习门槛 `valid_learn/2`（max_neili>=200 / force>=20 / sword>=10 / sword>=baxian-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 43 / neili 44，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的须持剑（weapon skill_type=="sword"）检查由 practice 流程把关，未写入 `valid_learn`；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N面露微笑，一招「拨云见日」，手中$w一抖，剑光暴长，洒向$n的$l",
      "force" => 50,
      "attack" => 15,
      "dodge" => 10,
      "parry" => 25,
      "damage" => 10,
      "lvl" => 0,
      "skill_name" => "拨云见日"
    },
    %{
      "action" => "$N一招「仙人指路」，身形突闪，剑招陡变，手中$w从后部斜刺向$n的$l",
      "force" => 70,
      "attack" => 21,
      "dodge" => 25,
      "parry" => 30,
      "damage" => 15,
      "lvl" => 20,
      "skill_name" => "仙人指路"
    },
    %{
      "action" => "$N暴退数尺，一招「曹国舅拍板」，低首抚剑，随后手中$w骤然穿上，刺向$n的$l",
      "force" => 75,
      "attack" => 23,
      "dodge" => 22,
      "parry" => 32,
      "damage" => 20,
      "lvl" => 40,
      "skill_name" => "曹国舅拍板"
    },
    %{
      "action" => "$N身形一晃，疾掠而上，使一招「丹凤朝阳」，手中$w龙吟一声，对准$n连递数剑",
      "force" => 90,
      "attack" => 29,
      "dodge" => 10,
      "parry" => 25,
      "damage" => 21,
      "lvl" => 60,
      "skill_name" => "丹凤朝阳"
    },
    %{
      "action" => "$N身形一展，施展出「湘子吹箫」，如影相随，手中$w疾往$n的$l刺去",
      "force" => 103,
      "attack" => 31,
      "dodge" => 13,
      "parry" => 22,
      "damage" => 23,
      "lvl" => 80,
      "skill_name" => "湘子吹箫"
    },
    %{
      "action" => "$N一招「采和献花」，侧过身子，手中$w疾往斜上挑起，直指$n的$l",
      "force" => 125,
      "attack" => 35,
      "dodge" => 15,
      "parry" => 25,
      "damage" => 28,
      "lvl" => 100,
      "skill_name" => "采和献花"
    },
    %{
      "action" => "$N微微一个转身，一招「张果老倒骑驴」，手中$w却已自肋下穿出，罩向$n的$l",
      "force" => 133,
      "attack" => 42,
      "dodge" => 11,
      "parry" => 27,
      "damage" => 33,
      "lvl" => 120,
      "skill_name" => "张果老倒骑驴"
    },
    %{
      "action" => "$N神色微变，一招「汉锺离阴阳宝扇」，剑招顿时变得凌厉无比，手中$w闪电般射向$n",
      "force" => 151,
      "attack" => 47,
      "dodge" => 13,
      "parry" => 32,
      "damage" => 36,
      "lvl" => 140,
      "skill_name" => "汉锺离阴阳宝扇"
    },
    %{
      "action" => "$N缓缓低首，接着一招「铁拐李葫芦系腰」，手中$w中宫直进，迅捷无比地往$n刺去",
      "force" => 165,
      "attack" => 53,
      "dodge" => 20,
      "parry" => 34,
      "damage" => 43,
      "lvl" => 160,
      "skill_name" => "铁拐李葫芦系腰"
    }
  ]

  @impl true
  def id(), do: "baxian-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 max_neili>=200 / force>=20 / sword>=10 / sword>=baxian-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 200 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 10 ->
        {:error, "你的基本剑法火候不够，无法学习八仙剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的八仙剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 43 / neili 44（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 43, neili: 44}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"dian" => Kantele.Combat.Skills.Performs.BaxianJian.Dian}
  end
  def actions(), do: @actions

end

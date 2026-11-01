defmodule Kantele.Combat.Skills.BaibianDaxue do
  @moduledoc """
  百变大学（对照 `kungfu/skill/baibian-daxue.c`）

  杖/棍法载体：`valid_enable("staff")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/baibian_daxue/`。

  学习门槛 `valid_learn/2`（max_neili>=150 / force>=40 / staff>=baibian-daxue）与
  练招消耗 `practice_cost`（LPC 扣 qi 32 / neili 15，须持杖）已按 LPC 迁移（2026-10-30）。
  LPC 的「须持杖（weapon skill_type=="staff"）」检查未在 `valid_learn` 建模
  （由 practice 流程把关），招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「指点江山」，手中$w疾点向$n的期门穴!",
      "force" => 60,
      "dodge" => 20,
      "damage" => 22,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N吐气开声一招「银钩铁划」，$w如灵蛇吞吐，向$n白海穴戳去",
      "force" => 90,
      "dodge" => 15,
      "damage" => 28,
      "lvl" => 9,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N向前跨上一步，手中$w一晃，正是一招使出「灵蛇吐雾」，疾点$n的地仓穴",
      "force" => 120,
      "dodge" => 10,
      "damage" => 32,
      "lvl" => 19,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中的$w左右急晃，舞成一段光芒，使出「千变万化」带着呼呼风声笼罩了$n的章门穴",
      "force" => 140,
      "dodge" => 8,
      "damage" => 38,
      "lvl" => 29,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N飞身跃起，一式「千蛇出洞」，卷起漫天笔影，紧紧裹住$n",
      "force" => 160,
      "dodge" => 15,
      "damage" => 44,
      "lvl" => 39,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N凝气守中，$w逼出阵阵光芒，挥出「灵台观景」，一招快一招地攻向$n",
      "force" => 190,
      "dodge" => 12,
      "damage" => 49,
      "lvl" => 59,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N使出一招「神蛇引路」挺笔中宫直进，$w忽的颤动，中途忽然转而向上变幻无方",
      "force" => 230,
      "dodge" => 5,
      "damage" => 53,
      "lvl" => 79,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N侧身手中的$w斜刺，一招「奇采迭出」，刺向$n胸前檀中大穴",
      "force" => 250,
      "dodge" => 15,
      "damage" => 58,
      "lvl" => 99,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "baibian-daxue"

  @impl true
  def valid_enable(usage), do: usage in ["staff", "parry"]

  # LPC valid_learn 要求 max_neili>=150 / force>=40 / staff>=baibian-daxue（须持杖检查由 practice 流程把关）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      not is_nil(max_neili) and max_neili < 150 ->
        {:error, "你的内力不够，没有办法练百变打穴法。\n"}

      Stats.skill(stats, "force") < 40 ->
        {:error, "你的内功火候不够，还不能学习百变打穴法!\n"}

      Stats.skill(stats, "staff") < Stats.skill(stats, id()) ->
        {:error, "你的基本杖法水平有限，无法领会更高深的百变打穴杖法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 32 / neili 15（须持杖，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 32, neili: 15}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"dian" => Kantele.Combat.Skills.Performs.BaibianDaxue.Dian}
  end
  def actions(), do: @actions

end

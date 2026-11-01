defmodule Kantele.Combat.Skills.PangenCuojiefu do
  @moduledoc """
  盘根错节斧（对照 `kungfu/skill/pangen-cuojiefu.c`）

  斧/锤法载体：`valid_enable("hammer")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/pangen_cuojiefu/`。

  学习门槛 `valid_learn/2`（force>=50 / max_neili>=600 / hammer>=30 / hammer>=self）与练招消耗
  `practice_cost`（qi 80 / neili 52）已按 LPC 迁移（2026-10-30）。须持锤检查由 practice 流程把关；招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N蓦地腾空跃起，双手紧握$w，对准$n的头顶，自上而下地砍了下去，只\n在半空中留下一团巨大的黑影",
      "force" => 100,
      "dodge" => -5,
      "parry" => -10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "砍伤"
    },
    %{
      "action" => "$N突然发一声喊，冲前两步，手中$w由下而上反撩$n下三路，顿时只见道\n淡黄色的气影逼向$n，情知不妙，急忙招架",
      "force" => 130,
      "dodge" => -10,
      "parry" => -10,
      "damage" => 40,
      "lvl" => 10,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N忽然虎吼一声，闪身斜向左前方冲出一步，身体微晃，手中$w在空中划\n出一道淡影，急速横扫$n的右肩，气势迫人",
      "force" => 160,
      "dodge" => -20,
      "parry" => -15,
      "damage" => 50,
      "lvl" => 20,
      "damage_type" => "砍伤"
    },
    %{
      "action" => "$N突然抽身向右滚倒，随即跳起，就在一瞬间，已单臂握着$w砸向$n的左\n肋，出手既快且狠",
      "force" => 180,
      "dodge" => -35,
      "parry" => -10,
      "damage" => 60,
      "lvl" => 30,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N双手横举$w，平扫$n前胸，招式未使老就已打住猝然变招，斧尖直直撞\n向$n的小腹，",
      "force" => 210,
      "dodge" => -40,
      "parry" => -20,
      "damage" => 70,
      "lvl" => 42,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N不急不缓地转身微蹲，$n见$N露出破绽，急忙抢攻，却突然发现$N的\n身体已转过来，手中$w正迅猛地扫向自己的下盘",
      "force" => 240,
      "dodge" => -30,
      "parry" => -20,
      "damage" => 90,
      "lvl" => 55,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N身形微动，就在同一时间自上中下左右砍出五斧，$n见五把$w从不同的\n方位砍向自己，一时间竟不知该如何招架",
      "force" => 280,
      "dodge" => -25,
      "parry" => -40,
      "damage" => 110,
      "lvl" => 68,
      "damage_type" => "砍伤"
    },
    %{
      "action" => "$N前脚猛地往地上一顿，大地也微微一震，接着举起斧头在头顶急转数圈，$w\n就隐含风云之声平直而沉稳地袭向$n",
      "force" => 310,
      "dodge" => -50,
      "parry" => -30,
      "damage" => 150,
      "lvl" => 80,
      "damage_type" => "砍伤"
    }
  ]

  @impl true
  def id(), do: "pangen-cuojiefu"

  @impl true
  def valid_enable(usage), do: usage in ["hammer", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 50 ->
        {:error, "你的内功火候不够，无法学盘根错节斧。\n"}

      not is_nil(max_neili) and max_neili < 600 ->
        {:error, "你的内力修为太弱，无法练盘根错节斧。\n"}

      Stats.skill(stats, "hammer") < 30 ->
        {:error, "你的基本锤法等级太低，无法学盘根错节斧。\n"}

      Stats.skill(stats, "hammer") < Stats.skill(stats, id()) ->
        {:error, "你的基本锤法水平有限，无法领会更高深的盘根错节斧。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili), do: max_neili
  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 80 / neili 52（须持锤，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 80, neili: 52}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"cuo" => Kantele.Combat.Skills.Performs.PangenCuojiefu.Cuo}
  end
  def actions(), do: @actions

end

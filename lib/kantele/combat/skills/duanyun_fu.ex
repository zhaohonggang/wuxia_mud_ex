defmodule Kantele.Combat.Skills.DuanyunFu do
  @moduledoc """
  断云拂法（对照 `kungfu/skill/duanyun-fu.c`）

  斧法载体：`valid_enable("axe")` / `valid_enable("parry")`（LPC `usage=="axe" || usage=="parry"`；
  旧版本误作 `club`，已按 LPC 修正）。

  绝招实现见 `lib/kantele/combat/skills/performs/duanyun_fu/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn`（force>=20 / max_neili>=150）已按 LPC 迁移。
  - LPC `practice_skill` 的「须持斧（`skill_type=="axe"`）」检查由 practice 流程把关，未写入
    `valid_learn`；扣 `qi` 80、`receive_damage("neili", -12)`（**负伤害 = 回 12 点内力**，
    LPC 原样 bug），`practice_cost` 只能表达非负消耗，故 neili 记 0（实际效果是回内）。
  - 招式表未建模（绝招见 `performs/duanyun_fu/`）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N蓦地腾空跃起，双手紧握$w，对准$n的头顶，自上而下地砍了下去，只在半空中留下一团巨大的黑影",
      "dodge" => -5,
      "parry" => -10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "砍伤"
    },
    %{
      "action" => "$N突然发一声喊，冲前两步，手中$w由下而上反撩$n下三路，$n见到一道淡黄色的气影逼向自己，情知不妙，急忙招架",
      "dodge" => -10,
      "parry" => -10,
      "damage" => 40,
      "lvl" => 10,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N忽然虎吼一声，闪身斜向左前方冲出一步，身体微晃，手中$w在空中划出一道淡影，急速横扫$n的右肩，气势迫人",
      "dodge" => -20,
      "parry" => -15,
      "damage" => 50,
      "lvl" => 20,
      "damage_type" => "砍伤"
    },
    %{
      "action" => "$N突然抽身向右滚倒，随即跳起，就在跳起的一瞬间，已单臂握着$w砸向$n的左肋，出手既快且狠",
      "dodge" => -35,
      "parry" => -10,
      "damage" => 60,
      "lvl" => 30,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N双手横举$w，平扫$n前胸，招式未使老就已打住猝然变招，斧尖直撞$n的小腹，",
      "dodge" => -40,
      "parry" => -20,
      "damage" => 70,
      "lvl" => 42,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N不急不缓地转身微蹲，$n见$N露出破绽，急忙抢攻，却突然发现$N的身体已转过来，手中$w正迅猛地扫向自己的下盘",
      "dodge" => -30,
      "parry" => -20,
      "damage" => 90,
      "lvl" => 55,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N身形微动，就在同一时间自上中下左右砍出五斧，$n见五把$w从不同的方位砍向自己，一时间竟不知该如何招架",
      "dodge" => -25,
      "parry" => -40,
      "damage" => 110,
      "lvl" => 68,
      "damage_type" => "砍伤"
    },
    %{
      "action" => "$N前脚猛地往地上一顿，大地也微微一震，接着举起斧头在头顶急转数圈，$w就隐含风云之声平直而沉稳地袭向$n，$n无论向何处闪躲，总看见斧尖离自己不到一尺，不由大惊失色",
      "dodge" => -50,
      "parry" => -30,
      "damage" => 150,
      "lvl" => 80,
      "damage_type" => "砍伤"
    }
  ]

  @impl true
  def id(), do: "duanyun-fu"

  @impl true
  def valid_enable(usage), do: usage in ["axe", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功心法火候不够，无法学断云斧。\n"}

      not is_nil(max_neili) and max_neili < 150 ->
        {:error, "你的内力太弱，无法练断云斧。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "LPC practice_skill 扣 qi 80（neili 侧原样为回内，记 0）"
  @impl true
  def practice_cost(), do: %{qi: 80, neili: 0}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{"tiaoyan" => Kantele.Combat.Skills.Performs.DuanyunFu.Tiaoyan}
  end
  def actions(), do: @actions

end

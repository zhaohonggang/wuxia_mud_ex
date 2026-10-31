defmodule Kantele.Combat.Skills.BingcanDuzhang do
  @moduledoc """
  武学实装「bingcan-duzhang」（源 bingcan-duzhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/bingcan_duzhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.PoisonHit

  @actions [
    %{
      "action" => "$N脸上露出诡异的笑容，双掌携满寒霜，横扫$n",
      "force" => 430,
      "attack" => 79,
      "parry" => -37,
      "dodge" => -30,
      "damage" => 52,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N突然身形旋转起来扑向$n，双掌飞舞着拍向$n的$l",
      "force" => 490,
      "attack" => 96,
      "parry" => -34,
      "dodge" => -22,
      "damage" => 67,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N将冰蚕寒毒运至右手，阴毒无比地拍向$n的$l",
      "force" => 530,
      "attack" => 113,
      "parry" => 10,
      "dodge" => -20,
      "damage" => 82,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N诡异的一笑，双掌带着凌厉的寒气拍向$n的$l",
      "force" => 580,
      "attack" => 139,
      "parry" => 36,
      "dodge" => 28,
      "damage" => 95,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N仰天一声长啸，聚集全身的力量击向$n",
      "force" => 640,
      "attack" => 161,
      "parry" => 21,
      "dodge" => 27,
      "damage" => 105,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "bingcan-duzhang"

  # LPC hit_ob：lvl>=80 且 jiali>=10 且 damage!=0，`jiali*2 + random(lvl)`
  # 压过对手 force 时上「冰蚕寒毒」（duration = lvl/100 + random(lvl/10)）。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    PoisonHit.strike(attacker, victim, damage, rng,
      skill: id(),
      cnd: "bingcan_duzhang",
      msg: "$n只感一阵极寒从心底升起，看来是中了$N掌上的冰蚕寒毒。\n",
      div1: 100,
      div2: 10
    )
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 180}

  # LPC `valid_learn(object me)`（源 bingcan-duzhang.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "yijinjing") < 0 ->
        {:error, "你所修的内功无法练冰蚕毒掌。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候不够，无法练冰蚕毒掌。\n"}

      not is_nil(max_neili) and max_neili < 3000 ->
        {:error, "你的内力太弱，无法练冰蚕毒掌。"}

      Stats.skill(stats, "strike") < lvl ->
        {:error, "你的基本掌法水平有限，无法领会更高深的冰蚕毒掌。\n"}

      Stats.skill(stats, "yijinjing") < lvl ->
        {:error, "你的易筋经神功水平有限，无法领会更高深的冰蚕毒掌。\n"}

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
end

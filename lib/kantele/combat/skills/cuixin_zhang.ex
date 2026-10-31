defmodule Kantele.Combat.Skills.CuixinZhang do
  @moduledoc """
  武学实装「cuixin-zhang」（源 cuixin-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/cuixin_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.PoisonHit

  @actions [
    %{
      "action" => "$N使出一招「百花凋零」，运掌如飞，招招直打$n的$l",
      "force" => 220,
      "attack" => 25,
      "parry" => 16,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "百花凋零"
    },
    %{
      "action" => "$N使出一招「万木皆枯」，双掌急运内力，带着凛冽的掌风直拍$n的$l",
      "force" => 280,
      "attack" => 55,
      "parry" => 19,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "万木皆枯"
    },
    %{
      "action" => "$N飞身一跃而起，一声怪叫，一招「魂飞魄散」，双掌铺天盖地般拍向$n",
      "force" => 340,
      "attack" => 67,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "魂飞魄散"
    },
    %{
      "action" => "$N惨然一声长啸，一招「收魂摄魄」，双掌猛然击下，直扑$n的要脉",
      "force" => 440,
      "attack" => 85,
      "parry" => 38,
      "dodge" => 20,
      "damage" => 60,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "收魂摄魄"
    },
    %{
      "action" => "$N大叫一声，骨骼一阵暴响，双臂忽然暴长数尺，一招「六阴追魂」直直攻向$n的$l",
      "force" => 470,
      "attack" => 90,
      "parry" => 43,
      "dodge" => 40,
      "damage" => 65,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "六阴追魂"
    },
    %{
      "action" => "$N一招「裂骨催心」，双掌缤纷拍出，化出满天掌影，陡然间一掌已迅捷无比的拍向$n",
      "force" => 480,
      "attack" => 126,
      "parry" => 55,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "裂骨催心"
    }
  ]

  @impl true
  def id(), do: "cuixin-zhang"

  # LPC hit_ob：lvl>=80 且 jiali>=10 且 damage!=0，`jiali*2 + random(lvl)`
  # 压过对手 force 时上「催心掌掌力」（duration = lvl/100 + random(lvl/10)）。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    PoisonHit.strike(attacker, victim, damage, rng,
      skill: id(),
      cnd: "cuixin_zhang",
      msg: "只听$n闷哼了一声，看来是受到了催心掌掌劲的干扰！\n",
      div1: 100,
      div2: 10
    )
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike", "unarmed"]

  # LPC valid_learn：空手 / force>=100 / max_neili>=1200 / unarmed>=100 且 >=本技能 /
  # strike>=100 且 >=本技能。空手检查未建模（character 快照不含持械，见 MEMORY）。
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功太差，无法练习催心掌。\n"}

      not is_nil(max_neili) and max_neili < 1200 ->
        {:error, "你的内力修为太浅，无法练习催心掌。\n"}

      Stats.skill(stats, "unarmed") < 100 ->
        {:error, "你的基本拳脚有限，无法体会催心掌的要诣。\n"}

      Stats.skill(stats, "unarmed") < Stats.skill(stats, id()) ->
        {:error, "你的基本拳脚水平有限，无法领会更高深的催心掌。\n"}

      Stats.skill(stats, "strike") < 100 ->
        {:error, "你的基本掌法太差，无法领会催心掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法火候不够，无法领会更高深的催心掌。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 120}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> Map.get(action, "skill_name")
    end
  end

  @impl true
  def perform_list() do
    %{
      "cui" => Kantele.Combat.Skills.Performs.CuixinZhang.Cui
    }
  end
end

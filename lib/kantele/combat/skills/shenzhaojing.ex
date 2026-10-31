defmodule Kantele.Combat.Skills.Shenzhaojing do
  @moduledoc """
  武学实装「shenzhaojing」（源 shenzhaojing.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, perform_action_file, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shenzhaojing/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Engine

  @actions [
    %{
      "action" => "$N倏然跃近，击出一拳，这一拳无声无影，去势快极，向$n的胸口打去",
      "force" => 323,
      "attack" => 119,
      "parry" => 94,
      "dodge" => 81,
      "damage" => 68,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N丝毫不动声色，右掌平伸，左掌运起神照经神功的劲力，呼的一声拍向$n",
      "force" => 362,
      "attack" => 138,
      "parry" => 51,
      "dodge" => 73,
      "damage" => 73,
      "lvl" => 200,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身形微微一展，已然游走至$n跟前，陡然间双掌齐施，向$n猛拍而去",
      "force" => 389,
      "attack" => 152,
      "parry" => 53,
      "dodge" => 78,
      "damage" => 87,
      "lvl" => 220,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N退后一步，双掌回收，凌空划出一个圆圈，顿时一股澎湃的气劲直涌$n而出",
      "force" => 410,
      "attack" => 163,
      "parry" => 67,
      "dodge" => 75,
      "damage" => 93,
      "lvl" => 250,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "shenzhaojing"

  # LPC hit_ob（唯一「既追加创伤又上毒」的一条）：damage>=160、lvl>=180、
  # neili>=300、空手、force/unarmed 双映射都是本技能时，`damage/6 > 对手 con`
  # 则 receive_wound("qi", (damage-100)/3) 并上「神照经内劲」
  # （duration = lvl/100 + random(lvl/10)）。
  #
  # 未建模：`query_skill_prepared("unarmed")`（本引擎无 prepare 槽），
  # 以及 `query_temp("secondary_weapon")`（只有主手 weapon_name）。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    lvl = Map.get(attacker.skills, id(), 0)

    blocked? =
      damage < 160 or lvl < 180 or attacker.neili < 300 or attacker.weapon_name != nil or
        Map.get(attacker.mapped, "force") != id() or
        Map.get(attacker.mapped, "unarmed") != id()

    if blocked? do
      {0, nil}
    else
      if div(damage, 6) > victim.con do
        flvl = attacker.jiali

        {div(damage - 100, 3),
         "$n一声惨嚎，全身骨骼格格格格爆声不绝，肋骨、臂骨、腿骨同时断折。\n",
         [
           {"shenzhao",
            %{
              "level" => flvl + Engine.rand(rng, flvl),
              "id" => attacker.id,
              "duration" => div(lvl, 100) + Engine.rand(rng, div(lvl, 10))
            }}
         ]}
      else
        {0, nil}
      end
    end
  end

  # LPC 生效的那条 `valid_enable` 只允许 "force"（文件里另一条把
  # unarmed/parry 也放开的版本被 `}*/` 注释掉了）。
  @impl true
  def valid_enable(usage), do: usage == "force"

  # LPC valid_learn：性别「无性」且本技能>29 拒绝 / force>=200 / max_neili>=4000 /
  # force>=本技能 / 末了 `return ::valid_learn(me)`（FORCE 基类 = 恒 1）。
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      gender_of(character) == "无性" and Stats.skill(stats, id()) > 29 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的神照经神功。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的基本内功火候不足，不能学神照经神功。\n"}

      not is_nil(max_neili) and max_neili < 4000 ->
        {:error, "你的内力修为不足，不能学神照经神功。\n"}

      Stats.skill(stats, "force") < Stats.skill(stats, id()) ->
        {:error, "你的基本内功水平不够，难以锻炼更深厚的神照经神功。\n"}

      true ->
        :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  # LPC practice_skill 恒返回 notify_fail("神照经神功只能用学(learn)的来增加熟练度。\n")
  # → `nil`（本引擎语义：只能用学(learn)的来增加熟练度）
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "wu" => Kantele.Combat.Skills.Performs.Shenzhaojing.Wu,
      "ying" => Kantele.Combat.Skills.Performs.Shenzhaojing.Ying
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.Shenzhaojing.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.Shenzhaojing.Shield
    }
  end
end

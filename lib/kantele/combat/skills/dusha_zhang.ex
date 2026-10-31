defmodule Kantele.Combat.Skills.DushaZhang do
  @moduledoc """
  武学实装「dusha-zhang」（源 dusha-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/dusha_zhang/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.PoisonHit

  @actions [
    %{
      "action" => "$N双手不住地忽伸忽缩，手臂关节喀喇声响，右掌一立，左掌啪的一下朝$n$l击去",
      "force" => 80,
      "attack" => 28,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 60,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形挫动，风声虎虎，接着朝$n连发八掌，一掌快似一掌，一掌猛似一掌",
      "force" => 130,
      "attack" => 35,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 67,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N攸地变爪为掌，身子不动，右臂陡长，潜运内力，一掌朝$n$l劈去",
      "force" => 170,
      "attack" => 37,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 65,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一声怪啸，形如飘风，左掌已如风行电挚般拍向$n，掌未到，风先至，迅猛已极",
      "force" => 220,
      "attack" => 42,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 73,
      "lvl" => 90,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "dusha-zhang"

  # LPC hit_ob：lvl>=80 且 jiali>=10 且 damage!=0，`jiali*2 + random(lvl)`
  # 压过对手 force 时上「砂毒」（duration = lvl/50 + random(lvl/20)）。
  @impl true
  def hit_ob(attacker, victim, damage, _factor, rng) do
    PoisonHit.strike(attacker, victim, damage, rng,
      skill: id(),
      cnd: "sha_poison",
      msg: "$n忽然感到一股莫名的恶心，全身瘫软，嘴皮乌紫。\n"
    )
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  # LPC valid_learn：空手 / force>=100 / max_neili>=450 / strike>=本技能。
  # 空手检查未建模（character 快照不含持械，见 MEMORY）。
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不够，无法练毒砂掌。\n"}

      not is_nil(max_neili) and max_neili < 450 ->
        {:error, "你的内力太弱，无法练毒砂掌。\n"}

      Stats.skill(stats, "strike") < Stats.skill(stats, id()) ->
        {:error, "你的基本掌法水平有限，无法领会更高深的毒砂掌。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 60}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

defmodule Kantele.Combat.Skills.YanqingQuan do
  @moduledoc """
  武学实装「yanqing-quan」（源 yanqing-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill
  - perform/exert 路由骨架见 tmp/perf_out/yanqing_quan/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "只见$N飞身一纵，一招「燕子渡水」凌空一拳打向$n的$l",
      "force" => 120,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N步履一沉，左拳拉开，右拳带风，一招「燕尾手」势不可挡地击向$n$l",
      "force" => 140,
      "attack" => 30,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "只见$N拉开架式，一招「掠水掌」使得虎虎有风。底下却飞起一脚踢向$n$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一个转身，左掌护胸，右掌使了个「百花齐放」往$n当头一拳",
      "force" => 270,
      "attack" => 40,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "只见$N拉开架式，一招「平推掌」使得虎虎有风，数只手掌一齐击向$n的$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一个转身，左掌护胸，右掌使了个「燕青逸翔」往$n当头拂过",
      "force" => 270,
      "attack" => 40,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "砸伤"
    }
  ]

  @impl true
  def id(), do: "yanqing-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 50}

  # LPC `valid_learn(object me)`（源 yanqing-quan.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())

    cond do
      Stats.skill(stats, "baihua-cuoquan") > 0 ->
        {:error, "你已经练成了百花错拳，不必再单独学习了。\n"}

      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练燕青拳必须空手。\n"}

      Stats.skill(stats, "unarmed") < lvl ->
        {:error, "你的基本拳脚火候不足，无法领会更高深的燕青拳。\n"}

      Stats.skill(stats, "cuff") < lvl ->
        {:error, "你的拳法根基火候不足，无法领会更高深的燕青拳。\n"}

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

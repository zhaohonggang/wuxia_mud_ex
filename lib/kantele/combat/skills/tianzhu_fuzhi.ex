defmodule Kantele.Combat.Skills.TianzhuFuzhi do
  @moduledoc """
  武学实装「tianzhu-fuzhi」（源 tianzhu-fuzhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 5 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tianzhu_fuzhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N侧身抬臂，右指划了个半圈，轻轻拂向向$n$l，不着力道",
      "force" => 100,
      "attack" => 10,
      "parry" => 15,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "点穴"
    },
    %{
      "action" => "$N左掌虚托，右手中指穿腋疾出，轻拂$n胸前的诸多要穴",
      "force" => 140,
      "attack" => 15,
      "parry" => 18,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "点穴"
    },
    %{
      "action" => "$N俯身斜倚，左手半推，右手中指和食指向$n的$l轻轻拂过",
      "force" => 170,
      "attack" => 20,
      "parry" => 25,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "点穴"
    },
    %{
      "action" => "$N双目微睁，双手十指幻化出千百个指影，拂向$n的$l",
      "force" => 210,
      "attack" => 28,
      "parry" => 30,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "点穴"
    },
    %{
      "action" => "只见$N左掌护住丹田，右手斜指苍天，蓄势点向$n的$l",
      "force" => 250,
      "attack" => 30,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 80,
      "damage_type" => "点穴"
    }
  ]

  @impl true
  def id(), do: "tianzhu-fuzhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

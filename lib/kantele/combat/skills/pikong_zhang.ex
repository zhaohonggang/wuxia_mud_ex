defmodule Kantele.Combat.Skills.PikongZhang do
  @moduledoc """
  武学实装「pikong-zhang」（源 pikong-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pikong_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双掌一错，一招「雨疾风狂」，狂风般扫向$n的$l",
      "force" => 100,
      "attack" => 18,
      "parry" => 15,
      "dodge" => 30,
      "damage" => 40,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一招「残霞满天」，身形突然旋转起来扑向$n，双掌拍向$n的$l",
      "force" => 200,
      "attack" => 25,
      "parry" => 30,
      "dodge" => 40,
      "damage" => 45,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N将内力运至左手，一招「缤纷落影」，迅疾无比地抓向$n的$l",
      "force" => 250,
      "attack" => 35,
      "parry" => 55,
      "dodge" => 50,
      "damage" => 45,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N后退一步，突然一招「掌打飞花」，掌力拍向$n的$l",
      "force" => 330,
      "attack" => 42,
      "parry" => 65,
      "dodge" => 40,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    }
  ]

  @impl true
  def id(), do: "pikong-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 54}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

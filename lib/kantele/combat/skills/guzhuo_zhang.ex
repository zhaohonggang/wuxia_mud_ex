defmodule Kantele.Combat.Skills.GuzhuoZhang do
  @moduledoc """
  武学实装「guzhuo-zhang」（源 guzhuo-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/guzhuo_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一声大喝，左掌叠于右掌之上，劈向$n",
      "force" => 100,
      "attack" => 2,
      "parry" => 1,
      "dodge" => 30,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N面色凝重，双掌轻抖，飘忽不定地拍向$n",
      "force" => 130,
      "attack" => 8,
      "parry" => 3,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 20,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N气沉丹田，双掌幻化一片掌影，将$n笼罩于内。",
      "force" => 160,
      "attack" => 12,
      "parry" => 4,
      "dodge" => 43,
      "damage" => 35,
      "lvl" => 40,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N跨前一步，右掌中攻直进，向$n的$l连击三掌",
      "force" => 210,
      "attack" => 15,
      "parry" => 8,
      "dodge" => 55,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N沉身顿气，贯出双掌，顿时只见一片掌影攻向$n",
      "force" => 250,
      "attack" => 22,
      "parry" => 0,
      "dodge" => 52,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N双掌平挥，猛击向$n的$l，毫无半点花巧可言",
      "force" => 300,
      "attack" => 23,
      "parry" => 11,
      "dodge" => 65,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N体内真气迸发，双掌缤纷拍出，顿时一片掌影笼罩$n",
      "force" => 310,
      "attack" => 28,
      "parry" => 5,
      "dodge" => 63,
      "damage" => 80,
      "lvl" => 120,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N左掌虚晃，右掌携着千钧之力猛然向$n的头部击落",
      "force" => 330,
      "attack" => 25,
      "parry" => 12,
      "dodge" => 77,
      "damage" => 90,
      "lvl" => 140,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N身子蓦的横移，右手横扫$n的$l，左手攻向$n的胸口",
      "force" => 360,
      "attack" => 31,
      "parry" => 15,
      "dodge" => 80,
      "damage" => 100,
      "lvl" => 160,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N陡然一声暴喝，真气迸发，双掌同时击向$n的$l",
      "force" => 400,
      "attack" => 32,
      "parry" => 10,
      "dodge" => 81,
      "damage" => 130,
      "lvl" => 180,
      "damage_type" => "内伤"
    }
  ]

  @impl true
  def id(), do: "guzhuo-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 81, neili: 73}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

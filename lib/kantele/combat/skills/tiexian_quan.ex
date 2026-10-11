defmodule Kantele.Combat.Skills.TiexianQuan do
  @moduledoc """
  武学实装「tiexian-quan」（源 tiexian-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tiexian_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "只见$N身形一矮，施一招「赤胆忠心」对准$n的呼地砸了过去",
      "force" => 120,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N左拳拉开，右拳带风，一招「忠心耿耿」势不可挡地击向$n",
      "force" => 140,
      "attack" => 30,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "只见$N拉开架式，双拳带风，施一招「铁门闸」蓦地拍向$n而去",
      "force" => 160,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一个转身，左掌护胸，右掌使出「直来直去」往$n当头一拳",
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
  def id(), do: "tiexian-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 22}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "tui" => Kantele.Combat.Skills.Performs.TiexianQuan.Tui
    }
  end
end

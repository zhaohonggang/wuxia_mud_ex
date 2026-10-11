defmodule Kantele.Combat.Skills.SuohouGong do
  @moduledoc """
  武学实装「suohou-gong」（源 suohou-gong.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/suohou_gong/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一声暴喝，双手如钩如戢，插向$n的$l",
      "force" => 100,
      "attack" => 28,
      "parry" => 0,
      "dodge" => 17,
      "damage" => 13,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N身形一跃，直扑而上，右手直直抓向$n的$l",
      "force" => 130,
      "attack" => 35,
      "parry" => 5,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 10,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，奋力抓向$n的$l",
      "force" => 160,
      "attack" => 39,
      "parry" => 10,
      "dodge" => 32,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N悄无声息的游走至$n身前，猛的一爪奋力抓向$n的$l",
      "force" => 172,
      "attack" => 42,
      "parry" => 19,
      "dodge" => 38,
      "damage" => 29,
      "lvl" => 40,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N双手平提胸前，左手护住面门，右手陡然抓向$n的$l",
      "force" => 187,
      "attack" => 45,
      "parry" => 21,
      "dodge" => 41,
      "damage" => 33,
      "lvl" => 60,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N低喝一声，双手化掌为爪，一前一后抓向$n的$l",
      "force" => 203,
      "attack" => 51,
      "parry" => 22,
      "dodge" => 49,
      "damage" => 36,
      "lvl" => 80,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N右腿斜插$n二腿之间，上手取目，下手直勾$n的喉部",
      "force" => 245,
      "attack" => 56,
      "parry" => 27,
      "dodge" => 53,
      "damage" => 41,
      "lvl" => 100,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N狂喝一声，双爪如狂风骤雨般对准$n的$l连续抓出",
      "force" => 270,
      "attack" => 61,
      "parry" => 38,
      "dodge" => 58,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "suohou-gong"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 69}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "suo" => Kantele.Combat.Skills.Performs.SuohouGong.Suo
    }
  end
end

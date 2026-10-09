defmodule Kantele.Combat.Skills.YujiamuQuan do
  @moduledoc """
  武学实装「yujiamu-quan」（源 yujiamu-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yujiamu_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N并举双拳，使出一招「灌顶」，当头砸向$n的$l  ",
      "force" => 160,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "灌顶"
    },
    %{
      "action" => "$N使出一招「解苦」，身形一低，左手护顶，右手一拳击向$n的裆部  ",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "解苦"
    },
    %{
      "action" => "$N使出一招「颦眉」，左拳虚击$n的前胸，一错身，右拳横扫$n的太阳穴  ",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "颦眉"
    },
    %{
      "action" => "$N神形怪异，使一招「嗔恚」，双拳上下击向$n的$l  ",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "嗔恚"
    },
    %{
      "action" => "$N使出一招「静寂」，双拳交错，缓缓击出，劲气直指$n的$l  ",
      "force" => 270,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "静寂"
    },
    %{
      "action" => "$N微微一笑，使出一式「妙音」，双拳前后击出，直取$n的左胸  ",
      "force" => 300,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 0,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "妙音"
    },
    %{
      "action" => "$N使出一招「明心」，全身疾转，双拳横扫$n的$l  ",
      "force" => 310,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 140,
      "damage_type" => "瘀伤",
      "skill_name" => "明心"
    },
    %{
      "action" => "$N飞身一跃，使出一招「制胜」，一拳猛击$n咽喉  ",
      "force" => 330,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "制胜"
    }
  ]

  @impl true
  def id(), do: "yujiamu-quan"

  @impl true
  def valid_enable(usage), do: usage in ["cuff", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 61}

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

end

defmodule Kantele.Combat.Skills.HuzhuaShou do
  @moduledoc """
  武学实装「huzhua-shou」（源 huzhua-shou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/huzhua_shou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "在呼呼风声中，$N使一招「虎口夺食」，双手如钩如戢，插向$n的$l",
      "force" => 100,
      "attack" => 28,
      "parry" => 0,
      "dodge" => 17,
      "damage" => 13,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "虎口夺食"
    },
    %{
      "action" => "$N身形一跃，费神扑上，使出一招「饿虎扑食」，右手直直抓向$n的$l",
      "force" => 130,
      "attack" => 35,
      "parry" => 5,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 10,
      "damage_type" => "抓伤",
      "skill_name" => "饿虎扑食"
    },
    %{
      "action" => "$N双手平伸，十指微微上下抖动，一招「山崩地裂」打向$n的$l",
      "force" => 160,
      "attack" => 39,
      "parry" => 10,
      "dodge" => 32,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "抓伤",
      "skill_name" => "山崩地裂"
    },
    %{
      "action" => "$N使出一招「夜黑风高」，悄无声息的游走至$n身前，猛的一爪奋力抓向$n的$l",
      "force" => 172,
      "attack" => 42,
      "parry" => 19,
      "dodge" => 38,
      "damage" => 29,
      "lvl" => 40,
      "damage_type" => "抓伤",
      "skill_name" => "夜黑风高"
    },
    %{
      "action" => "$N双手平提胸前，左手护住面门，一招「损筋断骨」右手推向$n的$l",
      "force" => 187,
      "attack" => 45,
      "parry" => 21,
      "dodge" => 41,
      "damage" => 33,
      "lvl" => 60,
      "damage_type" => "抓伤",
      "skill_name" => "损筋断骨"
    },
    %{
      "action" => "$N使出「恶林虎啸」，低喝一声，双手化掌为爪，一前一后抓向$n的$l",
      "force" => 203,
      "attack" => 51,
      "parry" => 22,
      "dodge" => 49,
      "damage" => 36,
      "lvl" => 80,
      "damage_type" => "抓伤",
      "skill_name" => "恶林虎啸"
    },
    %{
      "action" => "$N右腿斜插$n二腿之间，一招「虎爪绝户」，上手取目，下手反勾$n的裆部",
      "force" => 245,
      "attack" => 56,
      "parry" => 27,
      "dodge" => 53,
      "damage" => 41,
      "lvl" => 100,
      "damage_type" => "抓伤",
      "skill_name" => "虎爪绝户"
    },
    %{
      "action" => "$N使出「困兽犹斗」，双爪如狂风骤雨般对准$n的$l连续抓出",
      "force" => 270,
      "attack" => 61,
      "parry" => 38,
      "dodge" => 58,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "抓伤",
      "skill_name" => "困兽犹斗"
    }
  ]

  @impl true
  def id(), do: "huzhua-shou"

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
      "juehu" => Kantele.Combat.Skills.Performs.HuzhuaShou.Juehu
    }
  end
end

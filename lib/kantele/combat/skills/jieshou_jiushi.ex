defmodule Kantele.Combat.Skills.JieshouJiushi do
  @moduledoc """
  武学实装「jieshou-jiushi」（源 jieshou-jiushi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/jieshou_jiushi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N手掌交错，身行前探，一招「虚式分金」，掌风直劈向$n的$l",
      "force" => 120,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 35,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "虚式分金"
    },
    %{
      "action" => "$N身行斗转，一招「月落西山」，左手护肘，右手直击$n前胸",
      "force" => 140,
      "attack" => 15,
      "parry" => 7,
      "dodge" => 7,
      "damage" => 38,
      "lvl" => 20,
      "damage_type" => "抓伤",
      "skill_name" => "月落西山"
    },
    %{
      "action" => "$N轻喝一声，一招「顺水推舟」，身行不变，将右手迅间化掌，斜击$n的后腰。",
      "force" => 170,
      "attack" => 21,
      "parry" => 11,
      "dodge" => 11,
      "damage" => 43,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "顺水推舟"
    },
    %{
      "action" => "$N双手自外向内拗入，一招「铁锁横江」，去势奇快，向$n的$l劈去，",
      "force" => 190,
      "attack" => 25,
      "parry" => 13,
      "dodge" => 13,
      "damage" => 45,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "铁锁横江"
    },
    %{
      "action" => "$N衣袖轻摆,右手上封，左手下压，连削带打奔向$n的$l",
      "force" => 220,
      "attack" => 35,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 51,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "轻罗小扇"
    },
    %{
      "action" => "$N一招「黑沼灵狐」，左脚向前一个偷步，右手化掌向前划出,左手顺势反拍$n的面门",
      "force" => 240,
      "attack" => 55,
      "parry" => 18,
      "dodge" => 18,
      "damage" => 55,
      "lvl" => 130,
      "damage_type" => "瘀伤",
      "skill_name" => "黑沼灵狐"
    },
    %{
      "action" => "$N脚踩奇门，猛然跃到$n的身旁,一招「生死茫茫」，挥手打向$n的$l",
      "force" => 270,
      "attack" => 61,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 58,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "生死茫茫"
    },
    %{
      "action" => "$N手指微微作响，一招「高山流水」，掌影犹如飞瀑般将$n笼罩了起来",
      "force" => 310,
      "attack" => 75,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 65,
      "lvl" => 200,
      "damage_type" => "瘀伤",
      "skill_name" => "高山流水"
    },
    %{
      "action" => "$N突然愁眉紧缩，神态间散发万种风情，$n猛一惊讶，忽然感到一股排山倒海的掌风袭来",
      "force" => 340,
      "attack" => 85,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 71,
      "lvl" => 250,
      "damage_type" => "瘀伤",
      "skill_name" => "伊人消魂"
    }
  ]

  @impl true
  def id(), do: "jieshou-jiushi"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

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
      "jie" => Kantele.Combat.Skills.Performs.JieshouJiushi.Jie
    }
  end
end

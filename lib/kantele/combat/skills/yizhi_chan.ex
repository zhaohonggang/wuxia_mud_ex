defmodule Kantele.Combat.Skills.YizhiChan do
  @moduledoc """
  武学实装「yizhi-chan」（源 yizhi-chan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 4 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yizhi_chan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双指并拢，一式「佛恩济世」，和身而上，左右手一前一后戳向$n的胸腹间",
      "force" => 340,
      "attack" => 75,
      "parry" => 55,
      "dodge" => 35,
      "damage" => 22,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "佛恩济世"
    },
    %{
      "action" => "$N左掌护胸，一式「佛光普照」，右手中指前后划了个半弧，猛地一",
      "force" => 370,
      "attack" => 70,
      "parry" => 45,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "佛光普照"
    },
    %{
      "action" => "$N身形闪动，一式「佛门广渡」，双手食指端部各射出一道青气，射",
      "force" => 360,
      "attack" => 72,
      "parry" => 52,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "佛门广渡"
    },
    %{
      "action" => "$N盘膝跌坐，一式「佛法无边」，左手握拳托肘，右手拇指直立，遥",
      "force" => 380,
      "attack" => 68,
      "parry" => 48,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "佛法无边"
    }
  ]

  @impl true
  def id(), do: "yizhi-chan"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 62, neili: 68}

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

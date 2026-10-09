defmodule Kantele.Combat.Skills.HuaguMianzhang do
  @moduledoc """
  武学实装「huagu-mianzhang」（源 huagu-mianzhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/huagu_mianzhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形微晃，一招「长恨深入骨」，十指如戟，插向$n的双肩锁骨",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "内伤",
      "skill_name" => "长恨深入骨"
    },
    %{
      "action" => "$N出手如风，十指微微抖动，一招「素手裂红裳」抓向$n的前胸",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "素手裂红裳"
    },
    %{
      "action" => "$N双手忽隐忽现，一招「长风吹落尘」，鬼魅般地抓向$n的肩头",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "长风吹落尘"
    },
    %{
      "action" => "$N左手当胸画弧，右手疾出，一招「明月映流沙」，猛地抓向$n的额头",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "明月映流沙"
    },
    %{
      "action" => "$N使一招「森然动四方」，激起漫天的劲风，撞向$n",
      "force" => 240,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 25,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "森然动四方"
    },
    %{
      "action" => "$N面无表情，双臂忽左忽右地疾挥，使出「黯黯侵骨寒」，十指\\n",
      "force" => 260,
      "attack" => 0,
      "parry" => 5,
      "dodge" => 30,
      "damage" => 30,
      "lvl" => 100,
      "damage_type" => "内伤",
      "skill_name" => "黯黯侵骨寒"
    },
    %{
      "action" => "$N使出「黄沙飘惊雨」，蓦然游身而上，绕着$n疾转数圈，$n正眼\\n",
      "force" => 280,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 35,
      "lvl" => 120,
      "damage_type" => "内伤",
      "skill_name" => "黄沙飘惊雨"
    },
    %{
      "action" => "$N突然双手平举，$n一呆，正在猜测间，便见$N嗖的一下将双手\\n",
      "force" => 300,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 140,
      "damage_type" => "内伤",
      "skill_name" => "白骨无限寒"
    }
  ]

  @impl true
  def id(), do: "huagu-mianzhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 47}

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

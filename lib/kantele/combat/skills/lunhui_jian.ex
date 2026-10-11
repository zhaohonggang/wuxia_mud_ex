defmodule Kantele.Combat.Skills.LunhuiJian do
  @moduledoc """
  武学实装「lunhui-jian」（源 lunhui-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/lunhui_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N使一式「人间道」，手中$w嗡嗡微振，幻成一条疾光刺向$n的$l",
      "force" => 190,
      "attack" => 130,
      "parry" => 115,
      "dodge" => 110,
      "damage" => 115,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "人间道"
    },
    %{
      "action" => "$N错步上前，使出「畜生道」，剑意若有若无，$w淡淡地向$n的$l挥去",
      "force" => 240,
      "attack" => 150,
      "parry" => 125,
      "dodge" => 115,
      "damage" => 130,
      "lvl" => 40,
      "damage_type" => "割伤",
      "skill_name" => "畜生道"
    },
    %{
      "action" => "$N一式「饿鬼道」，纵身飘开数尺，运发剑气，手中$w遥摇指向$n的$l",
      "force" => 260,
      "attack" => 160,
      "parry" => 128,
      "dodge" => 125,
      "damage" => 140,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "饿鬼道"
    },
    %{
      "action" => "$N纵身轻轻跃起，一式「修罗道」，剑光如轮疾转，霍霍斩向$n的$l",
      "force" => 280,
      "attack" => 170,
      "parry" => 135,
      "dodge" => 120,
      "damage" => 155,
      "lvl" => 120,
      "damage_type" => "割伤",
      "skill_name" => "修罗道"
    },
    %{
      "action" => "$N手中$w中宫直进，一式「地狱道」，无声无息地对准$n的$l刺出一剑",
      "force" => 320,
      "attack" => 180,
      "parry" => 142,
      "dodge" => 125,
      "damage" => 160,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "地狱道"
    },
    %{
      "action" => "$N手中$w斜指苍天，剑芒吞吐，一式「天极道」，对准$n的$l斜斜击出",
      "force" => 360,
      "attack" => 185,
      "parry" => 151,
      "dodge" => 125,
      "damage" => 170,
      "lvl" => 200,
      "damage_type" => "刺伤",
      "skill_name" => "天极道"
    },
    %{
      "action" => "$N左指凌空虚点，右手$w逼出丈许雪亮剑芒，一式「六道轮回」翻转向$n",
      "force" => 390,
      "attack" => 190,
      "parry" => 159,
      "dodge" => 130,
      "damage" => 175,
      "lvl" => 240,
      "damage_type" => "刺伤",
      "skill_name" => "六道轮回"
    }
  ]

  @impl true
  def id(), do: "lunhui-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 100, neili: 120}

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
      "hui" => Kantele.Combat.Skills.Performs.LunhuiJian.Hui
    }
  end
end

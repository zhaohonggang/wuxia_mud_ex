defmodule Kantele.Combat.Skills.YunlongJian do
  @moduledoc """
  武学实装「yunlong-jian」（源 yunlong-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 13 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yunlong_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "\\n$N使一式「悠悠顺自然」，手中$w嗡嗡微振，幻成一条白光刺向$n的$l",
      "force" => 40,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 8,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "悠悠顺自然"
    },
    %{
      "action" => "\\n$N错步上前，使出「来去若梦行」，剑意若有若无，$w淡淡地向$n的$l挥去",
      "force" => 50,
      "attack" => 0,
      "parry" => 0,
      "dodge" => -10,
      "damage" => 10,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "来去若梦行"
    },
    %{
      "action" => "\\n$N一式「志当存高远」，纵身飘开数尺，运发剑气，手中$w遥摇指向$n的$l",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 12,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "志当存高远"
    },
    %{
      "action" => "$N纵身轻轻跃起，一式「表里俱澄澈」，剑光如水，一泻千里，洒向$n全身",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "表里俱澄澈"
    },
    %{
      "action" => "$N手中$w中宫直进，一式「随风潜入夜」，无声无息地对准$n的$l刺出一剑",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 18,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "随风潜入夜"
    },
    %{
      "action" => "$N手中$w一沉，一式「润物细无声」，无声无息地滑向$n的$l",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 120,
      "damage_type" => "割伤",
      "skill_name" => "润物细无声"
    },
    %{
      "action" => "\\n$N手中$w斜指苍天，剑芒吞吐，一式「云龙听梵音」，对准$n的$l斜斜击出",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 22,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "云龙听梵音"
    },
    %{
      "action" => "$N左指凌空虚点，右手$w逼出丈许雪亮剑芒，一式「万里一点红」刺向$n的咽喉",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "万里一点红"
    },
    %{
      "action" => "$N合掌跌坐，一式「我心化云龙」，$w自怀中跃出，如疾电般射向$n的胸口",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 30,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "我心化云龙"
    },
    %{
      "action" => "\\n$N呼的一声拔地而起，一式「日月与同辉」，$w幻出万道光影，将$n团团围住",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 165,
      "damage_type" => "内伤",
      "skill_name" => "日月与同辉"
    },
    %{
      "action" => "$N随风轻轻飘落，一式「清风知我意」，手中$w平指，缓缓拍向$n脸颊",
      "force" => 250,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 40,
      "lvl" => 170,
      "damage_type" => "内伤",
      "skill_name" => "清风知我意"
    },
    %{
      "action" => "$N剑尖微颤作龙吟，一招「高处不胜寒」，切骨剑气如飓风般裹向$n全身",
      "force" => 290,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 45,
      "lvl" => 175,
      "damage_type" => "内伤",
      "skill_name" => "高处不胜寒"
    },
    %{
      "action" => "$N募的使一招「红叶舞秋山」，顿时剑光中几朵血花洒向$n全身",
      "force" => 310,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 50,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "红叶舞秋山"
    }
  ]

  @impl true
  def id(), do: "yunlong-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 67}

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

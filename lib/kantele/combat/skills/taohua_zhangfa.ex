defmodule Kantele.Combat.Skills.TaohuaZhangfa do
  @moduledoc """
  武学实装「taohua-zhangfa」（源 taohua-zhangfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/taohua_zhangfa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N右手五指缓缓一收，一式「春风拂面」，五指忽然遥遥拂向$n，$n只觉得五",
      "force" => 40,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "春风拂面"
    },
    %{
      "action" => "$N突然纵身跃入半空，一式「落花无情」，双掌向下，疾扑$n的头顶",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 0,
      "lvl" => 10,
      "damage_type" => "内伤",
      "skill_name" => "落花无情"
    },
    %{
      "action" => "$N伸出右手并拢食指中指，捻个剑决，一式「寻花探柳」，直指$n的中盘",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "内伤",
      "skill_name" => "寻花探柳"
    },
    %{
      "action" => "$N突然抽身而退，接着一式「随风而逝」，平身飞起，双掌向$n的$l",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 0,
      "lvl" => 30,
      "damage_type" => "内伤",
      "skill_name" => "随风而逝"
    },
    %{
      "action" => "$N使一式「狂风卷叶」，全身突然飞速旋转，双掌忽前忽后，猛地拍向$n",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "内伤",
      "skill_name" => "狂风卷叶"
    },
    %{
      "action" => "$N前后一揉，一式「寸草不生」，双掌推出一股阴柔之力袭向$n的$1 ",
      "force" => 130,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 35,
      "damage" => 0,
      "lvl" => 50,
      "damage_type" => "内伤",
      "skill_name" => "寸草不生"
    },
    %{
      "action" => "$N双手食指和中指迅速和在一起，一式「摧花断叶」，一股强烈的气",
      "force" => 150,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 0,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "摧花断叶"
    },
    %{
      "action" => "$N使一式「天女散花」，双掌舞出无数圈劲气，一环环向$n的$l斫去 ",
      "force" => 170,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 35,
      "damage" => 0,
      "lvl" => 70,
      "damage_type" => "劈伤",
      "skill_name" => "天女散花"
    },
    %{
      "action" => "$N两掌在胸前合什，施展出「推波助澜」，双掌骤然分开，祭出两团光",
      "force" => 190,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 30,
      "damage" => 0,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "推波助澜"
    },
    %{
      "action" => "$N一式「落英缤纷」，双掌在胸前疾转数圈，不急不缓地推向$n。$n只",
      "force" => 210,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 35,
      "damage" => 0,
      "lvl" => 90,
      "damage_type" => "内伤",
      "skill_name" => "落英缤纷"
    }
  ]

  @impl true
  def id(), do: "taohua-zhangfa"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 30, neili: 5}

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

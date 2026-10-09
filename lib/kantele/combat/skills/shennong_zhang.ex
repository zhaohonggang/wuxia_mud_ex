defmodule Kantele.Combat.Skills.ShennongZhang do
  @moduledoc """
  武学实装「shennong-zhang」（源 shennong-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shennong_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N微一躬身，一招「混沌初开」，$w带着刺耳的吱吱声，擦地扫向$n的脚踝",
      "force" => 130,
      "attack" => 10,
      "parry" => 19,
      "dodge" => -5,
      "damage" => 20,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "混沌初开"
    },
    %{
      "action" => "$N一招「后羿射日」，右手托住杖端，左掌居中一击，令其凭惯性倒向$n的肩头",
      "force" => 140,
      "attack" => 15,
      "parry" => 15,
      "dodge" => -10,
      "damage" => 25,
      "lvl" => 20,
      "damage_type" => "挫伤",
      "skill_name" => "后羿射日"
    },
    %{
      "action" => "$N一招「夸父赶日」，飞身一跃而起，$w挥舞转动不停，逼得$n左闪右避，狼狈不堪",
      "force" => 150,
      "attack" => 20,
      "parry" => 19,
      "dodge" => -5,
      "damage" => 30,
      "lvl" => 40,
      "damage_type" => "挫伤",
      "skill_name" => "夸父赶日"
    },
    %{
      "action" => "$N一招「莫邪奠剑」，手中$w斜指苍天，呆呆地盯了一会，突然猛地一杖刺向$n的$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 22,
      "dodge" => -5,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "挫伤",
      "skill_name" => "莫邪奠剑"
    },
    %{
      "action" => "$N高举$w，猛然一声暴喝，杖端遥指$n，一招「大禹治水」，携着呼啸声贯向$n",
      "force" => 180,
      "attack" => 30,
      "parry" => 28,
      "dodge" => -15,
      "damage" => 50,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "大禹治水"
    },
    %{
      "action" => "$N一招「伏羲披靡」，身形一展，持杖狂挥，$w全力一击拦腰向$n劈去",
      "force" => 210,
      "attack" => 35,
      "parry" => 32,
      "dodge" => 5,
      "damage" => 57,
      "lvl" => 100,
      "damage_type" => "挫伤",
      "skill_name" => "伏羲披靡"
    },
    %{
      "action" => "$N面色庄严，一招「轩辕帝威」，端持$w，陡然间身形一晃，疾风般一杖凌空攻向$n而去",
      "force" => 240,
      "attack" => 40,
      "parry" => 37,
      "dodge" => -5,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "轩辕帝威"
    },
    %{
      "action" => "$N一招「化蛇易龙」，单手持杖，力注于腕，待$n攻来， $w猛地弹射而起，击向$n",
      "force" => 260,
      "attack" => 45,
      "parry" => 45,
      "dodge" => -5,
      "damage" => 71,
      "lvl" => 140,
      "damage_type" => "挫伤",
      "skill_name" => "化蛇易龙"
    },
    %{
      "action" => "$N一招「女娲补天」，猛然一个翻滚拔地而起，高举$w凌空打向$n的头部",
      "force" => 280,
      "attack" => 50,
      "parry" => 55,
      "dodge" => -5,
      "damage" => 70,
      "lvl" => 160,
      "damage_type" => "挫伤",
      "skill_name" => "女娲补天"
    },
    %{
      "action" => "$N一招「蚩尤戮血」，身不动，脚不移，$w却晃动不定，不偏不倚地倒插向$n的要穴",
      "force" => 310,
      "attack" => 55,
      "parry" => 58,
      "dodge" => -5,
      "damage" => 84,
      "lvl" => 180,
      "damage_type" => "挫伤",
      "skill_name" => "蚩尤戮血"
    },
    %{
      "action" => "$N高举$w，一招「盘古开天」，身形如鬼魅般飘出，对准$n的天灵盖一杖打下",
      "force" => 330,
      "attack" => 61,
      "parry" => 62,
      "dodge" => -5,
      "damage" => 90,
      "lvl" => 200,
      "damage_type" => "挫伤",
      "skill_name" => "盘古开天"
    },
    %{
      "action" => "$N一招「神农百草」，单腿独立，$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 350,
      "attack" => 65,
      "parry" => 67,
      "dodge" => -5,
      "damage" => 95,
      "lvl" => 220,
      "damage_type" => "挫伤",
      "skill_name" => "神农百草"
    }
  ]

  @impl true
  def id(), do: "shennong-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 85}

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

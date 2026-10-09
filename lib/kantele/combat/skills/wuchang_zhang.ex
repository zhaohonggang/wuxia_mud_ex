defmodule Kantele.Combat.Skills.WuchangZhang do
  @moduledoc """
  武学实装「wuchang-zhang」（源 wuchang-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/wuchang_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N微一躬身，一招「庸人自扰」，$w带着刺耳的吱吱声，擦地扫向$n的脚踝",
      "force" => 100,
      "attack" => 10,
      "parry" => 9,
      "dodge" => -5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "挫伤",
      "skill_name" => "庸人自扰"
    },
    %{
      "action" => "$N一招「想入非非」，右手托住杖端，左掌居中一击，令其凭惯性倒向$n的肩头",
      "force" => 110,
      "attack" => 15,
      "parry" => 15,
      "dodge" => -10,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "挫伤",
      "skill_name" => "想入非非"
    },
    %{
      "action" => "$N一招「六神不安」，举起$w乒乒乓乓地满地乱敲，让$n左闪右避，狼狈不堪",
      "force" => 120,
      "attack" => 20,
      "parry" => 19,
      "dodge" => -5,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "挫伤",
      "skill_name" => "六神不安"
    },
    %{
      "action" => "$N一招「面无人色」，举起$w，呆呆地盯了一会，突然猛地一杖打向$n的$l",
      "force" => 140,
      "attack" => 25,
      "parry" => 22,
      "dodge" => -5,
      "damage" => 20,
      "lvl" => 70,
      "damage_type" => "挫伤",
      "skill_name" => "面无人色"
    },
    %{
      "action" => "$N将$w顶住自己的胸膛，一端指向$n，一招「心惊肉跳」，大声叫喊着冲向$n",
      "force" => 160,
      "attack" => 30,
      "parry" => 28,
      "dodge" => -15,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "挫伤",
      "skill_name" => "心惊肉跳"
    },
    %{
      "action" => "$N一招「行尸走肉」，全身僵直，蹦跳着持杖前行，冷不防举杖拦腰向$n劈去",
      "force" => 180,
      "attack" => 35,
      "parry" => 32,
      "dodge" => 5,
      "damage" => 30,
      "lvl" => 90,
      "damage_type" => "挫伤",
      "skill_name" => "行尸走肉"
    },
    %{
      "action" => "$N面带戚色，一招「饮恨吞声」，趁$n说话间，一杖向$n张大的嘴巴捅了过去",
      "force" => 220,
      "attack" => 40,
      "parry" => 37,
      "dodge" => -5,
      "damage" => 40,
      "lvl" => 110,
      "damage_type" => "挫伤",
      "skill_name" => "饮恨吞声"
    },
    %{
      "action" => "$N一招「力不从心」，假意将$w摔落地上，待$n行来，一脚勾起，击向$n的$l",
      "force" => 250,
      "attack" => 45,
      "parry" => 45,
      "dodge" => -5,
      "damage" => 40,
      "lvl" => 120,
      "damage_type" => "挫伤",
      "skill_name" => "力不从心"
    },
    %{
      "action" => "$N伏地装死，一招「穷途没路」，一个翻滚，身下$w往横里打出，挥向$n的裆部",
      "force" => 280,
      "attack" => 50,
      "parry" => 55,
      "dodge" => -5,
      "damage" => 50,
      "lvl" => 130,
      "damage_type" => "挫伤",
      "skill_name" => "穷途没路"
    },
    %{
      "action" => "$N一招「呆若木鸡」，身不动，脚不移，$w却直飞半空，不偏不倚地砸向$n的$l",
      "force" => 310,
      "attack" => 55,
      "parry" => 58,
      "dodge" => -5,
      "damage" => 50,
      "lvl" => 140,
      "damage_type" => "挫伤",
      "skill_name" => "呆若木鸡"
    },
    %{
      "action" => "$N高举$w，一招「人鬼殊途」，身形如鬼魅般飘出，对准$n的天灵盖一杖打下",
      "force" => 330,
      "attack" => 61,
      "parry" => 62,
      "dodge" => -5,
      "damage" => 60,
      "lvl" => 150,
      "damage_type" => "挫伤",
      "skill_name" => "人鬼殊途"
    },
    %{
      "action" => "$N一招「我入地狱」，单腿独立，$w舞成千百根相似，根根砸向$n全身各处要害",
      "force" => 350,
      "attack" => 65,
      "parry" => 67,
      "dodge" => -5,
      "damage" => 60,
      "lvl" => 160,
      "damage_type" => "挫伤",
      "skill_name" => "我入地狱"
    }
  ]

  @impl true
  def id(), do: "wuchang-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "staff"]

  @impl true
  def practice_cost(), do: %{qi: 70, neili: 69}

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

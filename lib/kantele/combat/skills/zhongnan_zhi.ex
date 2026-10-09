defmodule Kantele.Combat.Skills.ZhongnanZhi do
  @moduledoc """
  武学实装「zhongnan-zhi」（源 zhongnan-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/zhongnan_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「剑指南山」，右手拇指直刺$n的$l",
      "force" => 30,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 10,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "剑指南山"
    },
    %{
      "action" => "$N使一招「天荒地老」，左手轻轻一挥，右手刺向$n的檀中大穴",
      "force" => 60,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 18,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "天荒地老"
    },
    %{
      "action" => "$N双掌翻飞，一招「海枯石烂」，暗藏玄机，中指戳向$n的$l",
      "force" => 110,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 16,
      "damage" => 12,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "海枯石烂"
    },
    %{
      "action" => "$N一声大喝，一式「大江东去」，双指齐出，攻向$n的胸口和$l",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 14,
      "damage" => 15,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "大江东去"
    },
    %{
      "action" => "$N连上数步，一招「乌雀南飞」，左掌劈向$n，右手却暗袭$n的$l",
      "force" => 170,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 22,
      "damage" => 25,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "乌雀南飞"
    },
    %{
      "action" => "$N双手不住晃动，缓缓逼近$n，一招「冰冻千里」，笼罩了$n的$l",
      "force" => 190,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 20,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "冰冻千里"
    },
    %{
      "action" => "$N一招「寿比南山」，手指不住晃动，不离$n的$l方寸之间",
      "force" => 210,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 30,
      "damage" => 20,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "寿比南山"
    }
  ]

  @impl true
  def id(), do: "zhongnan-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 11}

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

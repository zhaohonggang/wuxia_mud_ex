defmodule Kantele.Combat.Skills.TiexueDao do
  @moduledoc """
  武学实装「tiexue-dao」（源 tiexue-dao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/tiexue_dao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「黑龙现身」，$w有如黑龙在$n的周身旋游，勿快勿慢，变化若神",
      "force" => 40,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "割伤",
      "skill_name" => "黑龙现身"
    },
    %{
      "action" => "$N一招「万水千山」，左右腿一前一后，$w乱披风势向$n的$l斩去",
      "force" => 90,
      "attack" => 20,
      "parry" => 8,
      "dodge" => 10,
      "damage" => 5,
      "lvl" => 10,
      "damage_type" => "割伤",
      "skill_name" => "万水千山"
    },
    %{
      "action" => "$N纵身跃落，一招「横扫千里」，$w带着疾风呼的一声便向$n横扫过去",
      "force" => 140,
      "attack" => 25,
      "parry" => 12,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "割伤",
      "skill_name" => "横扫千里"
    },
    %{
      "action" => "$N一招「左右开弓」，$w大开大阖，左右并进，左右两刀向$n的两肩砍落",
      "force" => 190,
      "attack" => 30,
      "parry" => 15,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 50,
      "damage_type" => "割伤",
      "skill_name" => "左右开弓"
    },
    %{
      "action" => "$N手中$w自上而下，一招「百丈飞瀑」刀光流泻，如瀑布般砍向$n的头部",
      "force" => 240,
      "attack" => 35,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "割伤",
      "skill_name" => "百丈飞瀑"
    },
    %{
      "action" => "$N使出一招「直摧万马」，上劈下撩，左挡右开，如千军万马般罩向$n",
      "force" => 280,
      "attack" => 40,
      "parry" => 32,
      "dodge" => 15,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "直摧万马"
    },
    %{
      "action" => "$N带得刀风劲疾，一招「怪蟒翻身」，转身连刀带人往$n的$l的劈去",
      "force" => 290,
      "attack" => 45,
      "parry" => 35,
      "dodge" => 5,
      "damage" => 50,
      "lvl" => 120,
      "damage_type" => "割伤",
      "skill_name" => "怪蟒翻身"
    },
    %{
      "action" => "$N一招「上步劈山」，$w直直的劈出，一片流光般的刀影向$n的全身罩去",
      "force" => 320,
      "attack" => 50,
      "parry" => 45,
      "dodge" => 20,
      "damage" => 60,
      "lvl" => 150,
      "damage_type" => "割伤",
      "skill_name" => "上步劈山"
    }
  ]

  @impl true
  def id(), do: "tiexue-dao"

  @impl true
  def valid_enable(usage), do: usage in ["blade", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 58}

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

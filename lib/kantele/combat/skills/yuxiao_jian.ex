defmodule Kantele.Combat.Skills.YuxiaoJian do
  @moduledoc """
  武学实装「yuxiao-jian」（源 yuxiao-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yuxiao_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N漫步提腰，一招「英雄潇洒我独行」，飘然来至$n面前，随即手中$w微微\\n",
      "force" => 120,
      "attack" => 41,
      "parry" => 40,
      "dodge" => 31,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "英雄潇洒我独行"
    },
    %{
      "action" => "$N斜跨一步，使出一式「儿女情长只恨短」，手中$w挥舞出两道一长一短的\\n",
      "force" => 140,
      "attack" => 52,
      "parry" => 41,
      "dodge" => 42,
      "damage" => 12,
      "lvl" => 10,
      "damage_type" => "刺伤",
      "skill_name" => "儿女情长只恨短"
    },
    %{
      "action" => "$N一招「翩然离去不思归」，$w骤然出鞘又立刻回到剑鞘中，随即转身翩然\\n",
      "force" => 150,
      "attack" => 58,
      "parry" => 45,
      "dodge" => 43,
      "damage" => 20,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "翩然离去不思归"
    },
    %{
      "action" => "$N双手举剑向天，一招「傲立群雄无所惧」，$w带起阵阵惊雷，自上而下向\\n",
      "force" => 170,
      "attack" => 61,
      "parry" => 48,
      "dodge" => 48,
      "damage" => 25,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "傲立群雄无所惧"
    },
    %{
      "action" => "$N施展出「倾城一笑万人醉」，手握$w颔首微微一笑，$n只看得一呆，却见\\n",
      "force" => 190,
      "attack" => 68,
      "parry" => 51,
      "dodge" => 50,
      "damage" => 30,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "倾城一笑万人醉"
    },
    %{
      "action" => "$N左脚踏实，右脚虚点，一招「一曲奏毕愁肠结」，$w带着一团剑花，飘浮\\n",
      "force" => 200,
      "attack" => 71,
      "parry" => 55,
      "dodge" => 55,
      "damage" => 35,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "一曲奏毕愁肠结"
    },
    %{
      "action" => "$N一招「处子弄箫亦多情」，左手轻抚$w，随即猛地一弹，右手随即向前一\\n",
      "force" => 230,
      "attack" => 78,
      "parry" => 60,
      "dodge" => 62,
      "damage" => 40,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "处子弄箫亦多情"
    },
    %{
      "action" => "$N回身低首，神色黯然，一招「闻声哀怨断人肠」，$w剑尖游移不定地刺向\\n",
      "force" => 250,
      "attack" => 81,
      "parry" => 64,
      "dodge" => 65,
      "damage" => 70,
      "lvl" => 110,
      "damage_type" => "刺伤",
      "skill_name" => "闻声哀怨断人肠"
    },
    %{
      "action" => "$N坐手掩面，一招「彼将离兮泪涟涟」，$w斜向下划出，$n正迟疑间，却见\\n",
      "force" => 280,
      "attack" => 84,
      "parry" => 68,
      "dodge" => 75,
      "damage" => 69,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "彼将离兮泪涟涟"
    },
    %{
      "action" => "$N忽然面露微笑，一招「随音而舞笑开颜」，右手$w一闪，舞出三团剑花刺\\n",
      "force" => 300,
      "attack" => 88,
      "parry" => 70,
      "dodge" => 78,
      "damage" => 80,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "随音而舞笑开颜"
    },
    %{
      "action" => "$N左手食指疾点$w，一招「箫音有情人无情」，剑身发出一声龙吟，余音缭\\n",
      "force" => 330,
      "attack" => 91,
      "parry" => 72,
      "dodge" => 85,
      "damage" => 88,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "箫音有情人无情"
    },
    %{
      "action" => "$N右手微震，一招「箫声响毕情两断」，手中$w急颤，发出一阵震耳欲聋的\\n",
      "force" => 350,
      "attack" => 94,
      "parry" => 72,
      "dodge" => 85,
      "damage" => 100,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "箫声响毕情两断"
    }
  ]

  @impl true
  def id(), do: "yuxiao-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 66}

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
      "bihai" => Kantele.Combat.Skills.Performs.YuxiaoJian.Bihai,
      "qing" => Kantele.Combat.Skills.Performs.YuxiaoJian.Qing,
      "tian" => Kantele.Combat.Skills.Performs.YuxiaoJian.Tian
    }
  end
end

defmodule Kantele.Combat.Skills.XiuluoZhi do
  @moduledoc """
  武学实装「xiuluo-zhi」（源 xiuluo-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xiuluo_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左手一个虚晃，右指跟进，一招「割肉饲鹰」，右指击向$n的$l",
      "force" => 80,
      "attack" => 25,
      "parry" => 15,
      "dodge" => -5,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "割肉饲鹰"
    },
    %{
      "action" => "$N揉身而上，随后身形一矮，一式「投身饿虎」,试图拿住$n的周身大穴",
      "force" => 100,
      "attack" => 30,
      "parry" => 15,
      "dodge" => 0,
      "damage" => 65,
      "lvl" => 20,
      "damage_type" => "点穴",
      "skill_name" => "投身饿虎"
    },
    %{
      "action" => "$N面露凶光，一式「斫头谢天」,手指直击向$n的百汇大穴",
      "force" => 150,
      "attack" => 50,
      "parry" => 5,
      "dodge" => -15,
      "damage" => 100,
      "lvl" => 40,
      "damage_type" => "点穴",
      "skill_name" => "斫头谢天"
    },
    %{
      "action" => "$N摒指如刀，一招「折骨出髓」,双指划出一条刀路砍向$n的腰部",
      "force" => 150,
      "attack" => 30,
      "parry" => 25,
      "dodge" => 10,
      "damage" => 100,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "折骨出髓"
    },
    %{
      "action" => "$N忽然左腾右纵，双指连点，一招「挑身千灯」，一时间无数道劲气同时击向$n",
      "force" => 180,
      "attack" => 45,
      "parry" => 0,
      "dodge" => -15,
      "damage" => 120,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "挑身千灯"
    },
    %{
      "action" => "$N提起身形，一招「挖眼布施」,居高临下，以讯雷不及掩耳的速度功向$n",
      "force" => 180,
      "attack" => 35,
      "parry" => 0,
      "dodge" => -15,
      "damage" => 100,
      "lvl" => 100,
      "damage_type" => "割伤",
      "skill_name" => "挖眼布施"
    },
    %{
      "action" => "$N双指分左右两路，一招「剥皮书经」，分别点向$n两处大穴，令$n措不及防",
      "force" => 200,
      "attack" => 50,
      "parry" => 10,
      "dodge" => 15,
      "damage" => 120,
      "lvl" => 120,
      "damage_type" => "点穴",
      "skill_name" => "剥皮书经"
    },
    %{
      "action" => "$N一招「剜心决志」，一指对准自己，随后就地一个翻滚，右手食指戳向$n的$l",
      "force" => 220,
      "attack" => 60,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 130,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "剜心决志"
    },
    %{
      "action" => "$N一招「刺血满地」，双手十指连弹，一时间无数道劲气如潮水般涌向$n，令$n无从躲闪",
      "force" => 300,
      "attack" => 100,
      "parry" => 40,
      "dodge" => 55,
      "damage" => 200,
      "lvl" => 200,
      "damage_type" => "刺伤",
      "skill_name" => "刺血满地"
    }
  ]

  @impl true
  def id(), do: "xiuluo-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 80}

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

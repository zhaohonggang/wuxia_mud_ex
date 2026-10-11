defmodule Kantele.Combat.Skills.ShiguBifa do
  @moduledoc """
  武学实装「shigu-bifa」（源 shigu-bifa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shigu_bifa/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招「指点江山」，手中$w疾点向$n的期门穴",
      "force" => 90,
      "attack" => 15,
      "parry" => 20,
      "dodge" => -10,
      "damage" => 25,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "指点江山"
    },
    %{
      "action" => "$N吐气开声一招「银钩铁划」，$w如灵蛇吞吐，向$n白海穴戳去",
      "force" => 130,
      "attack" => 30,
      "parry" => 30,
      "dodge" => -10,
      "damage" => 30,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "银钩铁划"
    },
    %{
      "action" => "$N向前跨上一步，混身充满战意，手中$w使出「银瓶乍破」，疾点$n的地仓穴",
      "force" => 170,
      "attack" => 40,
      "parry" => 32,
      "dodge" => 5,
      "damage" => 35,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "银瓶乍破"
    },
    %{
      "action" => "$N手中的$w自左而右地一晃，使出「铁骑突出」带着呼呼风声横打$n的章门穴",
      "force" => 190,
      "attack" => 50,
      "parry" => 35,
      "dodge" => 5,
      "damage" => 40,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "铁骑突出"
    },
    %{
      "action" => "$N飞身跃起，一式「龙耀九霄」，卷起漫天笔影，$w向$n电射而去",
      "force" => 240,
      "attack" => 60,
      "parry" => 45,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "龙耀九霄"
    },
    %{
      "action" => "$N凝气守中，$w逼出尺许雪亮笔锋，挥出「灵台观景」，一笔快似一笔地攻向$n",
      "force" => 260,
      "attack" => 65,
      "parry" => 50,
      "dodge" => 5,
      "damage" => 60,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "灵台观景"
    },
    %{
      "action" => "$N使出一招「遥拜玉虚」挺笔中宫直进，笔尖颤动，中途忽然转而向上变幻无方",
      "force" => 280,
      "attack" => 70,
      "parry" => 52,
      "dodge" => 5,
      "damage" => 75,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "遥拜玉虚"
    },
    %{
      "action" => "$N侧身斜刺一笔，一招「天音萧煞」卷带着呼呼笔风，将$n包围紧裹",
      "force" => 310,
      "attack" => 75,
      "parry" => 64,
      "dodge" => 5,
      "damage" => 90,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "天音萧煞"
    }
  ]

  @impl true
  def id(), do: "shigu-bifa"

  @impl true
  def valid_enable(usage), do: usage in ["dagger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 62}

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
      "feng" => Kantele.Combat.Skills.Performs.ShiguBifa.Feng,
      "shiyi" => Kantele.Combat.Skills.Performs.ShiguBifa.Shiyi
    }
  end
end

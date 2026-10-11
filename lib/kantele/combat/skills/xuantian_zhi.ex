defmodule Kantele.Combat.Skills.XuantianZhi do
  @moduledoc """
  武学实装「xuantian-zhi」（源 xuantian-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/xuantian_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左指挥出，一式「冰冻三尺」，指尖携着阴寒之劲削向$n的掌缘",
      "force" => 100,
      "attack" => 10,
      "parry" => 15,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "冰冻三尺"
    },
    %{
      "action" => "$N全身之力聚于指，顿时指尖笼罩着一层寒霜，一式「千里冰封」指向$n的胸前",
      "force" => 140,
      "attack" => 15,
      "parry" => 18,
      "dodge" => -5,
      "damage" => 0,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "千里冰封"
    },
    %{
      "action" => "$N左掌贴于神道穴，右手一式「万里雪飘」，指尖携着阴寒之劲向$n的$l划过",
      "force" => 170,
      "attack" => 20,
      "parry" => 25,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "万里雪飘"
    },
    %{
      "action" => "$N双目怒视，一式「落日寒冰」，双指携着阴寒之劲拂向$n各处要穴",
      "force" => 210,
      "attack" => 28,
      "parry" => 30,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "落日寒冰"
    },
    %{
      "action" => "$N右手伸出，十指叉开，一式「冰河洞开」，分射出数股阴寒之劲，贯向$n",
      "force" => 250,
      "attack" => 30,
      "parry" => 35,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "冰河洞开"
    },
    %{
      "action" => "$N双指迸出无数道阴寒之极的劲气，一式「漫天雪舞」射向$n的全身",
      "force" => 280,
      "attack" => 45,
      "parry" => 40,
      "dodge" => 20,
      "damage" => 15,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "漫天雪舞"
    },
    %{
      "action" => "$N双掌翻飞，一式「九阴寒箭」，指端迸出无数道阴寒劲气，射向$n的全身",
      "force" => 310,
      "attack" => 50,
      "parry" => 48,
      "dodge" => 25,
      "damage" => 20,
      "lvl" => 130,
      "damage_type" => "刺伤",
      "skill_name" => "九阴寒箭"
    },
    %{
      "action" => "$N一式「极地冰原」，并指如刃，一束束锐利无俦的寒气，凌虚向$n的$l砍去",
      "force" => 370,
      "attack" => 60,
      "parry" => 55,
      "dodge" => 30,
      "damage" => 30,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "极地冰原"
    },
    %{
      "action" => "$N一式「天寒地冻」，双手食指交叉，指端射出一缕寒气，穿过$n的$l",
      "force" => 400,
      "attack" => 68,
      "parry" => 60,
      "dodge" => 35,
      "damage" => 40,
      "lvl" => 190,
      "damage_type" => "刺伤",
      "skill_name" => "天寒地冻"
    },
    %{
      "action" => "$N左掌竖立胸前，一式「万古坚冰」，右手食指扣住拇指，轻轻对着$n一弹",
      "force" => 440,
      "attack" => 75,
      "parry" => 66,
      "dodge" => 50,
      "damage" => 10,
      "lvl" => 220,
      "damage_type" => "刺伤",
      "skill_name" => "万古坚冰"
    }
  ]

  @impl true
  def id(), do: "xuantian-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 60, neili: 70}

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
      "bing" => Kantele.Combat.Skills.Performs.XuantianZhi.Bing
    }
  end
end

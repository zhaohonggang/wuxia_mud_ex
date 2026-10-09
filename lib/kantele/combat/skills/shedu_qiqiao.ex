defmodule Kantele.Combat.Skills.SheduQiqiao do
  @moduledoc """
  武学实装「shedu-qiqiao」（源 shedu-qiqiao.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/shedu_qiqiao/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左指挥出，一式「青蛇挺身」，削向$n的掌缘",
      "force" => 80,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 0,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "青蛇挺身"
    },
    %{
      "action" => "$N全身之力聚于一指，一式「银蛇吐信」，指向$n的胸前",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 25,
      "lvl" => 15,
      "damage_type" => "刺伤",
      "skill_name" => "银蛇吐信"
    },
    %{
      "action" => "$N左掌贴于神道穴，右手一式「金蛇摆尾」，向$n的$l划过",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 8,
      "damage" => 55,
      "lvl" => 25,
      "damage_type" => "刺伤",
      "skill_name" => "金蛇摆尾"
    },
    %{
      "action" => "$N双目怒视，一式「蝮蛇捕食」，双指拂向$n的额、颈、肩、臂、胸、背",
      "force" => 150,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 65,
      "lvl" => 45,
      "damage_type" => "刺伤",
      "skill_name" => "蝮蛇捕食"
    },
    %{
      "action" => "$N一式「待机而行」，左掌掌心向外，右指蓄势点向$n的$l",
      "force" => 180,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 15,
      "damage" => 80,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "待机而行"
    },
    %{
      "action" => "$N右手伸出，十指叉开，一式「猛蛇出洞」，小指拂向$n的太渊穴",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 100,
      "lvl" => 70,
      "damage_type" => "刺伤",
      "skill_name" => "猛蛇出洞"
    },
    %{
      "action" => "$N双迸出无数道劲气，一式「千蛇缠身」射向$n的全身",
      "force" => 220,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 25,
      "damage" => 120,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "千蛇缠身"
    }
  ]

  @impl true
  def id(), do: "shedu-qiqiao"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry", "poison"]

  @impl true
  def practice_cost(), do: %{qi: 52, neili: 44}

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

defmodule Kantele.Combat.Skills.PiaoxuZhang do
  @moduledoc """
  武学实装「piaoxu-zhang」（源 piaoxu-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_combine, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/piaoxu_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一式「白云出岫」，双掌间升起一团淡淡的白雾，缓缓推向$n的$l",
      "force" => 50,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 5,
      "damage" => 5,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "白云出岫"
    },
    %{
      "action" => "$N并指如剑，一式「白虹贯日」，疾向$n的$l戳去",
      "force" => 60,
      "attack" => 0,
      "parry" => 15,
      "dodge" => -5,
      "damage" => 5,
      "lvl" => 10,
      "damage_type" => "瘀伤",
      "skill_name" => "白虹贯日"
    },
    %{
      "action" => "$N使一式「云断秦岭」，左掌微拂，右掌乍伸乍合，猛地插往$n的$l",
      "force" => 65,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 5,
      "damage" => 10,
      "lvl" => 20,
      "damage_type" => "瘀伤",
      "skill_name" => "云断秦岭"
    },
    %{
      "action" => "$N双掌隐隐泛出青气，一式「青松翠翠」，幻成漫天碧绿的松针，雨点般向$n击去",
      "force" => 70,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 10,
      "damage" => 15,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "青松翠翠"
    },
    %{
      "action" => "$N身形往上一纵，使出一式「天绅倒悬」，双掌并拢，笔直地向$n的$l插去",
      "force" => 75,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 15,
      "damage" => 15,
      "lvl" => 40,
      "damage_type" => "瘀伤",
      "skill_name" => "天绅倒悬"
    },
    %{
      "action" => "$N身形一变，使一式「无边落木」，双掌带着萧刹的劲气，猛地击往$n的$l",
      "force" => 80,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 20,
      "lvl" => 50,
      "damage_type" => "瘀伤",
      "skill_name" => "无边落木"
    },
    %{
      "action" => "$N使一式「高山流水」，左掌凝重，右掌轻盈，同时向$n的$l击去",
      "force" => 85,
      "attack" => 0,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "高山流水"
    },
    %{
      "action" => "$N突地一招「金玉满堂」，双掌挟着一阵风雷之势，猛地劈往$n的$l",
      "force" => 90,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 70,
      "damage_type" => "瘀伤",
      "skill_name" => "金玉满堂"
    },
    %{
      "action" => "$N一式「风伴流云」，双掌缦妙地一阵挥舞，不觉已击到$n的$l上",
      "force" => 110,
      "attack" => 0,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 25,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "风伴流云"
    },
    %{
      "action" => "$N一式「烟雨飘渺」，身形凝立不动，双掌一高一低，看似简单，却令$n无法躲闪",
      "force" => 120,
      "attack" => 0,
      "parry" => 10,
      "dodge" => 25,
      "damage" => 30,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "烟雨飘渺"
    }
  ]

  @impl true
  def id(), do: "piaoxu-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 45, neili: 25}

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
      "piao" => Kantele.Combat.Skills.Performs.PiaoxuZhang.Piao
    }
  end
end

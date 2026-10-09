defmodule Kantele.Combat.Skills.BazhenZhang do
  @moduledoc """
  武学实装「bazhen-zhang」（源 bazhen-zhang.c，由 translate_skill.exs 生成）

  已自动化：静态招式 8 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/bazhen_zhang/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N一招",
      "force" => 130,
      "attack" => 21,
      "parry" => 65,
      "dodge" => 70,
      "damage" => 14,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "天阵居乾为天门"
    },
    %{
      "action" => "$N一招",
      "force" => 170,
      "attack" => 25,
      "parry" => 76,
      "dodge" => 83,
      "damage" => 17,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "地阵居坤为地门"
    },
    %{
      "action" => "$N一招",
      "force" => 190,
      "attack" => 28,
      "parry" => 88,
      "dodge" => 95,
      "damage" => 20,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "风阵居巽为风门"
    },
    %{
      "action" => "$N一招",
      "force" => 230,
      "attack" => 35,
      "parry" => 98,
      "dodge" => 107,
      "damage" => 23,
      "lvl" => 90,
      "damage_type" => "瘀伤",
      "skill_name" => "云阵居震为云门"
    },
    %{
      "action" => "$N一招",
      "force" => 270,
      "attack" => 40,
      "parry" => 113,
      "dodge" => 129,
      "damage" => 27,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "飞龙居坎飞龙门"
    },
    %{
      "action" => "$N一招",
      "force" => 320,
      "attack" => 48,
      "parry" => 118,
      "dodge" => 154,
      "damage" => 38,
      "lvl" => 150,
      "damage_type" => "瘀伤",
      "skill_name" => "武翼居兑武翼门"
    },
    %{
      "action" => "$N错步上前，一招",
      "force" => 360,
      "attack" => 61,
      "parry" => 131,
      "dodge" => 153,
      "damage" => 45,
      "lvl" => 180,
      "damage_type" => "内伤",
      "skill_name" => "鸟翔居离鸟翔门"
    },
    %{
      "action" => "$N身形一扭，将背门对准$n，使出一招",
      "force" => 380,
      "attack" => 73,
      "parry" => 135,
      "dodge" => 155,
      "damage" => 57,
      "lvl" => 220,
      "damage_type" => "内伤",
      "skill_name" => "蜿盘居艮蜿盘门"
    }
  ]

  @impl true
  def id(), do: "bazhen-zhang"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "strike"]

  @impl true
  def practice_cost(), do: %{qi: 85, neili: 60}

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

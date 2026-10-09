defmodule Kantele.Combat.Skills.QufannaoZhi do
  @moduledoc """
  武学实装「qufannao-zhi」（源 qufannao-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 7 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qufannao_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N神色端庄，长吸一口气，左手食指突然点向$n胸口",
      "force" => 350,
      "attack" => 0,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 50,
      "lvl" => 10,
      "damage_type" => "刺伤",
      "skill_name" => "无相无色"
    },
    %{
      "action" => "$N飘然退后，右手中指三曲三伸，一股无形指力猛袭$n下腹",
      "force" => 400,
      "attack" => 0,
      "parry" => 30,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 50,
      "damage_type" => "刺伤",
      "skill_name" => "烦恼无劫"
    },
    %{
      "action" => "$N丝毫不为$n所动，双手交替中，一式“烦恼无归”已封住了$n的所有退路",
      "force" => 450,
      "attack" => 0,
      "parry" => 25,
      "dodge" => 40,
      "damage" => 100,
      "lvl" => 80,
      "damage_type" => "内伤",
      "skill_name" => "烦恼无归"
    },
    %{
      "action" => "$N中指划动，无形指力弥漫四周。$n顿时上蹿下跳狼狈躲避",
      "force" => 500,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 50,
      "damage" => 130,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "烦恼无尽"
    },
    %{
      "action" => "$N忽然间化指为掌，“烦恼无形”意味古拙，掌力广被，$n莫辨其方向，难以招架",
      "force" => 550,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 55,
      "damage" => 170,
      "lvl" => 60,
      "damage_type" => "内伤",
      "skill_name" => "烦恼无形"
    },
    %{
      "action" => "$N俯身前探，右手食指连点数下，已将参和指发挥至极致",
      "force" => 550,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 55,
      "damage" => 200,
      "lvl" => 75,
      "damage_type" => "刺伤",
      "skill_name" => "烦恼无极"
    },
    %{
      "action" => "$N遥点数指，却是半点风声也无，$n胸口一紧，顿觉遍体冰凉",
      "force" => 580,
      "attack" => 0,
      "parry" => 50,
      "dodge" => 60,
      "damage" => 250,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "烦恼无指"
    }
  ]

  @impl true
  def id(), do: "qufannao-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 0, neili: 20}

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

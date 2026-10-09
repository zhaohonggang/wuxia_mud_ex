defmodule Kantele.Combat.Skills.YoumingZhi do
  @moduledoc """
  武学实装「youming-zhi」（源 youming-zhi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 6 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/youming_zhi/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N左手轻轻拨动，五指徐徐弹出拨，一式「元神出窍」，拂向$n全身经脉",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 5,
      "damage" => 15,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "元神出窍"
    },
    %{
      "action" => "$N俯身掠向$n，一式「鬼魅穿心」，化掌成指，汹涌袭向$n，正是其要脉所在",
      "force" => 140,
      "attack" => 5,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 20,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "鬼魅穿心"
    },
    %{
      "action" => "$N双手扭曲如灵蛇，一式「血鬼锁心」施出，左右并用，陡然插向$n的双目",
      "force" => 155,
      "attack" => 10,
      "parry" => 7,
      "dodge" => 5,
      "damage" => 30,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "血鬼锁心"
    },
    %{
      "action" => "$N一式「炼狱鬼嚎」，左手抽回，右手前探，戟指点向$n的脑后脊髓",
      "force" => 170,
      "attack" => 20,
      "parry" => 11,
      "dodge" => 9,
      "damage" => 40,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "炼狱鬼嚎"
    },
    %{
      "action" => "$N使一式「孤魂驭魔」，身影变幻不定地掠至$n身后，猛地拍向$n左前胸",
      "force" => 190,
      "attack" => 30,
      "parry" => 12,
      "dodge" => 10,
      "damage" => 50,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "孤魂驭魔"
    },
    %{
      "action" => "$N两臂大开大阖，一式「妖风袭体」，劲力透彻，顿时激出数道劲气逼向$n",
      "force" => 220,
      "attack" => 40,
      "parry" => 21,
      "dodge" => 15,
      "damage" => 55,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "妖风袭体"
    }
  ]

  @impl true
  def id(), do: "youming-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 51}

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

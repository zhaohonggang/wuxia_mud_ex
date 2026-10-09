defmodule Kantele.Combat.Skills.LiumaiShenjian do
  @moduledoc """
  武学实装「liumai-shenjian」（源 liumai-shenjian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 21 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, hit_ob, perform_action_file, practice_skill, skill_improved, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/liumai_shenjian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手拇指同时捺出，嗤嗤两声急响，「",
      "force" => 460,
      "attack" => 240,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少商剑"
    },
    %{
      "action" => "$N大拇指一按，嗤嗤两指，劲道使得甚巧，「",
      "force" => 460,
      "attack" => 240,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少商剑"
    },
    %{
      "action" => "$N大拇指连挥，「",
      "force" => 460,
      "attack" => 240,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少商剑"
    },
    %{
      "action" => "$N双手拇指同时捺出，「",
      "force" => 460,
      "attack" => 240,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少商剑"
    },
    %{
      "action" => "$N食指连动，手腕园转，「",
      "force" => 440,
      "attack" => 245,
      "parry" => 95,
      "dodge" => 110,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "商阳剑"
    },
    %{
      "action" => "$N变招奇速，右手食指疾从袖底穿出，「",
      "force" => 440,
      "attack" => 245,
      "parry" => 95,
      "dodge" => 110,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "商阳剑"
    },
    %{
      "action" => "$N拇指一屈，食指随即点出，嗤嗤两声急响，变成商阳剑法，「",
      "force" => 440,
      "attack" => 245,
      "parry" => 95,
      "dodge" => 110,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "商阳剑"
    },
    %{
      "action" => "$N以食指急运「",
      "force" => 480,
      "attack" => 245,
      "parry" => 95,
      "dodge" => 110,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "商阳剑"
    },
    %{
      "action" => "$N右手中指一竖，「",
      "force" => 560,
      "attack" => 255,
      "parry" => 70,
      "dodge" => 10,
      "damage" => 220,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "中冲剑"
    },
    %{
      "action" => "$N将中指向上一刺，「",
      "force" => 560,
      "attack" => 245,
      "parry" => 70,
      "dodge" => 10,
      "damage" => 220,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "中冲剑"
    },
    %{
      "action" => "电光火石之间，$N猛然翻掌，右手陡然探出，中指「",
      "force" => 560,
      "attack" => 235,
      "parry" => 70,
      "dodge" => 10,
      "damage" => 220,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "中冲剑"
    },
    %{
      "action" => "$N右手无名指伸出，「",
      "force" => 530,
      "attack" => 240,
      "parry" => 95,
      "dodge" => 100,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "关冲剑"
    },
    %{
      "action" => "$N俯身斜倚，无名指「",
      "force" => 530,
      "attack" => 240,
      "parry" => 95,
      "dodge" => 100,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "关冲剑"
    },
    %{
      "action" => "$N无名指轻轻一挥，「嗤啦」一声，拙滞古朴的「",
      "force" => 530,
      "attack" => 240,
      "parry" => 95,
      "dodge" => 100,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "关冲剑"
    },
    %{
      "action" => "$N左手小指一伸，一条气流从少冲穴中激射而出，「",
      "force" => 500,
      "attack" => 260,
      "parry" => 92,
      "dodge" => 95,
      "damage" => 270,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少泽剑"
    },
    %{
      "action" => "忽见$N左手小指一伸，一条气流从$P少冲穴中激射而出，一股「",
      "force" => 500,
      "attack" => 260,
      "parry" => 92,
      "dodge" => 95,
      "damage" => 270,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少泽剑"
    },
    %{
      "action" => "$N右手小指伸出，真气自少冲穴激荡而出，「",
      "force" => 480,
      "attack" => 250,
      "parry" => 95,
      "dodge" => 90,
      "damage" => 240,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少冲剑"
    },
    %{
      "action" => "$N掌托于胸前，伸出右小指，一招「",
      "force" => 530,
      "attack" => 270,
      "parry" => 95,
      "dodge" => 90,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少冲剑"
    },
    %{
      "action" => "$N小指一弹，「",
      "force" => 430,
      "attack" => 280,
      "parry" => 95,
      "dodge" => 90,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少冲剑"
    },
    %{
      "action" => "$N一招「",
      "force" => 530,
      "attack" => 280,
      "parry" => 95,
      "dodge" => 90,
      "damage" => 240,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少冲剑"
    },
    %{
      "action" => "$N右手小指一挥，一招「",
      "force" => 530,
      "attack" => 280,
      "parry" => 95,
      "dodge" => 90,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少冲剑"
    }
  ]

  @impl true
  def id(), do: "liumai-shenjian"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 88, neili: 0}

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

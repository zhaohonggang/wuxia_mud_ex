defmodule Kantele.Combat.Skills.PixieJian do
  @moduledoc """
  武学实装「pixie-jian」（源 pixie-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, hit_ob, perform_action_file, practice_skill, query_effect_dodge, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/pixie_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "突然之间，白影急幌，$N向后滑出丈余，立时又回到了原地",
      "force" => 160,
      "attack" => 40,
      "parry" => 30,
      "dodge" => 120,
      "damage" => 150,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "白影急幌"
    },
    %{
      "action" => "$N右手伸出，在$n手腕上迅速无比的一按，$n险些击中自己小腹",
      "force" => 180,
      "attack" => 50,
      "parry" => 30,
      "dodge" => 135,
      "damage" => 160,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "自己小腹"
    },
    %{
      "action" => "蓦地里$N猱身而上，蹿到$n的身后，又跃回原地",
      "force" => 225,
      "attack" => 60,
      "parry" => 35,
      "dodge" => 155,
      "damage" => 170,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "猱身而上"
    },
    %{
      "action" => "$N突然间招法一变，$w忽伸忽缩，招式诡奇绝伦。$n惊骇之中方寸大乱",
      "force" => 230,
      "attack" => 70,
      "parry" => 40,
      "dodge" => 160,
      "damage" => 180,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "招法一变"
    },
    %{
      "action" => "$N身形飘忽，有如鬼魅，转了几转，移步到$n的左侧",
      "force" => 240,
      "attack" => 80,
      "parry" => 50,
      "dodge" => 170,
      "damage" => 200,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "有如鬼魅"
    },
    %{
      "action" => "$N一声冷笑，蓦地里疾冲上前，一瞬之间，与$n相距已不到一尺，$w随即递出",
      "force" => 260,
      "attack" => 70,
      "parry" => 40,
      "dodge" => 165,
      "damage" => 220,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "疾冲上前"
    },
    %{
      "action" => "$N喝道：“好！”，便即拔出$w，反手刺出，跟着转身离去",
      "force" => 300,
      "attack" => 90,
      "parry" => 45,
      "dodge" => 180,
      "damage" => 230,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "反手刺出"
    },
    %{
      "action" => "$n只觉眼前一花，似乎见到$N身形一幌，但随即又见$N回到原地，却似从未离开",
      "force" => 340,
      "attack" => 80,
      "parry" => 40,
      "dodge" => 185,
      "damage" => 250,
      "lvl" => 140,
      "damage_type" => "刺伤",
      "skill_name" => "眼前一花"
    },
    %{
      "action" => "$N向后疾退，$n紧追两步，突然间$N闪到$n面前，手中$w直指$n的$l",
      "force" => 380,
      "attack" => 100,
      "parry" => 50,
      "dodge" => 190,
      "damage" => 270,
      "lvl" => 160,
      "damage_type" => "刺伤",
      "skill_name" => "向后疾退"
    },
    %{
      "action" => "$N蓦地冲到$n面前，手中$w直刺$n右眼！$n慌忙招架，不想$N的$w突然转向",
      "force" => 410,
      "attack" => 130,
      "parry" => 55,
      "dodge" => 210,
      "damage" => 300,
      "lvl" => 180,
      "damage_type" => "刺伤",
      "skill_name" => "直刺右眼"
    },
    %{
      "action" => "$N飞身跃起，$n抬眼一望，但见得$N从天直落而下，手中$w刺向$n的$l",
      "force" => 440,
      "attack" => 130,
      "parry" => 50,
      "dodge" => 230,
      "damage" => 320,
      "lvl" => 200,
      "damage_type" => "刺伤",
      "skill_name" => "飞身跃起"
    },
    %{
      "action" => "$N腰枝猛摆，$n眼前仿佛突然出现了七八个$N，七八只$w一起刺向$n",
      "force" => 480,
      "attack" => 140,
      "parry" => 60,
      "dodge" => 270,
      "damage" => 340,
      "lvl" => 220,
      "damage_type" => "刺伤",
      "skill_name" => "腰枝猛摆"
    }
  ]

  @impl true
  def id(), do: "pixie-jian"

  @impl true
  def valid_enable(usage), do: usage in ["dodge", "parry", "sword", "unarmed"]

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

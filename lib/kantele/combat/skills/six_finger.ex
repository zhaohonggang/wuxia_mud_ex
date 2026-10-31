defmodule Kantele.Combat.Skills.SixFinger do
  @moduledoc """
  武学实装「six-finger」（源 six-finger.c，由 translate_skill.exs 生成）

  已自动化：静态招式 21 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, skill_improved
  - perform/exert 路由骨架见 tmp/perf_out/six_finger/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  alias Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手拇指同时捺出，嗤嗤两声急响，「",
      "force" => 460,
      "attack" => 140,
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
      "attack" => 140,
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
      "attack" => 140,
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
      "attack" => 140,
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
      "attack" => 145,
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
      "attack" => 145,
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
      "attack" => 145,
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
      "attack" => 145,
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
      "attack" => 155,
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
      "attack" => 145,
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
      "attack" => 135,
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
      "attack" => 140,
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
      "attack" => 140,
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
      "attack" => 140,
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
      "attack" => 160,
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
      "attack" => 160,
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
      "attack" => 150,
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
      "attack" => 170,
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
      "attack" => 180,
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
      "attack" => 180,
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
      "attack" => 180,
      "parry" => 95,
      "dodge" => 90,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "少冲剑"
    }
  ]

  @impl true
  def id(), do: "six-finger"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  @impl true
  def practice_cost(), do: %{qi: 88, neili: 0}

  # LPC `valid_learn(object me)`（源 six-finger.c）
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练六脉神剑必须空手。\n"}

      Stats.int(stats) < 36 ->
        {:error, "你研究了半天，只感六种剑法毫无牵连，无法再作研究。\n"}

      Stats.con(stats) < 36 ->
        {:error, "你研究了一会儿，只觉得眼前金星乱冒，太阳穴突突的跳。\n"}

      Stats.skill(stats, "literate") < 200 ->
        {:error, "你觉得六脉神剑极其深奥，不是你这种学问水平所能研究的。\n"}

      Stats.skill(stats, "lamaism") < 200 ->
        {:error, "你发现这里面有很多奥妙都和密宗心法有关，难以理解。\n"}

      Stats.skill(stats, "buddhism") < 200 ->
        {:error, "你发现这里面有很多奥妙都和禅宗心法有关，难以理解。\n"}

      Stats.skill(stats, "jingluo-xue") < 200 ->
        {:error, "你发现这里面有很多奥妙都和人体的经络构造有关，难以理解。\n"}

      not is_nil(max_neili) and max_neili < 5000 ->
        {:error, "你的内力太弱，无法学六脉神剑。\n"}

      Stats.skill(stats, "finger") < 200 ->
        {:error, "你的基本指法火候不够。\n"}

      Stats.skill(stats, "force") < Stats.skill(stats, "liumai-shenjian") + 10 ->
        {:error, "你的现在必须先提高你基本内功的水平。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, "liumai-shenjian") + 10 ->
        {:error, "你的现在必须先提高你基本指法的水平。\n"}

      true ->
        :ok
    end
  end

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
      "qi" => Kantele.Combat.Skills.Performs.SixFinger.Qi,
      "six" => Kantele.Combat.Skills.Performs.SixFinger.Six,
      "zong" => Kantele.Combat.Skills.Performs.SixFinger.Zong,
      "zongheng" => Kantele.Combat.Skills.Performs.SixFinger.Zongheng
    }
  end

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end

defmodule Kantele.Combat.Skills.HuashanJian do
  @moduledoc """
  华山剑法（对照 kungfu/skill/huashan-jian.c）

  招式表为纯数据（`@actions`，取 LPC `action` 表中的 6 式静态招式）。
  第 7 式「极意」（lvl 200）的力/攻/闪/架/伤由 `query_action/3` 按出招者的
  `force`/`sword`/`dodge`/`parry` **实时生成**（见 `@ultimate` 与 `ultimate_values/2`）。

  **未迁移**：`hit_ob`「紫霞剑气」（华山剑法 + 狂风快剑 + 紫霞神功均 ≥300 且映射齐全时的
  额外创伤）—— 引擎无命中后回调，见 TODO(migrate)。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  # 第 7 式「极意」的静态部分；五项数值由 ultimate_values/2 出招时生成
  @ultimate %{
    "action" => "$N凝神静气，使出极招 华山剑法之极意 ",
    "lvl" => 200,
    "skill_name" => "极意",
    "damage_type" => "刺伤"
  }

  @actions [
    %{
      "action" => "$N使一招「有凤来仪」，手中$w剑光暴长，向$n的$l刺去",
      "force" => 70,
      "attack" => 10,
      "parry" => 5,
      "dodge" => 10,
      "damage" => 30,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "有凤来仪"
    },
    %{
      "action" => "$N剑随身转，一招「无边落木」罩向$n的$l",
      "force" => 120,
      "attack" => 20,
      "parry" => 15,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "无边落木"
    },
    %{
      "action" => "$N舞动$w，一招「鸿飞冥冥」挟著无数剑光刺向$n的$l",
      "force" => 160,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 30,
      "damage" => 45,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "鸿飞冥冥"
    },
    %{
      "action" => "$N手中$w龙吟一声，祭出「平沙落雁」往$n的$l刺出数剑",
      "force" => 190,
      "attack" => 30,
      "parry" => 28,
      "dodge" => 35,
      "damage" => 50,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "平沙落雁"
    },
    %{
      "action" => "$N手中$w剑光暴长，一招「金玉满堂」往$n$l刺去",
      "force" => 220,
      "attack" => 40,
      "parry" => 33,
      "dodge" => 40,
      "damage" => 55,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "金玉满堂"
    },
    %{
      "action" => "$N手中$w化成一道光弧，直指$n$l，一招「白虹贯日」发出虎哮龙吟刺去",
      "force" => 260,
      "attack" => 50,
      "parry" => 40,
      "dodge" => -20,
      "damage" => 90,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "白虹贯日"
    }
  ]

  @impl true
  def id(), do: "huashan-jian"

  @impl true
  def valid_enable(usage), do: usage == "sword" or usage == "parry"

  # TODO(migrate): LPC valid_learn 还要求 max_neili >= 100 且手持剑（query_temp weapon）
  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内力不够，没有办法练华山剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的华山剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 31}

  @doc "按等级加权随机选一式（招式表 + NewRandom）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc """
  带角色上下文选招：等级 > 200 时把动态第 7 式「极意」并入招式表

  LPC 原文（`kungfu/skill/huashan-jian.c`）：

      "force"  : query_skill("force",1)/2 + random(query_skill("force",1)),
      "attack" : query_skill("sword",1)/4 + random(query_skill("sword",1)/2),
      "dodge"  : query_skill("dodge",1)/6 + random(query_skill("force",1)/3),
      "parry"  : query_skill("parry",1)/6 + random(query_skill("parry",1)/3),
      "damage" : query_skill("force",1)/4 + random(query_skill("sword",1)/2),
  """
  @impl true
  def query_action(level, rng, attacker) do
    Kantele.Combat.Skill.pick_action_with_ultimate(
      @actions,
      level,
      attacker,
      @ultimate,
      &ultimate_values/2,
      rng
    )
  end

  defp ultimate_values(attacker, rng) do
    force = Skill.skill_of(attacker, "force")
    sword = Skill.skill_of(attacker, "sword")
    dodge = Skill.skill_of(attacker, "dodge")
    parry = Skill.skill_of(attacker, "parry")
    r = &Skill.lpc_random(rng, &1)

    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(sword, 4) + r.(div(sword, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(sword, 2))
    }
  end

  @impl true
  def perform_list() do
    %{
      "jie" => Kantele.Combat.Skills.Performs.HuashanJian.Jie,
      "lian" => Kantele.Combat.Skills.Performs.HuashanJian.Lian,
      "long" => Kantele.Combat.Skills.Performs.HuashanJian.Long,
      "xian" => Kantele.Combat.Skills.Performs.HuashanJian.Xian
    }
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "第 7 式「极意」的静态部分（动态数值需角色上下文，见 `query_action/3`）"
  def ultimate(), do: @ultimate

  @doc "当前等级对应的最高招式名（query_skill_name，含极意）"
  def query_skill_name(level) do
    (@actions ++ [@ultimate])
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> action["skill_name"]
    end
  end
end

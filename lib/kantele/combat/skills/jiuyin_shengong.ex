defmodule Kantele.Combat.Skills.JiuyinShengong do
  @moduledoc """
  武学实装「jiuyin-shengong」（源 jiuyin-shengong.c）

  九阴神功（`inherit FORCE` 的绝学内功）。LPC 的招式表变量名是 **`actionf`** 而不是
  `action`（全库仅这 6 个绝学如此），`translate_skill.exs` 只认 `action`，所以
  生成时整表丢失 —— 本文件已按源补回：

  - `@actions`：`actionf`，空手时用（6 式）
  - `@actions_weapon`：`actionw`，持械时用（5 式）

  LPC 的选招是 `weapon ? actionw[random(sizeof(actionw))] : actionf[random(sizeof(actionw))]`
  —— 注意**两张表长度不同时用 `sizeof(actionw)` 索引 `actionf` 是源里的 off-by-one**，
  这里按各自表的长度选（`Kantele.Combat.Skill.pick_action_for/5`），不照抄该缺陷。

  **reborn 门控**：`usage_skills3` 只有 `force`，转世后才放开 `usage_skills` 的 9 项；
  `valid_enable/1` 走未转世分支（保守），`valid_enable/2` 读角色走完整分支。
  `valid_force` 恒 1、`double_attack` 恒 1（引擎默认）。

  未迁移：`perform`/`exert` 的具体效果、`difficult_level`、`practice_skill` 门槛
  （路由骨架已由 `perform_list`/`exert_list` 给出）。
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N伸手一探，顿时气流呼啸而至，单手毫无花巧的插向$n$l",
      "force" => 510,
      "attack" => 190,
      "parry" => 90,
      "dodge" => 100,
      "damage" => 180,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N双手齐抓，幻出千万道耀眼的金光，齐齐照向$n的$l",
      "force" => 510,
      "attack" => 185,
      "parry" => 120,
      "dodge" => 90,
      "damage" => 175,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N身形一转，拳头携着疾速旋转的气流挥出，疾如闪电，势如雷霆，击向$n",
      "force" => 530,
      "attack" => 175,
      "parry" => 110,
      "dodge" => 90,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N移步向前，一掌不紧不慢的拍向$n的$l，空气中顿时传来一阵刺耳的暴响",
      "force" => 525,
      "attack" => 185,
      "parry" => 115,
      "dodge" => 85,
      "damage" => 185,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N身体一侧，一掌凌空劈出，一股凛冽的气流顿时澎湃涌至$n的$l处",
      "force" => 530,
      "attack" => 165,
      "parry" => 115,
      "dodge" => 90,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N双手合拳，蓦的张开，只听“嗤嗤”破空之声，十道劲气一齐射向$n的$l",
      "force" => 540,
      "attack" => 200,
      "parry" => 120,
      "dodge" => 115,
      "damage" => 280,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @actions_weapon [
    %{
      "action" => "$N攻势忽缓而不疏，$w变化无常，捉摸不定向$n慢慢卷去",
      "force" => 470,
      "attack" => 180,
      "parry" => 115,
      "dodge" => 75,
      "damage" => 225,
      "lvl" => 0,
      "damage_type" => "擦伤"
    },
    %{
      "action" => "$N手中的$w突焕气象森严，便似千军万马奔驰而来，$w就如棍棒一般横扫$n",
      "force" => 450,
      "attack" => 160,
      "parry" => 125,
      "dodge" => 85,
      "damage" => 210,
      "lvl" => 0,
      "damage_type" => "擦伤"
    },
    %{
      "action" => "$N卷起手中的$w，就如铁锤一般对着$n乱砍乱砸，没有半点章法",
      "force" => 460,
      "attack" => 175,
      "parry" => 125,
      "dodge" => 80,
      "damage" => 205,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N运用$w幻化做一个一个圆圈，似乎要将$n团团包围",
      "force" => 525,
      "attack" => 160,
      "parry" => 125,
      "dodge" => 65,
      "damage" => 190,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N含笑回转$w，伸手一指，颇得拈花指之意，点向$n的$l",
      "force" => 540,
      "attack" => 180,
      "parry" => 120,
      "dodge" => 70,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @impl true
  def id(), do: "jiuyin-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @doc """
  带角色的 `valid_enable`（LPC 读 `this_player()`）：

      if (!me->query("reborn"))
          return (member_array(usage, usage_skills3) != -1);   // {"force"}
      else
          return (member_array(usage, usage_skills) != -1);    // 9 项

  未转世只能 `force`；转世后放开拳脚/爪/手法/鞭/轻功/招架等 9 项。
  """
  @impl true
  def valid_enable(usage, character) do
    if Kantele.Combat.Skill.reborn?(character) do
      usage in ["unarmed", "strike", "claw", "hand", "cuff", "dodge", "whip", "parry", "force"]
    else
      usage == "force"
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, nil, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, attacker, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "持械招式表（LPC `actionw`）"
  def weapon_actions(), do: @actions_weapon

  @impl true
  def perform_list() do
    %{
      "quan" => Kantele.Combat.Skills.Performs.JiuyinShengong.Quan,
      "shou" => Kantele.Combat.Skills.Performs.JiuyinShengong.Shou,
      "xin" => Kantele.Combat.Skills.Performs.JiuyinShengong.Xin,
      "zhang" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhang,
      "zhen" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhen,
      "zhi" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhi,
      "zhua" => Kantele.Combat.Skills.Performs.JiuyinShengong.Zhua
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.JiuyinShengong.Powerup,
      "roar" => Kantele.Combat.Skills.Performs.JiuyinShengong.Roar,
      "shield" => Kantele.Combat.Skills.Performs.JiuyinShengong.Shield
    }
  end
end

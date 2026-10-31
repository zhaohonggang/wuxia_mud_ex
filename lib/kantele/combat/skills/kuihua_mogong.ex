defmodule Kantele.Combat.Skills.KuihuaMogong do
  @moduledoc """
  武学实装「kuihua-mogong」（源 kuihua-mogong.c）

  葵花魔功（`inherit FORCE` 的绝学内功）。LPC 的招式表变量名是 **`actionf`** 而不是
  `action`（全库仅这 6 个绝学如此），`translate_skill.exs` 只认 `action`，所以
  生成时整表丢失 —— 本文件已按源补回：

  - `@actions`：`actionf`，空手时用（6 式）
  - `@actions_weapon`：`actionw`，持械时用（6 式）

  LPC 的选招是 `weapon ? actionw[random(sizeof(actionw))] : actionf[random(sizeof(actionw))]`
  —— 注意**两张表长度不同时用 `sizeof(actionw)` 索引 `actionf` 是源里的 off-by-one**，
  这里按各自表的长度选（`Kantele.Combat.Skill.pick_action_for/5`），不照抄该缺陷。

  `valid_combo(combo) == "kuihua-mogong"` 引擎暂无 combo 回调，未迁移。
  `valid_force` 恒 1、`double_attack` 恒 1（引擎默认）。

  未迁移：`perform`/`exert` 的具体效果、`difficult_level`、`practice_skill` 门槛
  （路由骨架已由 `perform_list`/`exert_list` 给出）。
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N倏的近前，身形快极，手指戳向$n的$l",
      "force" => 410,
      "attack" => 182,
      "parry" => 60,
      "dodge" => 215,
      "damage" => 190,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N扑向前来，身形如同鬼魅，令人难以捉摸，手指忽的刺向$n的$l",
      "force" => 410,
      "attack" => 180,
      "parry" => 70,
      "dodge" => 224,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身形一转，手指刺出，直指$n的$l",
      "force" => 430,
      "attack" => 175,
      "parry" => 50,
      "dodge" => 220,
      "damage" => 210,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N飘然远去，忽又进前，速度快的不可思议，一指如闪电般刺向$n的$l",
      "force" => 445,
      "attack" => 180,
      "parry" => 65,
      "dodge" => 255,
      "damage" => 190,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身体一晃，突然飞起一脚，踢向$n的$l",
      "force" => 450,
      "attack" => 200,
      "parry" => 55,
      "dodge" => 250,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N足下疾走，身形变幻莫测，突然一指插向$n的$l",
      "force" => 450,
      "attack" => 215,
      "parry" => 55,
      "dodge" => 285,
      "damage" => 220,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @actions_weapon [
    %{
      "action" => "$N倏的近前，身形快极，手中的$w戳向$n的$l",
      "force" => 460,
      "attack" => 200,
      "parry" => 40,
      "dodge" => 150,
      "damage" => 300,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N扑向前来，身形如同鬼魅，令人难以捉摸，手中的$w忽的刺向$n的$l",
      "force" => 490,
      "attack" => 185,
      "parry" => 45,
      "dodge" => 160,
      "damage" => 300,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身形一转，$w刺出，直指$n的$l",
      "force" => 465,
      "attack" => 210,
      "parry" => 45,
      "dodge" => 180,
      "damage" => 300,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N飘然远去，忽又进前，速度快的不可思议，$w如闪电般刺向$n的$l",
      "force" => 480,
      "attack" => 190,
      "parry" => 55,
      "dodge" => 195,
      "damage" => 300,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身体一晃，突然飞起一脚踢向$n的下阴，蓦的又收回，反手$w刺向$n的$l",
      "force" => 500,
      "attack" => 220,
      "parry" => 57,
      "dodge" => 180,
      "damage" => 300,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N足下疾走，身形变幻莫测，突然一扬手，$w飞也似的插向$n的$l",
      "force" => 520,
      "attack" => 260,
      "parry" => 50,
      "dodge" => 195,
      "damage" => 300,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @impl true
  def id(), do: "kuihua-mogong"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "kuihua-mogong", 0) < 210 or
         Map.get(victim.mapped, "dodge") != "kuihua-mogong" do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "dodge", 0) + mp
      dp = div(Map.get(victim.skills, "dodge", 0), 2) + Map.get(victim.skills, "kuihua-mogong", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, kuihua_msg(rng)}
      else
        if mp >= 100 do
          {damage, kuihua_fail_msg(rng)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp kuihua_msg(rng) do
    case rng.(4) - 1 do
      0 -> "$N眼睛一花，$n已没了踪影。突然$n从身后拍了一下$N的头，轻轻跃开。\n"
      1 -> "$N眼前一花，似乎见到$n身形一晃，但随即又见$n回到原地，却似从未离开。\n"
      2 -> "$n尖啸一声，忽然身子一转已不见了踪影，$N只觉耳边风声不断，但随即又见$n回到了原地。\n"
      _ -> "忽然间，只见$n腰枝一摆，顿时出现无数个$n的影子，$N却无法辨别出$n的方位。\n"
    end
  end

  defp kuihua_fail_msg(rng) do
    case rng.(4) - 1 do
      0 -> "$N眼睛一花，$n已没了踪影。可是$N精通易理，丝毫不为所乱，尽自出招。\n"
      1 -> "$N眼前一花，似乎见到$n身形一晃。$N一声冷笑，已瞬间看破招中虚实。\n"
      2 -> "$n身形飘忽，有如鬼魅，转了几转，可是$N理也不理，连续数招径直攻出。\n"
      _ -> "突然间白影急晃，$n身形顿时化分成万千身影，可是$N不假思索，追身攻上，更是巧妙无方。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["unarmed", "sword", "dodge", "parry", "force"]

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
      "bian" => Kantele.Combat.Skills.Performs.KuihuaMogong.Bian,
      "qiong" => Kantele.Combat.Skills.Performs.KuihuaMogong.Qiong,
      "sheng" => Kantele.Combat.Skills.Performs.KuihuaMogong.Sheng,
      "tian" => Kantele.Combat.Skills.Performs.KuihuaMogong.Tian,
      "wswd" => Kantele.Combat.Skills.Performs.KuihuaMogong.Wswd
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.KuihuaMogong.Powerup,
      "roar" => Kantele.Combat.Skills.Performs.KuihuaMogong.Roar,
      "shield" => Kantele.Combat.Skills.Performs.KuihuaMogong.Shield
    }
  end
end

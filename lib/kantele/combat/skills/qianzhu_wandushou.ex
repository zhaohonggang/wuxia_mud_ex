defmodule Kantele.Combat.Skills.QianzhuWandushou do
  @moduledoc """
  武学实装「qianzhu-wandushou」（源 qianzhu-wandushou.c，由 translate_skill.exs 生成）

  已自动化：静态招式 10 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qianzhu_wandushou/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N身形一晃而至，一招「小鬼勾魂」，双掌带着一缕腥风拍向$n的前心",
      "force" => 100,
      "attack" => 25,
      "parry" => 20,
      "dodge" => 15,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身形化做一缕轻烟绕着$n急转，一招「天网恢恢」，双掌幻出无数掌影罩向$n",
      "force" => 130,
      "attack" => 30,
      "parry" => 15,
      "dodge" => 10,
      "damage" => 20,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N怪叫一声，一招「阴风怒号」，双掌铺天盖地般拍向$n的$l",
      "force" => 160,
      "attack" => 45,
      "parry" => 20,
      "dodge" => 20,
      "damage" => 25,
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一照「凄雨冷风」，双掌拍出满天阴风，忽然右掌悄无声息的拍向$n的$l",
      "force" => 180,
      "attack" => 50,
      "parry" => 30,
      "dodge" => 20,
      "damage" => 30,
      "lvl" => 80,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N大喝一声，一招「恶鬼推门」，单掌如巨斧开山带着一股腥风猛劈向$n的面门",
      "force" => 210,
      "attack" => 65,
      "parry" => 20,
      "dodge" => 25,
      "damage" => 35,
      "lvl" => 100,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一声冷笑，一招「灵蛇九转」，身形一闪而至，一掌轻轻拍出，手臂宛若无骨，掌到中途竟连\\n",
      "force" => 280,
      "attack" => 95,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 45,
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N侧身向前，一招「地府阴风」，双掌连环拍出，一缕缕彻骨的寒气从掌心透出，将$n周围的空\\n",
      "force" => 320,
      "attack" => 110,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 60,
      "lvl" => 140,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N厉叫一声，身形忽的蜷缩如球，飞身撞向$n，一招「黄蜂吐刺」单掌如剑，直刺$n的心窝",
      "force" => 360,
      "attack" => 135,
      "parry" => 35,
      "dodge" => 30,
      "damage" => 75,
      "lvl" => 160,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一个急旋，飞身纵起，半空中一式「毒龙摆尾」，反手击向$n的$l",
      "force" => 420,
      "attack" => 150,
      "parry" => 75,
      "dodge" => 30,
      "damage" => 90,
      "lvl" => 180,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N大喝一声，运起五毒神功，一招「毒火焚身」，刹那间全身毛发尽绿，一对碧绿的双爪闪电般的朝\\n",
      "force" => 450,
      "attack" => 185,
      "parry" => 80,
      "dodge" => 40,
      "damage" => 120,
      "lvl" => 200,
      "damage_type" => "抓伤"
    }
  ]

  @impl true
  def id(), do: "qianzhu-wandushou"

  @impl true
  def valid_enable(usage), do: usage in ["hand", "parry"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "suck" => Kantele.Combat.Skills.Performs.QianzhuWandushou.Suck,
      "wan" => Kantele.Combat.Skills.Performs.QianzhuWandushou.Wan,
      "zhugu" => Kantele.Combat.Skills.Performs.QianzhuWandushou.Zhugu
    }
  end
end

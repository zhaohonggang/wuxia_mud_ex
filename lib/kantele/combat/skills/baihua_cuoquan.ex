defmodule Kantele.Combat.Skills.BaihuaCuoquan do
  @moduledoc """
  武学实装「baihua-cuoquan」（源 baihua-cuoquan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 12 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 1 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：hit_ob, perform_action_file, practice_skill, skill_improved, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/baihua_cuoquan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N单手上抬，一招查拳的「冲天炮」，对准$n的$l猛击下去",
      "force" => 420,
      "attack" => 130,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 80,
      "lvl" => 0,
      "damage_type" => "砸伤"
    },
    %{
      "action" => "$N一招燕青拳的「白鹤亮翅」，身子已向左转成弓箭步，两臂向后成钩手，呼\\n",
      "force" => 512,
      "attack" => 145,
      "parry" => 75,
      "dodge" => 10,
      "damage" => 85,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N往后一纵，施展小擒拿手的手法，双手对着$n$l处的关节直直抓去",
      "force" => 410,
      "attack" => 170,
      "parry" => 35,
      "dodge" => 35,
      "damage" => 178,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "$N左拳拉开，右拳转臂回扰，一招少林的少林长拳突然击出，带着许许风声贯向$n",
      "force" => 460,
      "attack" => 150,
      "parry" => 60,
      "dodge" => 62,
      "damage" => 90,
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "只见$N运足气力，使出八极拳中的「八极翻手式」，双掌对着$n的$l平平攻去",
      "force" => 480,
      "attack" => 160,
      "parry" => 40,
      "dodge" => 40,
      "damage" => 85,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N大喝一声，左手往$n身后一抄，右掌往$n反手击去，正是八卦掌的招式",
      "force" => 510,
      "attack" => 155,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 95,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N提气游走，左手护胸，右手一招游身八卦掌的「游空探爪」，迅速拍向$n$l",
      "force" => 510,
      "attack" => 150,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 110,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "只见$N拉开架式，双手将武当派的绵掌使得密不透风，招招不离$n的$l",
      "force" => 460,
      "attack" => 155,
      "parry" => 160,
      "dodge" => 160,
      "damage" => 105,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N突然飞身一跃而起，双手握做爪状，朝着$n的$l猛然抓去，凛然是鹰爪功的招式",
      "force" => 470,
      "attack" => 185,
      "parry" => 60,
      "dodge" => 60,
      "damage" => 155,
      "lvl" => 0,
      "damage_type" => "抓伤"
    },
    %{
      "action" => "只见$N身形一矮，双手翻滚，合抱为圈，一招太极拳「云手」直拿$n的$l",
      "force" => 350,
      "attack" => 90,
      "parry" => 230,
      "dodge" => 210,
      "damage" => 65,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "只见$N跨前一步，左手一记大擒拿手护住上盘，右手顺势一带，施一招摔碑手击向$n",
      "force" => 520,
      "attack" => 155,
      "parry" => 37,
      "dodge" => 41,
      "damage" => 103,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N一个转身，趁$n不备，反手将$n牢牢抱住猛的朝地面摔去，竟然是蒙古的摔角招式",
      "force" => 560,
      "attack" => 185,
      "parry" => 60,
      "dodge" => 75,
      "damage" => 125,
      "lvl" => 0,
      "damage_type" => "摔伤"
    }
  ]

  @impl true
  def id(), do: "baihua-cuoquan"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 80, neili: 120}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end

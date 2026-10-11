defmodule Kantele.Combat.Skills.BaihuaQuan do
  @moduledoc """
  武学实装「baihua-quan」（源 baihua-quan.c，由 translate_skill.exs 生成）

  已自动化：静态招式 11 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/baihua_quan/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N单手上抬，一招查拳的［冲天炮］，对准$n的$l猛击下去",
      "force" => 120,
      "attack" => 30,
      "parry" => 5,
      "dodge" => 5,
      "damage" => 40,
      "lvl" => 0,
      "damage_type" => "砸伤",
      "skill_name" => "查拳"
    },
    %{
      "action" => "$N一招燕青拳的［白鹤亮翅］，身子已向左转成弓箭步，两臂向后成钩手，呼\\n",
      "force" => 180,
      "attack" => 35,
      "parry" => 50,
      "dodge" => 10,
      "damage" => 55,
      "lvl" => 0,
      "damage_type" => "瘀伤",
      "skill_name" => "燕青拳"
    },
    %{
      "action" => "$N往后一纵，施展小擒拿手的手法，双手对着$n$l处的关节直直抓去",
      "force" => 220,
      "attack" => 40,
      "parry" => 15,
      "dodge" => 15,
      "damage" => 70,
      "lvl" => 0,
      "damage_type" => "抓伤",
      "skill_name" => "小擒拿手"
    },
    %{
      "action" => "$N左拳拉开，右拳转臂回扰，一招少林的大金刚拳突然击出，带着许许风声贯向$n",
      "force" => 280,
      "attack" => 60,
      "parry" => 20,
      "dodge" => 22,
      "damage" => 90,
      "lvl" => 30,
      "damage_type" => "瘀伤",
      "skill_name" => "少林大金刚拳"
    },
    %{
      "action" => "只见$N运足气力，使出八极拳中的［八极翻手式］，双掌对着$n的$l平平攻去",
      "force" => 340,
      "attack" => 55,
      "parry" => 40,
      "dodge" => 40,
      "damage" => 80,
      "lvl" => 60,
      "damage_type" => "瘀伤",
      "skill_name" => "八极拳"
    },
    %{
      "action" => "$N大喝一声，左手往$n身后一抄，右掌往$n反手击去，正是八卦掌的招式",
      "force" => 360,
      "attack" => 65,
      "parry" => 30,
      "dodge" => 30,
      "damage" => 95,
      "lvl" => 80,
      "damage_type" => "瘀伤",
      "skill_name" => "八卦掌"
    },
    %{
      "action" => "$N提气游走，左手护胸，右手一招游身八卦掌的［游空探爪］，迅速拍向$n$l",
      "force" => 420,
      "attack" => 80,
      "parry" => 45,
      "dodge" => 45,
      "damage" => 85,
      "lvl" => 100,
      "damage_type" => "瘀伤",
      "skill_name" => "游身八卦掌"
    },
    %{
      "action" => "只见$N拉开架式，把武当派的绵掌使得密不透风，招招不离$n的$l",
      "force" => 380,
      "attack" => 75,
      "parry" => 90,
      "dodge" => 90,
      "damage" => 70,
      "lvl" => 120,
      "damage_type" => "瘀伤",
      "skill_name" => "武当绵掌"
    },
    %{
      "action" => "$N突然飞身一跃而起，双手握做爪状，朝着$n的$l猛然抓去，凛然是鹰爪功的招式",
      "force" => 440,
      "attack" => 105,
      "parry" => 70,
      "dodge" => 90,
      "damage" => 105,
      "lvl" => 140,
      "damage_type" => "抓伤",
      "skill_name" => "鹰爪功"
    },
    %{
      "action" => "只见$N身形一矮，双手翻滚，一招太极拳［云手］直拿$n$l",
      "force" => 450,
      "attack" => 90,
      "parry" => 100,
      "dodge" => 90,
      "damage" => 90,
      "lvl" => 160,
      "damage_type" => "瘀伤",
      "skill_name" => "太极拳"
    },
    %{
      "action" => "$N一个转身，趁$n不备，反手将$n牢牢抱住猛的朝地面摔去，竟然是蒙古的摔角招式",
      "force" => 460,
      "attack" => 105,
      "parry" => 60,
      "dodge" => 5,
      "damage" => 105,
      "lvl" => 180,
      "damage_type" => "摔伤",
      "skill_name" => "摔角"
    }
  ]

  @impl true
  def id(), do: "baihua-quan"

  @impl true
  def valid_enable(usage), do: usage in ["claw", "cuff", "hand", "parry", "strike", "unarmed"]

  @impl true
  def practice_cost(), do: %{qi: 50, neili: 100}

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
      "cuo" => Kantele.Combat.Skills.Performs.BaihuaQuan.Cuo
    }
  end
end

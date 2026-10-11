defmodule Kantele.Combat.Skills.LuohanJian do
  @moduledoc """
  武学实装「luohan-jian」（源 luohan-jian.c，由 translate_skill.exs 生成）

  已自动化：静态招式 9 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/luohan_jian/
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N握紧手中$w一招「来去自如」点向$n的$l",
      "force" => 70,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 50,
      "damage" => 40,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "来去自如"
    },
    %{
      "action" => "$N一招「日月无光」，无数$w上下刺出，直向$n逼去",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 20,
      "damage" => 40,
      "lvl" => 20,
      "damage_type" => "刺伤",
      "skill_name" => "日月无光"
    },
    %{
      "action" => "$N向前跨上一步，手中$w使出「剑气封喉」直刺$n的喉部",
      "force" => 100,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 50,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "剑气封喉"
    },
    %{
      "action" => "$N虚恍一步，使出「心境如水」手中$w直刺$n的要害",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 80,
      "lvl" => 60,
      "damage_type" => "刺伤",
      "skill_name" => "心境如水"
    },
    %{
      "action" => "只见$N抡起手中的$w，使出「佛光普照」万点金光直射$n",
      "force" => 90,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 70,
      "damage" => 110,
      "lvl" => 80,
      "damage_type" => "刺伤",
      "skill_name" => "佛光普照"
    },
    %{
      "action" => "$N抡起手中的$w，使出「风行叶落」无数剑光直射$n",
      "force" => 120,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 60,
      "damage" => 120,
      "lvl" => 100,
      "damage_type" => "刺伤",
      "skill_name" => "风行叶落"
    },
    %{
      "action" => "$N使出「声东击西」，手中$w如刮起狂风一般闪烁不定，刺向$n",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 80,
      "damage" => 140,
      "lvl" => 120,
      "damage_type" => "刺伤",
      "skill_name" => "声东击西"
    },
    %{
      "action" => "$N随手使出剑法之奥义「无影无踪」，手中$w如鬼魅一般铺天盖地的刺向$n",
      "force" => 200,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 90,
      "damage" => 160,
      "lvl" => 150,
      "damage_type" => "刺伤",
      "skill_name" => "「无影无踪」"
    },
    %{
      "action" => "",
      "force" => 280,
      "attack" => 0,
      "parry" => 0,
      "dodge" => 100,
      "damage" => 180,
      "lvl" => 220,
      "damage_type" => "刺伤",
      "skill_name" => "HIY「剑气合一」"
    }
  ]

  @impl true
  def id(), do: "luohan-jian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword"]

  @impl true
  def practice_cost(), do: %{qi: 65, neili: 62}

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
      "wuxing" => Kantele.Combat.Skills.Performs.LuohanJian.Wuxing
    }
  end
end

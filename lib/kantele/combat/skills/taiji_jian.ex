defmodule Kantele.Combat.Skills.TaijiJian do
  @moduledoc """
  太极剑法（对照 `kungfu/skill/taiji-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/taiji_jian/`。

  学习门槛 `valid_learn/2`（int>=26 / max_neili>=1500 / force>=200 /
  taiji-quan>=100 / sword>=100 / sword>=taiji-jian）与练招消耗 `practice_cost`
  （LPC 扣 qi 50 / neili 64，须持剑）已按 LPC 迁移（2026-10-30）。
  招式表（query_action）的静态招式未在本文件建模，沿用基类占位（TODO）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N虚步提腰，一招「蜻蜓点水」，手中$w轻轻颤动，一剑剑点向$n的$l",
      "force" => 25,
      "dodge" => 20,
      "parry" => 25,
      "lvl" => 0
    },
    %{
      "action" => "$N向前跨上一步，左手剑诀，右手$w使出一式「指南针」直刺$n的$l",
      "force" => 30,
      "dodge" => 25,
      "parry" => 30,
      "lvl" => 6
    },
    %{
      "action" => "$N身形往右一挫，左手剑诀，右手$w使出一式「大魁星」刺向$n的$l",
      "force" => 30,
      "dodge" => 35,
      "parry" => 35,
      "lvl" => 12
    },
    %{
      "action" => "$N双膝下沉，右手$w使出一式「探海式」，由下而上疾刺$n的$l",
      "force" => 35,
      "dodge" => 35,
      "parry" => 40,
      "lvl" => 15
    },
    %{
      "action" => "$N一招「燕子掠波」，$w自上而下划出一个大弧，平平地向$n的$l挥去",
      "force" => 35,
      "dodge" => 45,
      "parry" => 45,
      "lvl" => 18
    },
    %{
      "action" => "$N上身往左侧一拧，一招「乌龙摆尾」，右手$w反手向$n的$l挥去",
      "force" => 35,
      "dodge" => 45,
      "parry" => 55,
      "lvl" => 21
    },
    %{
      "action" => "$N一招「右拦扫」，一招「左拦扫」，剑锋平指，一气呵成横扫$n的$l",
      "force" => 40,
      "dodge" => 60,
      "parry" => 55,
      "lvl" => 24
    },
    %{
      "action" => "$N左腿提膝，手中$w斜指，一招「宿鸟投林」刺向$n的$l",
      "force" => 40,
      "dodge" => 55,
      "parry" => 60,
      "lvl" => 27
    },
    %{
      "action" => "$N一招「青龙出水」，$w自下而上划出一个大弧，平平地挥向$n的$l",
      "force" => 45,
      "dodge" => 65,
      "parry" => 65,
      "lvl" => 30
    },
    %{
      "action" => "$N使出「三环套月」，$w划出三个圆圈，剑锋直出，绵绵不断划向$n的$l",
      "force" => 45,
      "dodge" => 70,
      "parry" => 70,
      "lvl" => 35
    },
    %{
      "action" => "$N一招「风卷荷叶」，$w轻灵地划出几个圆弧，迅速地向$n的$l挥去",
      "force" => 50,
      "dodge" => 75,
      "parry" => 80,
      "lvl" => 40
    },
    %{
      "action" => "$N一招「虎抱头」，$w划出一个左低右高的大弧，斜斜地斩向$n的$l",
      "force" => 50,
      "dodge" => 75,
      "parry" => 80,
      "lvl" => 45
    },
    %{
      "action" => "$N使出「狮子摇头」，$w由右向左划出一个大８字，将$n圈在其中",
      "force" => 55,
      "dodge" => 85,
      "parry" => 80,
      "lvl" => 50
    },
    %{
      "action" => "$N左脚踏实，右脚虚点，一招「仙人指路」，右手$w带着一团剑花，逼向$n的$l",
      "force" => 55,
      "dodge" => 95,
      "parry" => 80,
      "lvl" => 60
    },
    %{
      "action" => "$N轻轻跃起，一招「野马跳涧」，$w在半空中化为一圈银芒，落向$n的$l",
      "force" => 60,
      "attack" => 3,
      "dodge" => 95,
      "parry" => 90,
      "lvl" => 80
    },
    %{
      "action" => "$N两腿前箭后弓，一招「射雁式」，右手$w直刺$n的$l",
      "force" => 65,
      "attack" => 5,
      "dodge" => 100,
      "parry" => 100,
      "lvl" => 100
    },
    %{
      "action" => "$N一招「小魁星」，身形往左一挫，左手剑诀，右手$w平平地向$n的$l挥去",
      "force" => 70,
      "attack" => 7,
      "dodge" => 100,
      "parry" => 105,
      "damage" => 1,
      "lvl" => 110
    },
    %{
      "action" => "$N猱身扑上，一招「白猿献果」，手中$w斜斜地向$n的$l挥去",
      "force" => 75,
      "attack" => 10,
      "dodge" => 110,
      "parry" => 120,
      "damage" => 2,
      "lvl" => 120
    },
    %{
      "action" => "$N一招「迎风掸尘」，$w看似随意地一挥，$n却陡觉一股劲气迎面袭来。",
      "force" => 80,
      "attack" => 12,
      "dodge" => 105,
      "parry" => 115,
      "damage" => 4,
      "lvl" => 130
    },
    %{
      "action" => "$N一招「顺水推舟」，$w自上而下划出一个大弧，平平地向$n的$l挥去。",
      "force" => 85,
      "attack" => 15,
      "dodge" => 115,
      "parry" => 125,
      "damage" => 5,
      "lvl" => 140
    },
    %{
      "action" => "$N一招「流星赶月」，$w疾刺$n的$l",
      "force" => 90,
      "attack" => 18,
      "dodge" => 135,
      "parry" => 125,
      "damage" => 8,
      "lvl" => 150
    },
    %{
      "action" => "$N突然盘蹲下身来，一招「海底捞月」，$w自下而上地向$n的$l挥去",
      "force" => 95,
      "attack" => 20,
      "dodge" => 125,
      "parry" => 125,
      "damage" => 12,
      "lvl" => 160
    },
    %{
      "action" => "$N一招「挑帘式」，$w自下而上徐徐划出一个大弧，平平地向$n的$l挥去",
      "force" => 100,
      "attack" => 22,
      "dodge" => 135,
      "parry" => 145,
      "damage" => 17,
      "lvl" => 170
    },
    %{
      "action" => "$N一招「黄蜂入洞」，$w自上而下划出一个大弧，平平地向$n的$l挥去",
      "force" => 105,
      "attack" => 25,
      "dodge" => 140,
      "parry" => 165,
      "damage" => 20,
      "lvl" => 180
    },
    %{
      "action" => "$N一招「大鹏展翅」，身形跃起，右手$w刺向$n的$l",
      "force" => 110,
      "attack" => 28,
      "dodge" => 145,
      "parry" => 155,
      "damage" => 22,
      "lvl" => 190
    },
    %{
      "action" => "$N一招「车轮剑」，$w化作一片银盘，平平地向$n的$l卷去",
      "force" => 115,
      "attack" => 28,
      "dodge" => 155,
      "parry" => 175,
      "damage" => 25,
      "lvl" => 200
    },
    %{
      "action" => "$N左脚轻点地面，身形往前一扑，一招「天马行空」，$w向$n的$l挥去",
      "force" => 120,
      "attack" => 29,
      "dodge" => 165,
      "parry" => 180,
      "damage" => 31,
      "lvl" => 210
    },
    %{
      "action" => "$N一招「风扫梅花」，身体跃在半空，手中$w扫向$n的$l",
      "force" => 125,
      "attack" => 32,
      "dodge" => 175,
      "parry" => 185,
      "damage" => 33,
      "lvl" => 220
    },
    %{
      "action" => "$N一招「却步抽剑」，左脚跃步落地，$w回抽，反手勾向$n的$l",
      "force" => 130,
      "attack" => 35,
      "dodge" => 185,
      "parry" => 200,
      "damage" => 34,
      "lvl" => 230
    },
    %{
      "action" => "$N右腿半屈般蹲，一招「如封似闭」，剑尖虚指，转身撩向$n的$l",
      "force" => 135,
      "attack" => 38,
      "dodge" => 185,
      "parry" => 220,
      "damage" => 37,
      "lvl" => 240
    },
    %{
      "action" => "$N回身拧腰，右手虚抱，一招「拨云瞻日」，$w中宫直进，刺向$n的$l",
      "force" => 150,
      "attack" => 40,
      "dodge" => 220,
      "parry" => 220,
      "damage" => 40,
      "lvl" => 250
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 太极剑之极意",
    "lvl" => 350,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "taiji-jian"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "taiji-jian", 0) < 100 or
         is_nil(victim.weapon_name) or victim.weapon_skill_type != "sword" do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "force", 0) + mp
      dp = div(Map.get(victim.skills, "parry", 0), 2) + Map.get(victim.skills, "taiji-jian", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, taiji_jian_msg(rng, victim.weapon_name)}
      else
        if mp >= 100 do
          {damage, taiji_jian_fail_msg(rng, victim.weapon_name)}
        else
          {damage, nil}
        end
      end
    end
  end

  defp taiji_jian_msg(rng, weapon) do
    case rng.(3) - 1 do
      0 -> "$n一抖手中的#{weapon}，划出了一个圆圈，竟然让$N的攻击全然落空。\n"
      1 -> "$n手中#{weapon}轻挑，正指向$N攻势中的破绽。\n"
      _ -> "$n晃动手中的#{weapon}，不住的变幻剑势，让$N完全无法捕捉到力道。\n"
    end
  end

  defp taiji_jian_fail_msg(rng, weapon) do
    case rng.(2) - 1 do
      0 -> "$n一抖手中的#{weapon}，划出了一个圆圈，$N理也不理，当即挥招直入，进袭$n。\n"
      _ -> "$n手中#{weapon}轻挑，正指向$N攻势中的破绽，可是$N身形一变，破绽立刻不成为破绽。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 int>=26 / max_neili>=1500 / force>=200 /
  # taiji-quan>=100 / sword>=100 / sword>=taiji-jian
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      stats.int < 26 ->
        {:error, "你先天悟性太差，难以领会太极剑的要诣。\n"}

      not is_nil(max_neili) and max_neili < 1500 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "taiji-quan") < 100 ->
        {:error, "你的太极拳火候太浅。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法水平有限，无法修炼太极剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的太级剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 50 / neili 64（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 50, neili: 64}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, attacker) do
    Skill.pick_action_with_ultimate(
      @actions,
      level,
      attacker,
      @ultimate,
      &ultimate_values/2,
      rng
    )
  end

  @impl true
  def perform_list() do
    %{
      "chan" => Kantele.Combat.Skills.Performs.TaijiJian.Chan,
      "jia" => Kantele.Combat.Skills.Performs.TaijiJian.Jia,
      "sui" => Kantele.Combat.Skills.Performs.TaijiJian.Sui,
      "zhenwu" => Kantele.Combat.Skills.Performs.TaijiJian.Zhenwu,
      "zhuan" => Kantele.Combat.Skills.Performs.TaijiJian.Zhuan
    }
  end
  def actions(), do: @actions

  defp ultimate_values(attacker, rng) do
    dodge = Skill.skill_of(attacker, "dodge")
    force = Skill.skill_of(attacker, "force")
    parry = Skill.skill_of(attacker, "parry")
    sword = Skill.skill_of(attacker, "sword")
    r = &Skill.lpc_random(rng, &1)
    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(sword, 4) + r.(div(sword, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(force, 2))
    }
  end

end

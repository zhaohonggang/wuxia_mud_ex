defmodule Kantele.Combat.Skills.QixianWuxingjian do
  @moduledoc """
  七弦无形剑（对照 `kungfu/skill/qixian-wuxingjian.c`）

  双载体：`valid_enable` 支持 `unarmed` / `sword` / `parry` / `tanqin-jifa`。

  已按 LPC 迁移（2026-10-31）：

    - 两张静态招式表各 7 式：`@action_unarmed`（lvl 0/40/80/120/160/200/240）
      与 `@action_sword`（同 lvl 阶梯）。`query_action/3` 按「是否持械」分表
      （LPC `if (! weapon)`）。
    - 两张表的**等级过滤符号不同**（源内不对称，已保真）：空手表用
      `level >= action_unarmed[i-1]["lvl"]`，持械表用 `level > action_sword[i-1]["lvl"]`。
      故 0 级持械时持械表一应不合，源 `query_action` 落到末尾返回 0（无招式）；
      本实现回落首式 —— 引擎 `select_action` 拿到 `%{}` 会在出招文案拼接处崩，
      属**有意偏差**（仅 0 级且持械这一退化场景）。
    - `valid_learn/2`：`force >= 270` / `max_neili >= 3000` / `unarmed >= 180` /
      `sword >= 180` / `tanqin-jifa >= 100` / 四门技能等级不得低于本门
      （`tanqin-jifa` 只要求 `>= 本门 / 3`）。

  `hit_ob/5`（七弦音攻）已按源迁移：条件门、额外创伤、`start_busy(1)`、穴道文案、
  无创伤气血伤害（`extra[:plain_damage]`）与攻击方内力自耗（`extra[:attacker_neili]`）。

  招式里的 `"weapon"` 字段（`无形剑气` / `破体无形剑气`）在 LPC 只用于替换出招文案中的
  武器名，引擎不消费，保留在表内仅供展示。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @action_unarmed [
    %{
      "action" =>
        "$N使一招「弦外有音」，双手猛然击出，空气中暴响出“呜”的一声，一股气流如风一般卷向$n的$l",
      "force" => 350,
      "attack" => 80,
      "dodge" => 75,
      "parry" => 55,
      "damage" => 70,
      "lvl" => 0,
      "weapon" => "无形剑气",
      "skill_name" => "弦外有音",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N使出一招「吴阳琴音」，弹指向上一刺，接着再向下直划而出，顿时两股剑气如利刀般砍向$n",
      "force" => 370,
      "attack" => 81,
      "dodge" => 65,
      "parry" => 65,
      "damage" => 72,
      "lvl" => 40,
      "weapon" => "无形剑气",
      "skill_name" => "吴阳琴音",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N一声暴喝，陡然一招「天河紫气」，单手向$n凌空一劈，顿时一股劲气伴随着破空之声袭向$p$l",
      "force" => 410,
      "attack" => 85,
      "dodge" => 55,
      "parry" => 55,
      "damage" => 88,
      "lvl" => 80,
      "weapon" => "无形剑气",
      "skill_name" => "天河紫气",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N双掌缤纷拍出，劲气纵横，正是一式「七盘绝刹」，刹时“飕飕”破空声悠然而响，击向$n$l",
      "force" => 430,
      "attack" => 79,
      "dodge" => 65,
      "parry" => 35,
      "damage" => 83,
      "lvl" => 120,
      "weapon" => "破体无形剑气",
      "skill_name" => "七盘绝刹",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N凭空一指，一招「黄龙吐珠」斜斜袭出，手掌陡然生出半寸吞吐不定的青芒刺向$n的$l",
      "force" => 460,
      "attack" => 75,
      "dodge" => 91,
      "parry" => 85,
      "damage" => 78,
      "lvl" => 160,
      "weapon" => "破体无形剑气",
      "skill_name" => "黄龙吐珠",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N双手向外一分，使一招「清心普善」，手若拨琴弄萧，弹射出一股破体剑气，直涌$n$l而去",
      "force" => 490,
      "attack" => 105,
      "dodge" => 35,
      "parry" => 24,
      "damage" => 98,
      "lvl" => 200,
      "weapon" => "破体无形剑气",
      "skill_name" => "清心普善",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N忽然眼中精光四射，一招「星河气旋」使出，顿时数股淳厚无比的剑气从指尖激射而出，直逼$n",
      "force" => 480,
      "attack" => 95,
      "dodge" => 75,
      "parry" => 75,
      "damage" => 93,
      "lvl" => 240,
      "weapon" => "破体无形剑气",
      "skill_name" => "星河气旋",
      "damage_type" => "刺伤"
    }
  ]

  # 持械表：源无 "skill_name"、无 "weapon"（保真不补）
  @action_sword [
    %{
      "action" => "$N使一招「弦外有音」，手中$w弹出一股气流，如风一般卷向$n的$l",
      "force" => 140,
      "attack" => 60,
      "dodge" => 15,
      "parry" => 25,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N伸指在$w上一弹，一招「吴阳琴音」，整个剑身顿时发出一声龙吟，呼啸着斩向$n的$l",
      "force" => 150,
      "attack" => 80,
      "dodge" => 60,
      "parry" => 5,
      "damage" => 70,
      "lvl" => 40,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N一招「天河紫气」，手中$w剑芒顿时暴长数尺，光华四射，直直削向$n的$l",
      "force" => 200,
      "attack" => 80,
      "dodge" => 0,
      "parry" => 10,
      "damage" => 90,
      "lvl" => 80,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N手中$w一式「七盘绝刹」对准$n的$l一连刺出数剑，刹时剑气纵横，势不可挡",
      "force" => 250,
      "attack" => 80,
      "dodge" => 10,
      "parry" => 15,
      "damage" => 92,
      "lvl" => 120,
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N的$w凭空一指，一招「黄龙吐珠」直直刺出，剑尖陡然生出半寸吞吐不定的青芒刺向$n的$l",
      "force" => 225,
      "attack" => 63,
      "dodge" => 5,
      "parry" => 5,
      "damage" => 103,
      "lvl" => 160,
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N手中$w向外一分，使一招「清心普善」，单手在剑身轻轻弹拨，顿时一股剑气直涌$n$l而去",
      "force" => 250,
      "attack" => 80,
      "dodge" => 10,
      "parry" => 5,
      "damage" => 120,
      "lvl" => 200,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N忽然眼中精光四射，一招「星河气旋」，一股淳厚无比的剑气从$w上激射而出，直逼$n",
      "force" => 300,
      "attack" => 100,
      "dodge" => -15,
      "parry" => -15,
      "damage" => 140,
      "lvl" => 240,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "qixian-wuxingjian"

  @impl true
  def valid_enable(usage), do: usage in ["parry", "sword", "tanqin-jifa", "unarmed"]

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 100"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 100}

  # 源 `string *xue_name`：18 个穴位名（命中文案随机取一）
  @xue_names ~w(劳宫穴 膻中穴 曲池穴 关元穴 曲骨穴 中极穴 承浆穴 天突穴 百会穴
                幽门穴 章门穴 大横穴 紫宫穴 冷渊穴 天井穴 极泉穴 清灵穴 至阳穴)

  @doc """
  命中回调：七弦音攻（LPC `hit_ob`）

  条件（全部满足才触发）：

      skill >= 180 / max_neili >= 2500 / neili >= 500 /
      max_neili >= 对方 max_neili / 对方 max_neili >= 10 /
      对方未 busy / damage_bonus >= 150

  效果：`start_busy(1)` + 额外创伤 `skill/8 + damage_bonus/5` +
  无创伤气血伤害 `skill/5 + damage_bonus/3`（`extra[:plain_damage]`）+
  攻击方内力自耗 100（`extra[:attacker_neili]`）。
  """
  @impl true
  def hit_ob(attacker, victim, damage_bonus, _factor, rng) do
    skill = Map.get(attacker.skills, "qixian-wuxingjian", 0)
    me_max_neili = Map.get(attacker, :max_neili, 0)
    me_neili = Map.get(attacker, :neili, 0)
    victim_max_neili = Map.get(victim, :max_neili, 0)

    cond do
      skill < 180 -> {0, nil}
      me_max_neili < 2500 -> {0, nil}
      me_neili < 500 -> {0, nil}
      me_max_neili < victim_max_neili -> {0, nil}
      victim_max_neili < 10 -> {0, nil}
      Map.get(victim, :busy, 0) > 0 -> {0, nil}
      damage_bonus < 150 -> {0, nil}
      true ->
        name = Enum.at(@xue_names, Skill.lpc_random(rng, length(@xue_names)))
        wound = div(skill, 8) + div(damage_bonus, 5)

        msg =
          "只听一阵淳厚的弦音从$N处传来，$n『#{name}』顿时受震，两耳轰鸣，全身真气乱窜不止！\n"

        {wound, msg, [{"busy", %{"rounds" => 1}}],
         %{
           plain_damage: div(skill, 5) + div(damage_bonus, 3),
           attacker_neili: 100
         }}
    end
  end

  # LPC valid_learn：force>=270 / max_neili>=3000 / unarmed>=180 / sword>=180 /
  # tanqin-jifa>=100 / force>=own / unarmed>=own / sword>=own / tanqin-jifa>=own/3
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)
    lvl = Stats.skill(stats, id())

    cond do
      Stats.skill(stats, "force") < 270 ->
        {:error, "你的内功火候不够，无法修炼七弦无形剑。\n"}

      not is_nil(max_neili) and max_neili < 3000 ->
        {:error, "你的内力太弱，无法修炼七弦无形剑。\n"}

      Stats.skill(stats, "unarmed") < 180 ->
        {:error, "你的基本拳脚火候不够，无法修炼七弦无形剑。\n"}

      Stats.skill(stats, "sword") < 180 ->
        {:error, "你的基本剑法火候不够，无法修炼七弦无形剑。\n"}

      Stats.skill(stats, "tanqin-jifa") < 100 ->
        {:error, "弹琴技法水平有限，无法修炼七弦无形剑。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的内功修为有限，无法领会更高深的七弦无形剑。\n"}

      Stats.skill(stats, "unarmed") < lvl ->
        {:error, "你的基本拳脚水平有限，无法领会更高深的七弦无形剑。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的七弦无形剑。\n"}

      Stats.skill(stats, "tanqin-jifa") < div(lvl, 3) ->
        {:error, "你对琴学的了解不够深入，无法领会更高深的七弦无形剑。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc """
  带角色上下文选招：持械走持械表、空手走空手表

  LPC 原文：

      if (! weapon)
          for (i = sizeof(action_unarmed); i > 0; i--)
              if (level >= action_unarmed[i-1]["lvl"])
                  return action_unarmed[NewRandom(i, 20, level/5)];
      else
          for (i = sizeof(action_sword); i > 0; i--)
              if (level > action_sword[i-1]["lvl"])
                  return action_sword[NewRandom(i, 20, level/5)];
  """
  @impl true
  def query_action(level, rng, attacker) do
    if Skill.weapon?(attacker) do
      Skill.pick_action(@action_sword, level, rng)
    else
      pick_action_ge(@action_unarmed, level, rng)
    end
  end

  # 源空手表用 `level >= lvl`（与基类 pick_action 的 `level > lvl` 不同）
  defp pick_action_ge(actions, level, rng) do
    case Enum.count(actions, fn action -> level >= Map.get(action, "lvl", 0) end) do
      0 -> List.first(actions) || %{}
      count -> Enum.at(actions, Skill.new_random(count, rng))
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    pick_action_ge(@action_unarmed, level, rng)
  end

  @doc "招式名 -> 招式数据（空手表；持械表见 `sword_actions/0`）"
  def actions(), do: @action_unarmed

  @doc "持械招式表（供 score/look 与测试）"
  def sword_actions(), do: @action_sword

  @impl true
  def perform_list() do
    %{
      "shan" => Kantele.Combat.Skills.Performs.QixianWuxingjian.Shan,
      "yin" => Kantele.Combat.Skills.Performs.QixianWuxingjian.Yin,
      "zhu" => Kantele.Combat.Skills.Performs.QixianWuxingjian.Zhu
    }
  end
end

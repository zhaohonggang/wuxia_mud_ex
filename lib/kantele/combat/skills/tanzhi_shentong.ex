defmodule Kantele.Combat.Skills.TanzhiShentong do
  @moduledoc """
  弹指神通（对照 `kungfu/skill/tanzhi-shentong.c`）

  三载体：`valid_enable` 支持 `finger` / `parry` / `throwing`。

  已按 LPC 迁移（2026-10-31）：

    - 6 式静态招式（源无 `lvl` 字段 ⇒ 全部 0）+ 第 7 式动态「极意」（`lvl 200`）。
    - **选招是均匀随机、且不过滤等级**（源 `action_finger[random(sizeof(action_finger))]`）——
      即 0 级也可能抽到「极意」。此处保真复现（不走 `NewRandom`、不做 `lvl` 过滤）。
    - 「极意」五项数值由 `query_action/3` 按出招者快照实时生成，见 `ultimate_values/2`。
    - `valid_learn/2`：`dex >= 34`（源 `query("dex")`，裸属性）/ `force >= 150` /
      `max_neili >= 2000` / `finger >= 150` / `finger >= 本门`。

  `valid_damage/5`（2017 年新增的「特防」：指劲弹破绽）此前已迁移，本批未改。

  `hit_ob/5`（弹指穴道：`damage_bonus >= 150` + `neili >= 800` + 本门/`jingluo-xue` >= 100
  + 对方未 busy → `start_busy(2)` + 额外创伤 + 穴道文案）已迁移；对方 `neili` 削减因
  `hit_ob` 契约无通道未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  # 6 式静态招式：源无 "lvl"（视为 0）
  @actions [
    %{
      "action" => "$N右指划了个半圈，一式「划天裂地」自上而下划向$n的全身",
      "force" => 440,
      "attack" => 100,
      "parry" => 50,
      "dodge" => 75,
      "damage" => 131,
      "lvl" => 0,
      "skill_name" => "划天裂地",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N左掌护胸，一招「我心悠悠」，右指欲举无力指向$n的额头",
      "force" => 410,
      "attack" => 90,
      "parry" => 65,
      "dodge" => 90,
      "damage" => 103,
      "lvl" => 0,
      "skill_name" => "我心悠悠",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N双手齐出，一式「千夫所指」，顿时一道劲疾射$n的$l处",
      "force" => 420,
      "attack" => 110,
      "parry" => 65,
      "dodge" => 85,
      "damage" => 121,
      "lvl" => 0,
      "skill_name" => "千夫所指",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N仰天一叹，一招「弹指人生」，双手幻出重重指影，点向$n的$l",
      "force" => 400,
      "attack" => 100,
      "parry" => 70,
      "dodge" => 95,
      "damage" => 98,
      "lvl" => 0,
      "skill_name" => "弹指人生",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一式「笑指天南」，左掌蓄式，右指弹出一缕指风点向$n的$l",
      "force" => 430,
      "attack" => 95,
      "parry" => 45,
      "dodge" => 100,
      "damage" => 105,
      "lvl" => 0,
      "skill_name" => "笑指天南",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N施展出一招「擎天一指」，蓄集全身力气，一指点向$n的$l",
      "force" => 450,
      "attack" => 105,
      "parry" => 65,
      "dodge" => 90,
      "damage" => 130,
      "lvl" => 0,
      "skill_name" => "擎天一指",
      "damage_type" => "刺伤"
    }
  ]

  # 第 7 式「极意」的静态部分；五项数值由 ultimate_values/2 出招时生成
  @ultimate %{
    "action" => "$N凝神静气，使出极招 弹指神通之极意 ",
    "lvl" => 200,
    "skill_name" => "极意",
    "damage_type" => "刺伤"
  }

  @impl true
  def id(), do: "tanzhi-shentong"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "tanzhi-shentong", 0) < 150 or
         victim.busy != 0 or
         Map.get(victim.mapped, "finger") != "tanzhi-shentong" or
         Map.get(victim.mapped, "throwing") != "tanzhi-shentong" or
         not is_nil(victim.weapon_name) do
      {damage, nil}
    else
      ap = Map.get(attacker.skills, "force", 0)
      dp = div(Map.get(victim.skills, "parry", 0), 2) + Map.get(victim.skills, "tanzhi-shentong", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, "$n不理会$N的攻势，随意弹出一指，指劲正指向$N招式中的破绽。\n"}
      else
        {damage, nil}
      end
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry", "throwing"]

  @doc "练招消耗：LPC practice_skill 扣 qi 68 / neili 67"
  @impl true
  def practice_cost(), do: %{qi: 68, neili: 67}

  # 源 `string *xue_name`：18 个穴位名（命中文案随机取一）
  @xue_names ~w(劳宫穴 膻中穴 曲池穴 关元穴 曲骨穴 中极穴 承浆穴 天突穴 百会穴
                幽门穴 章门穴 大横穴 紫宫穴 冷渊穴 天井穴 极泉穴 清灵穴 至阳穴)

  @doc """
  命中回调：弹指穴道（LPC `hit_ob`）

  条件（全部满足才触发）：

      damage_bonus >= 150 / neili >= 800 / 本门 >= 100 / jingluo-xue >= 100 / 对方未 busy

  效果：`start_busy(2)` + 额外创伤 `(damage_bonus - 100) / 4`。

  未建模（引擎无通道）：对方 `neili` 削减（`<= damage_bonus/4 + 50` 时清零，否则减
  `damage_bonus/4`）—— `hit_ob` 契约只能回传创伤/文案/状态。
  """
  @impl true
  def hit_ob(attacker, victim, damage_bonus, _factor, rng) do
    skill = Map.get(attacker.skills, "tanzhi-shentong", 0)
    me_neili = Map.get(attacker, :neili, 0)
    jingluo = Map.get(attacker.skills, "jingluo-xue", 0)

    cond do
      damage_bonus < 150 -> {0, nil}
      me_neili < 800 -> {0, nil}
      skill < 100 -> {0, nil}
      jingluo < 100 -> {0, nil}
      Map.get(victim, :busy, 0) > 0 -> {0, nil}
      true ->
        name = Enum.at(@xue_names, Skill.lpc_random(rng, length(@xue_names)))
        wound = div(damage_bonus - 100, 4)

        msg = "只听“飕”的一声，$n被$N凌空弹射出的指气点中#{name}，全身登时一阵酸麻。\n"

        {wound, msg, [{"busy", %{"rounds" => 2}}]}
    end
  end

  # LPC valid_learn：dex>=34 / force>=150 / max_neili>=2000 / finger>=150 / finger>=own
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      # 源 me->query("dex")：裸属性，非 query_dex 派生值
      Stats.dex(stats) < 34 ->
        {:error, "你的先天身法不足，无法修炼弹指神通。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，无法修炼弹指神通。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力修为太弱，无法修炼弹指神通。\n"}

      Stats.skill(stats, "finger") < 150 ->
        {:error, "你的基本指法火候不够，无法学弹指神通。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本指法水平有限，无法领会更高深的弹指神通。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc """
  带出招者上下文选招：**均匀随机**（含「极意」），不做等级过滤

  LPC 原文：

      mapping query_action(object me, object weapon)
      {
              return action_finger[random(sizeof(action_finger))];
      }

  「极意」的动态五项见 `ultimate_values/2`。
  """
  @impl true
  def query_action(_level, rng, attacker) do
    table = @actions ++ [Map.merge(@ultimate, ultimate_values(attacker, rng))]
    Enum.at(table, Skill.lpc_random(rng, length(table)))
  end

  # 与 huashan-jian 的「极意」公式相同（源内同构）
  defp ultimate_values(attacker, rng) do
    force = Skill.skill_of(attacker, "force")
    finger = Skill.skill_of(attacker, "finger")
    dodge = Skill.skill_of(attacker, "dodge")
    parry = Skill.skill_of(attacker, "parry")
    r = &Skill.lpc_random(rng, &1)

    %{
      "force" => div(force, 2) + r.(force),
      "attack" => div(finger, 4) + r.(div(finger, 2)),
      "dodge" => div(dodge, 6) + r.(div(force, 3)),
      "parry" => div(parry, 6) + r.(div(parry, 3)),
      "damage" => div(force, 4) + r.(div(finger, 2))
    }
  end

  # 无出招者上下文（展示/测试）：动态字段按 0 处理
  @impl true
  def query_action(_level, rng \\ &:rand.uniform/1) do
    table =
      @actions ++
        [
          Map.merge(@ultimate, %{
            "force" => 0,
            "attack" => 0,
            "dodge" => 0,
            "parry" => 0,
            "damage" => 0
          })
        ]

    Enum.at(table, Skill.lpc_random(rng, length(table)))
  end

  @doc "招式名 -> 招式数据（供 score/look 展示；「极意」动态字段需 `query_action/3`）"
  def actions(), do: @actions

  @doc "第 7 式「极意」的静态部分"
  def ultimate(), do: @ultimate

  @impl true
  def perform_list() do
    %{
      "ding" => Kantele.Combat.Skills.Performs.TanzhiShentong.Ding,
      "po" => Kantele.Combat.Skills.Performs.TanzhiShentong.Po,
      "xiao" => Kantele.Combat.Skills.Performs.TanzhiShentong.Xiao,
      "zhuan" => Kantele.Combat.Skills.Performs.TanzhiShentong.Zhuan
    }
  end
end

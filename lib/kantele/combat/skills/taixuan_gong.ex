defmodule Kantele.Combat.Skills.TaixuanGong do
  @moduledoc """
  武学实装「taixuan-gong」（源 taixuan-gong.c）

  太玄功（`inherit FORCE` 的绝学内功）。LPC 的招式表变量名是 **`actionf`** 而不是
  `action`（全库仅这 6 个绝学如此），`translate_skill.exs` 只认 `action`，所以
  生成时整表丢失 —— 本文件已按源补回：

  - `@actions`：`actionf`，空手时用（6 式）
  - `@actions_weapon`：`actionw`，持械时用（5 式）
  - `@actions_bad`：`actionbad`，识字的「胡乱使出」兜底（1 式）

  LPC 的选招是 `weapon ? actionw[random(sizeof(actionw))] : actionf[random(sizeof(actionw))]`
  —— 注意**两张表长度不同时用 `sizeof(actionw)` 索引 `actionf` 是源里的 off-by-one**，
  这里按各自表的长度选（`Kantele.Combat.Skill.pick_action_for/5`），不照抄该缺陷。

  **literate 分支**：LPC `query_action` 里识字就 `return actionbad[0]`（只会「胡乱使出」，
  `@actions_bad` 10/10/10/10/10）；`valid_enable` 里识字则 `usage == 0` 恒假 → **全拒**。
  **enable_weapon 分支**：`can_learned/taixuan-gong/enable_weapon` 之后按
  `sword` / `blade` 与 `taixuan-gong` 的等级关系放开剑或刀。

  未迁移：`perform`/`exert` 的具体效果、`difficult_level`、`practice_skill` 门槛
  （路由骨架已由 `perform_list`/`exert_list` 给出）。
  """

  use Kantele.Combat.Skill

  @actions [
    %{
      "action" => "$N双手一举，一股劲气澎湃汹涌而来，逼得$n踉踉后退",
      "force" => 540,
      "attack" => 220,
      "parry" => 120,
      "dodge" => 120,
      "damage" => 155,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N右手伸出，霎时一股气流激射而出袭向$n",
      "force" => 560,
      "attack" => 240,
      "parry" => 90,
      "dodge" => 60,
      "damage" => 230,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N大喝一声，左掌一抖，顿时一股气流向$n脸上涌去",
      "force" => 570,
      "attack" => 235,
      "parry" => 135,
      "dodge" => 155,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N猱身而上，全身真气暴发，双掌猛地拍向$n",
      "force" => 580,
      "attack" => 250,
      "parry" => 75,
      "dodge" => 120,
      "damage" => 295,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身法陡快，忽左忽又，突然间$N双掌连连拍出，数股太玄内劲已射向$n",
      "force" => 580,
      "attack" => 265,
      "parry" => 125,
      "dodge" => 140,
      "damage" => 260,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N突然间左手一捺，封住$n退路，右手掌力汹涌而出",
      "force" => 580,
      "attack" => 280,
      "parry" => 145,
      "dodge" => 125,
      "damage" => 380,
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
  ]

  @actions_weapon [
    %{
      "action" => "$N攻势如虹，气势非凡，$w忽隐忽现，捉摸不定向$n慢慢攻去",
      "force" => 510,
      "attack" => 180,
      "parry" => 125,
      "dodge" => 115,
      "damage" => 325,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N手中的$w龙吟不定，犹如长江滚滚而来，将$n笼罩",
      "force" => 510,
      "attack" => 188,
      "parry" => 115,
      "dodge" => 112,
      "damage" => 310,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N卷起手中的$w，宛如翻江倒海直射向$n而去",
      "force" => 532,
      "attack" => 225,
      "parry" => 102,
      "dodge" => 120,
      "damage" => 365,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N手中$w幻出一个个光环，顿时将$n团团包围",
      "force" => 565,
      "attack" => 210,
      "parry" => 105,
      "dodge" => 115,
      "damage" => 390,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N飞身而起，手中$w犹如神龙般地卷向$n",
      "force" => 550,
      "attack" => 248,
      "parry" => 120,
      "dodge" => 110,
      "damage" => 420,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @actions_bad [
    %{
      "action" => "$N正欲施招，却又突然觉得好象忘记了招式，只好胡乱使出。",
      "force" => 10,
      "attack" => 10,
      "parry" => 10,
      "dodge" => 10,
      "damage" => 10,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
  ]

  @impl true
  def id(), do: "taixuan-gong"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "taixuan-gong", 0) < 150 or
         Map.get(victim.skills, "literate", 0) > 0 or
         Map.get(victim.mapped, "parry") != "taixuan-gong" or
         Map.get(victim.mapped, "force") != "taixuan-gong" or
         Map.get(victim.mapped, "unarmed") != "taixuan-gong" or
         victim.neili < 500 or not is_nil(attacker.weapon_name) do
      {damage, nil}
    else
      ap = Map.get(attacker.skills, "force", 0) * 12 + attacker.max_neili
      dp = Map.get(victim.skills, "force", 0) * 12 + victim.neili

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, taixuan_msg(rng)}
      else
        {damage, nil}
      end
    end
  end

  defp taixuan_msg(rng) do
    case rng.(2) - 1 do
      0 -> "$n默念太玄功口诀，太玄内劲齐聚于全身，$N只觉这招攻在$n身上，犹如碰到铜墙铁壁一般，丝毫不起作用。\n"
      _ -> "$N一招击中$n上身，可却犹如击在铜墙铁壁上一般，力道顿时消失得无影无踪。\n"
    end
  end

  @base_usages ["force", "unarmed", "dodge", "parry"]

  @impl true
  def valid_enable(usage), do: usage in @base_usages

  @doc """
  带角色的 `valid_enable`（LPC 读 `this_player()`）：

      if (me->query_skill("literate", 1) || me->query("learned_literate"))
          return usage == 0;
      if (!me->query("can_learned/taixuan-gong/enable_weapon"))
          return usage == "force" || usage == "unarmed" || usage == "dodge" || usage == "parry";
      // 之后按 sword / blade 与 taixuan-gong 的等级关系逐级放开剑或刀

  注意 `usage == 0` 是 LPC 里 string 与 int 的比较，**恒为假** —— 即识字的人
  一项都不能 enable（参不透蝌蚪文，连内功都不行）。
  """
  @impl true
  def valid_enable(usage, character) do
    cond do
      literate?(character) -> false
      not weapon_enabled?(character) -> usage in @base_usages
      true -> usage in (@base_usages ++ extra_usages(character))
    end
  end

  defp weapon_enabled?(character),
    do: Kantele.Combat.Skill.mark?(character, "can_learned/taixuan-gong/enable_weapon")

  # LPC 四个分支：谁的等级低于太玄就不放开谁；相等走 else（剑刀都放开）
  defp extra_usages(character) do
    tx = skill_level(character, "taixuan-gong")
    sword = skill_level(character, "sword")
    blade = skill_level(character, "blade")

    cond do
      sword < tx and blade < tx -> []
      sword < tx and blade > tx -> ["blade"]
      sword > tx and blade < tx -> ["sword"]
      true -> ["blade", "sword"]
    end
  end

  defp skill_level(%{meta: %{stats: stats}}, name), do: Kantele.Character.Stats.skill(stats, name)
  defp skill_level(_, _name), do: 0

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1), do: query_action(level, rng, nil)

  @impl true
  def query_action(level, rng, attacker) do
    if literate?(attacker) do
      # LPC: if (me->query_skill("literate", 1) || me->query("learned_literate"))
      #          return actionbad[0];
      List.first(@actions_bad) || %{}
    else
      Kantele.Combat.Skill.pick_action_for(@actions, @actions_weapon, level, attacker, rng)
    end
  end

  # 识字的人参不透太玄经的蝌蚪文（LPC `query_skill("literate", 1) || query("learned_literate")`；
  # 本引擎 `learned_literate` 未独立建模，识字技能 > 0 即视为识字，与
  # `ItemDescHandlers.PlayerSkill` 的判定一致）。
  # 两种形状都要认：`valid_enable/2` 收角色（`meta.stats`），`query_action/3` 收 Fighter 快照（`skills`）。
  defp literate?(%{meta: %{stats: stats}}),
    do: Kantele.Character.Stats.skill(stats, "literate") > 0

  defp literate?(%{skills: skills}) when is_map(skills), do: Map.get(skills, "literate", 0) > 0
  defp literate?(_), do: false

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "持械招式表（LPC `actionw`）"
  def weapon_actions(), do: @actions_weapon

  @impl true
  def perform_list() do
    %{
      "hun" => Kantele.Combat.Skills.Performs.TaixuanGong.Hun,
      "jing" => Kantele.Combat.Skills.Performs.TaixuanGong.Jing,
      "po" => Kantele.Combat.Skills.Performs.TaixuanGong.Po,
      "xuan" => Kantele.Combat.Skills.Performs.TaixuanGong.Xuan
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.TaixuanGong.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.TaixuanGong.Shield
    }
  end
end

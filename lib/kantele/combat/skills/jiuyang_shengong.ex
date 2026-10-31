defmodule Kantele.Combat.Skills.JiuyangShengong do
  @moduledoc """
  武学实装「jiuyang-shengong」（源 jiuyang-shengong.c）

  九阳神功（`inherit FORCE` 的绝学内功）。LPC 的招式表变量名是 **`actionf`** 而不是
  `action`（全库仅这 6 个绝学如此），`translate_skill.exs` 只认 `action`，所以
  生成时整表丢失 —— 本文件已按源补回：

  - `@actions`：`actionf`，空手时用（6 式）
  - `@actions_weapon`：`actionw`，持械时用（5 式）

  LPC 的选招是 `weapon ? actionw[random(sizeof(actionw))] : actionf[random(sizeof(actionw))]`
  —— 注意**两张表长度不同时用 `sizeof(actionw)` 索引 `actionf` 是源里的 off-by-one**，
  这里按各自表的长度选（`Kantele.Combat.Skill.pick_action_for/5`），不照抄该缺陷。

  **reborn 门控**：未转世只能 enable `force`；转世后放开拳脚/招架，
  拿到 `can_learn/jiuyang-shengong/enable_weapon` 才加剑/刀 ——
  `valid_enable/1` 走未转世分支（保守），`valid_enable/2` 读角色走完整分支。
  `valid_force` 恒 1、`double_attack` 恒 1（引擎默认）。

  未迁移：`perform`/`exert` 的具体效果、`difficult_level`、`practice_skill` 门槛
  （路由骨架已由 `perform_list`/`exert_list` 给出）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N飞身一跃而起，身法陡然加快，朝着$n$l快速攻出数十拳",
      "force" => 510,
      "attack" => 190,
      "parry" => 90,
      "dodge" => 100,
      "damage" => 180,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N沉身运气，一拳击向$n，刹那间，$N全身竟浮现出一道金光",
      "force" => 510,
      "attack" => 185,
      "parry" => 120,
      "dodge" => 90,
      "damage" => 175,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N将九阳神功运劲于臂，一掌凌空劈斩而出，划出一道炽热的黄芒",
      "force" => 530,
      "attack" => 175,
      "parry" => 110,
      "dodge" => 90,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
    %{
      "action" => "$N跨步上前，身形微微一展，双掌对准$n$l一并攻出",
      "force" => 525,
      "attack" => 185,
      "parry" => 115,
      "dodge" => 85,
      "damage" => 185,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N急催九阳神功内劲，猛的一拳在呼啸声中陡然挥击而出",
      "force" => 530,
      "attack" => 165,
      "parry" => 115,
      "dodge" => 90,
      "damage" => 200,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一声暴喝，十指暮的张开，一股雄厚的内劲澎湃而出",
      "force" => 540,
      "attack" => 200,
      "parry" => 120,
      "dodge" => 115,
      "damage" => 180,
      "lvl" => 0,
      "damage_type" => "割伤"
    },
  ]

  @actions_weapon [
    %{
      "action" => "$N攻势忽缓而不疏，$w变化无常，捉摸不定向$n慢慢卷去",
      "force" => 330,
      "attack" => 140,
      "parry" => 85,
      "dodge" => 35,
      "damage" => 325,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N手中的$w突焕气象森严，便似千军万马奔驰而来，$w幻作一道红芒贯向$n",
      "force" => 310,
      "attack" => 120,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 310,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N卷起手中的$w，霎时剑芒暴涨，宛如骄阳烈火直射向$n而去",
      "force" => 340,
      "attack" => 115,
      "parry" => 25,
      "dodge" => 20,
      "damage" => 365,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N运用$w幻化做一个一个圆圈，顿时无数火圈将$n团团包围",
      "force" => 285,
      "attack" => 110,
      "parry" => 25,
      "dodge" => 25,
      "damage" => 390,
      "lvl" => 0,
      "damage_type" => "内伤"
    },
    %{
      "action" => "$N回转$w遥指$n，顿时$w顶端顿时透出一道吞吐不定的火光，电射而出",
      "force" => 330,
      "attack" => 118,
      "parry" => 20,
      "dodge" => 10,
      "damage" => 420,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
  ]

  @impl true
  def id(), do: "jiuyang-shengong"

  # LPC hit_ob（combatd.c:707 force 路径）：damage_bonus>=150、自身>=150、
  # neili>=300、force 与 unarmed 都映射到本技能时，若 damage_bonus/5 > 对手 con，
  # 则给对手追加 (damage_bonus-80)/2 的 qi 创伤并出文案（随机两句之一）。
  # 未建模：me->add("neili",-50) 攻击方内力消耗（跨进程无通道）。
  @impl true
  def hit_ob(attacker, victim, db, _factor, rng) do
    lvl = Map.get(attacker.skills, id(), 0)

    if db < 150 or lvl < 150 or attacker.neili < 300 or
         Map.get(attacker.mapped, "force") != id() or
         Map.get(attacker.mapped, "unarmed") != id() do
      {0, nil}
    else
      if div(db, 5) > victim.con do
        extra = max(div(db - 80, 2), 0)

        msg =
          if Kantele.Combat.Engine.rand(rng, 2) == 1 do
            "$N九阳内劲自体内迸发，真气随招式而荡漾，摧毁了$n的真元！\n"
          else
            "$N九阳神功的潜力发挥了出来，突然间$n只感喉咙一甜，喷出一口鲜血！\n"
          end

        {extra, msg, []}
      else
        {0, nil}
      end
    end
  end

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "jiuyang-shengong", 0) < 150 or
         Map.get(victim.mapped, "parry") != "jiuyang-shengong" or
         Map.get(victim.mapped, "force") != "jiuyang-shengong" or
         Map.get(victim.mapped, "unarmed") != "jiuyang-shengong" or
         victim.neili < 500 or not is_nil(attacker.weapon_name) or
         rng.(2) - 1 != 1 do
      {damage, nil}
    else
      ap = Map.get(attacker.skills, "force", 0) * 12 + attacker.max_neili
      dp = Map.get(victim.skills, "force", 0) * 12 + victim.neili

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, jiuyang_msg(rng)}
      else
        {damage, nil}
      end
    end
  end

  defp jiuyang_msg(rng) do
    case rng.(2) - 1 do
      0 -> "$n默念九阳神功总诀，收敛内劲，承下$N这一招，$N只觉犹如石沉大海，丝毫不起作用。\n"
      _ -> "$N一招击中$n上身，可却犹如击在棉花上一般，力道顿时消失得无影无踪。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage == "force"

  @doc """
  带角色的 `valid_enable`（LPC 读 `this_player()`，有 reborn 门控）：

      if (me->query("reborn")) {
          if (!me->query("can_learn/jiuyang-shengong/enable_weapon"))
              return usage == "force" || usage == "unarmed" || usage == "parry";
          else
              return usage == "force" || usage == "unarmed" || usage == "parry"
                     || usage == "sword" || usage == "blade";
      } else
          return usage == "force";

  `reborn` 以 `stats.reborn` 有非零加成为准（见 `Kantele.Combat.Skill.reborn?/1`）；
  `can_learn/...` 落在 `meta.marks`（见 `Kantele.Combat.Skill.mark?/2`）。
  """
  @impl true
  def valid_enable(usage, character) do
    cond do
      not Kantele.Combat.Skill.reborn?(character) -> usage == "force"
      weapon_enabled?(character) -> usage in ["force", "unarmed", "parry", "sword", "blade"]
      true -> usage in ["force", "unarmed", "parry"]
    end
  end

  defp weapon_enabled?(character),
    do: Kantele.Combat.Skill.mark?(character, "can_learn/jiuyang-shengong/enable_weapon")

  # LPC `valid_learn(object me)`（源 jiuyang-shengong.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    gender = gender_of(character)
    personality = personality_of(character)

    cond do
      gender == "无性" ->
        {:error, "你无根无性，阴阳不调，难以领会高深的九阳神功。\n"}

      personality == "狡黠多变" ->
        {:error, "九阳神功正大恢弘，气度俨然，你怎么也学不得神似。\n"}

      personality == "阴险奸诈" ->
        {:error, "九阳神功正大恢弘，气度俨然，你怎么也学不得神似。\n"}

      Stats.int(stats) < 34 ->
        {:error, "你觉得九阳神功过于艰深，难以理解。\n"}

      Stats.con(stats) < 38 ->
        {:error, "你的先天根骨孱弱，无法运转九阳神功。\n"}

      not is_nil(max_neili) and max_neili < 3500 ->
        {:error, "你的内力修为太浅，无法运转九阳神功。\n"}

      Stats.skill(stats, "martial-cognize") < 100 ->
        {:error, "你觉得九阳神功过于深奥，以自己的武学修养全然无法明白。\n"}

      Stats.skill(stats, "force") < 200 ->
        {:error, "你的基本内功修为不足，难以运转九阳神功。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你对基本内功的理解还不够，无法继续领会更高深的九阳神功。\n"}

      Stats.skill(stats, "unarmed") < lvl ->
        {:error, "你对基本拳脚的理解还不够，无法继续领会更高深的九阳神功。\n"}

      true ->
        :ok
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
      "hun" => Kantele.Combat.Skills.Performs.JiuyangShengong.Hun,
      "jiu" => Kantele.Combat.Skills.Performs.JiuyangShengong.Jiu,
      "pi" => Kantele.Combat.Skills.Performs.JiuyangShengong.Pi,
      "po" => Kantele.Combat.Skills.Performs.JiuyangShengong.Po,
      "ri" => Kantele.Combat.Skills.Performs.JiuyangShengong.Ri
    }
  end

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.Performs.JiuyangShengong.Powerup,
      "roar" => Kantele.Combat.Skills.Performs.JiuyangShengong.Roar,
      "shield" => Kantele.Combat.Skills.Performs.JiuyangShengong.Shield
    }
  end

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil

  # LPC `me->query("character")`：天性。本端口未建模 register 流程 → 恒 nil，
  # 与 LPC 未设定时 `query()` 返回 0 等价（`nil == "X"` 假、`nil != "X"` 真）。
  defp personality_of(%{meta: meta}) when is_map(meta), do: Map.get(meta, :personality)
  defp personality_of(_character), do: nil
end

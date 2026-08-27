defmodule ExKantele.Combat.Skills.TaijiQuan do
  @moduledoc """
  太极拳（对照 lpc_example/skill/skill_taiji-quan.c）

  招式表为纯数据（@actions），选择公式复用 `Kantele.Combat.Skill.pick_action/3`。

  原文里有些回调是现有 `Kantele.Combat.Skill` **尚未提供**的，
  本文件把它们列在 @unsupported 并给了样例实现（见 migrate-notes.md）：

  - `valid_combine/1`     组合兼容（武当掌/排云手）——行为里没有
  - `valid_damage/4`      借力打力反击——需要战斗引擎的“受击前”钩子
  - `query_effect_parry/2` 招架加成——需要招架结算引用 skill
  - `hit_ob/3`            蓄力连击——需要 hit 钩子
  - `perform_action_file/1` 绝招文件映射——对应 perform_list/1

  其中能对上的（valid_enable / valid_learn / practice_skill->practice_cost /
  query_action->pick_action / query_skill_name）已直接映射。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  # 招式表：action[0..] 与 LPC 完全一致（action/force/dodge/parry/skill_name/lvl/damage_type）
  @actions [
    %{"action" => "$N使一招「揽雀尾」，双手划了个半圈，按向$n的$l", "force" => 20, "dodge" => 50, "parry" => 38, "skill_name" => "揽雀尾", "lvl" => 0, "damage_type" => "瘀伤"},
    %{"action" => "$N使一招「单鞭」，右手收置肋下，左手向外挥出，劈向$n的$l", "force" => 25, "dodge" => 48, "parry" => 57, "skill_name" => "单鞭", "lvl" => 5, "damage_type" => "瘀伤"},
    %{"action" => "$N左手回收，右手由钩变掌，由右向左，使一招「提手上式」，向$n的$l打去", "force" => 25, "dodge" => 46, "parry" => 49, "skill_name" => "提手上式", "lvl" => 10, "damage_type" => "瘀伤"},
    %{"action" => "$N双手划弧，右手向上，左手向下，使一招「白鹤亮翅」，分击$n的面门和$l", "force" => 25, "dodge" => 44, "parry" => 71, "skill_name" => "白鹤亮翅", "lvl" => 15, "damage_type" => "瘀伤"},
    %{"action" => "$N左手由胸前向下，身体微转，划了一个大圈，使一招「搂膝拗步」，击向$n的$l", "force" => 25, "dodge" => 44, "parry" => 58, "skill_name" => "搂膝拗步", "lvl" => 20, "damage_type" => "瘀伤"},
    %{"action" => "$N左手由下上挑，右手内合，使一招「手挥琵琶」，向$n的$l打去", "force" => 30, "dodge" => 48, "parry" => 62, "skill_name" => "手挥琵琶", "lvl" => 25, "damage_type" => "瘀伤"},
    %{"action" => "$N左手变掌横于胸前，右拳由肘下穿出，一招「肘底看锤」，锤向$n的$l", "force" => 30, "dodge" => 54, "parry" => 71, "skill_name" => "肘底看锤", "lvl" => 30, "damage_type" => "瘀伤"},
    %{"action" => "$N左脚前踏半步，右手使一招「海底针」，指由下向$n的$l戳去", "force" => 30, "dodge" => 76, "parry" => 65, "skill_name" => "海底针", "lvl" => 35, "damage_type" => "瘀伤"},
    %{"action" => "$N招「闪通臂」，左脚一个弓箭步，右手上举向外撇出，向$n的$l挥去", "force" => 30, "dodge" => 79, "parry" => 76, "skill_name" => "闪通臂", "lvl" => 40, "damage_type" => "瘀伤"},
    %{"action" => "$N两手由相对，转而向左上右下分别挥出，右手使一招「斜飞式」，挥向$n的$l", "force" => 35, "dodge" => 82, "parry" => 52, "skill_name" => "斜飞式", "lvl" => 45, "damage_type" => "瘀伤"},
    %{"action" => "$N左手虚按，右手使一招「白蛇吐信」，向$n的$l插去", "force" => 35, "dodge" => 70, "parry" => 82, "skill_name" => "白蛇吐信", "lvl" => 50, "damage_type" => "瘀伤"},
    %{"action" => "$N双手握拳，向前向后划弧，一招「双峰贯耳」打向$n的$l", "force" => 35, "dodge" => 88, "parry" => 51, "skill_name" => "双风贯耳", "lvl" => 55, "damage_type" => "瘀伤"},
    %{"action" => "$N左手虚划，右手一记「指裆锤」击向$n的裆部", "force" => 40, "dodge" => 86, "parry" => 71, "skill_name" => "指裆锤", "lvl" => 60, "damage_type" => "瘀伤"},
    %{"action" => "$N施出「伏虎式」，右手击向$n的$l，左手攻向$n的裆部", "force" => 40, "dodge" => 84, "parry" => 81, "skill_name" => "伏虎式", "lvl" => 65, "damage_type" => "瘀伤"},
    %{"action" => "$N由臂带手，在面前缓缓划过，使一招「云手」，挥向$n的$l", "force" => 45, "dodge" => 82, "parry" => 87, "skill_name" => "云手", "lvl" => 70, "damage_type" => "瘀伤"},
    %{"action" => "$N左腿收起，右手使一招「金鸡独立」，向$n的$l击去", "force" => 50, "dodge" => 90, "parry" => 51, "skill_name" => "金鸡独立", "lvl" => 75, "damage_type" => "瘀伤"},
    %{"action" => "$N右手由钩变掌，双手掌心向上，右掌向前推出一招「高探马」", "force" => 55, "dodge" => 68, "parry" => 90, "skill_name" => "高探马", "lvl" => 80, "damage_type" => "瘀伤"},
    %{"action" => "$N右手使一式招「玉女穿梭」，扑身向$n的$l插去", "force" => 60, "dodge" => 76, "parry" => 92, "skill_name" => "玉女穿梭", "lvl" => 85, "damage_type" => "瘀伤"},
    %{"action" => "$N右手经腹前经左肋向前撇出，使一招「反身撇锤」，向$n的$l锤去", "force" => 65, "dodge" => 84, "parry" => 95, "skill_name" => "反身撇锤", "lvl" => 90, "damage_type" => "瘀伤"},
    %{"action" => "$N左手虚按，右腿使一招「转身蹬腿」，向$n的$l踢去", "force" => 70, "dodge" => 42, "parry" => 99, "skill_name" => "反身蹬腿", "lvl" => 100, "damage_type" => "瘀伤"},
    %{"action" => "$N左手向上划弧拦出，右手使一招「搬拦锤」，向$n的$l锤去", "force" => 75, "dodge" => 81, "parry" => 102, "skill_name" => "白蛇吐信", "lvl" => 120, "damage_type" => "瘀伤"},
    %{"action" => "$N使一招「栽锤」，左手搂左膝，右手向下锤向$n的$l", "force" => 80, "dodge" => 88, "parry" => 115, "skill_name" => "栽锤", "lvl" => 140, "damage_type" => "瘀伤"},
    %{"action" => "$N双手先抱成球状，忽地分开右手上左手下，一招「野马分鬃」，向$n的$l和面门打去", "force" => 85, "dodge" => 86, "parry" => 119, "skill_name" => "野马分鬃", "lvl" => 160, "damage_type" => "瘀伤"},
    %{"action" => "$N左手由胸前向下，右臂微曲，使一招「抱虎归山」，向$n的$l推去", "force" => 90, "dodge" => 94, "parry" => 115, "skill_name" => "抱虎归山", "lvl" => 180, "damage_type" => "瘀伤"},
    %{"action" => "$N双手经下腹划弧交于胸前，成十字状，一式「十字手」，向$n的$l打去", "force" => 95, "dodge" => 102, "parry" => 122, "skill_name" => "十字手", "lvl" => 200, "damage_type" => "瘀伤"},
    %{"action" => "$N左脚踏一个虚步，双手交叉成十字拳，一招「进步七星」，向$n的$l锤去", "force" => 100, "dodge" => 110, "parry" => 133, "skill_name" => "进步七星", "lvl" => 210, "damage_type" => "瘀伤"},
    %{"action" => "$N身体向后腾出，左手略直，右臂微曲，使一招「倒撵猴」，向$n的$l和面门打去", "force" => 115, "dodge" => 132, "parry" => 121, "skill_name" => "倒撵猴", "lvl" => 220, "damage_type" => "瘀伤"},
    %{"action" => "$N双手伸开，以腰为轴，整个上身划出一个大圆弧，一招「转身摆莲」，将$n浑身上下都笼罩在重重掌影之中", "force" => 120, "dodge" => 154, "parry" => 145, "skill_name" => "转身摆莲", "lvl" => 230, "damage_type" => "瘀伤"},
    %{"action" => "$N双手握拳，右手缓缓收至耳际，左手缓缓向前推出，拳意如箭，一招「弯弓射虎」，直奔$n心窝而去", "force" => 115, "dodge" => 166, "parry" => 175, "skill_name" => "弯弓射虎", "lvl" => 240, "damage_type" => "瘀伤"},
    %{"action" => "$N双手在胸前翻掌，由腹部向前向上推出，一招「如封似闭」，一股劲风直逼$n", "force" => 120, "dodge" => 178, "parry" => 185, "skill_name" => "如封似闭", "lvl" => 250, "damage_type" => "瘀伤"}
  ]

  # 极招（LPC action 里唯一带动态 force/attack 的一式，等级 350）
  @ultimate %{
    "action" => "$N凝神静气，使出极招 太极拳之极意 ",
    "lvl" => 350,
    "skill_name" => "极意",
    "damage_type" => "瘀伤"
  }

  @impl true
  def id(), do: "taiji-quan"

  @impl true
  def valid_enable(usage), do: usage == "unarmed" or usage == "parry"

  # LPC valid_combine（行为未支持）
  def valid_combine(combo), do: combo in ["wudang-zhang", "paiyun-shou"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.attribute(stats, "int") < 26 -> {:error, "你先天悟性太差，难以领会太极拳的要诣。\n"}
      Stats.skill(stats, "force") < 180 -> {:error, "你的内功火候不够，无法学太极拳。\n"}
      Stats.skill(stats, "unarmed") < 100 -> {:error, "你的基本拳脚火候不够，无法学太极拳。\n"}
      Stats.skill(stats, "unarmed") < Stats.skill(stats, id()) -> {:error, "你的基本拳脚水平有限，无法领会更高深的太极拳。\n"}
      true -> :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 59}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    # LPC 极招分支：等级>=350 时命中极招（lecture 上极意）
    if level >= 350 do
      @ultimate
    else
      Kantele.Combat.Skill.pick_action(@actions, level, rng)
    end
  end

  @doc "当前等级对应招式名（LPC query_skill_name，倒序遍历）"
  def query_skill_name(level) do
    @actions
    |> Kernel.++([@ultimate])
    |> Enum.reverse()
    |> Enum.find(fn a -> level >= Map.get(a, "lvl", 0) end)
    |> case do
      nil -> nil
      a -> a["skill_name"]
    end
  end

  # ---- 以下 LPC 回调在现有行为中缺失，标记为 @unsupported ，需底层扩展 ----

  @unsupported [valid_combine: 1, valid_damage: 4, query_effect_parry: 2, hit_ob: 3]

  # LPC valid_damage：借力打力反击（“受击前”钩子，返回 %{damage: -d, msg: ..} 或 nil）
  def valid_damage(attacker_stats, me_stats, _damage, _weapon) do
    # 需战斗引擎在读 hit 前调用；此处给减少伤害的样例
    %{damage_reduction: 50, msg: "$n面含微笑，双手齐出，划出了一个圆圈，竟然让$N的攻击全不着力。\n"}
  end

  # LPC query_effect_parry：招架技能加成（按 taiji 等级给档位）
  def query_effect_parry(level) do
    cond do
      level < 80 -> 0
      level < 200 -> 50
      level < 280 -> 80
      level < 350 -> 100
      true -> 120
    end
  end

  # LPC hit_ob：蓄力连击（hit 命中后钩子）
  def hit_ob(_me, _victim, _bonus), do: :none
end

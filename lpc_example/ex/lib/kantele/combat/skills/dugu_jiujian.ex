defmodule ExKantele.Combat.Skills.DuguJiujian do
  @moduledoc """
  独孤九剑（对照 lpc_example/skill/skill_dugu-jiujian.c）

  与原版最大不同：LPC 有 `action` 与 `action2`（“无招”状态）两套招式表，
  并靠 `can_learn/dugu-jiujian/nothing` 标记切换；Kalevala 现有 Skill
  行为只有一个动作表 + query_action/1，无法表达“两套表 + 玩家标记”。
  因此迁移时：
    - ① 需要把 `look/nothing` 标记（npc 传徒/秘籍）挂到 character meta；
    - ② query_action 需支持按标记选表 —— 属行为层扩展（@unsupported）。

  另含大量现有行为缺失的横向钩子：valid_damage / hit_ob / query_effect_parry /
  skill_improved / difficult_level。这些都要动战斗引擎，不能单文件直落。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{"action" => "但见$N挺身而上，$w一旋，一招仿佛泰山剑法的「来鹤清泉」直刺$n的$l", "force" => 290, "attack" => 145, "dodge" => 95, "parry" => 105, "damage" => 160, "damage_type" => "刺伤"},
    %{"action" => "$N奇诡地向$n挥出「泉鸣芙蓉」、「鹤翔紫盖」、「石廪书声」、「天柱云气」及「雁回祝融」衡山五神剑", "force" => 410, "attack" => 135, "dodge" => 135, "parry" => 175, "damage" => 270, "damage_type" => "刺伤"},
    %{"action" => "$N剑随身转，续而刺出十九剑，竟然是华山「玉女十九剑」，但奇的是这十九剑便如一招，手法之快，直是匪夷所思", "force" => 310, "attack" => 115, "dodge" => 75, "parry" => 105, "damage" => 205, "damage_type" => "刺伤"},
    %{"action" => "$N剑势忽缓而不疏，剑意有余而不尽，化恒山剑法为一剑，向$n慢慢推去", "force" => 280, "attack" => 125, "dodge" => 55, "parry" => 125, "damage" => 160, "damage_type" => "刺伤"},
    %{"action" => "$N剑意突焕气象森严，便似千军万马奔驰而来，长枪大戟，黄沙千里，尽括嵩山剑势击向$n", "force" => 340, "attack" => 160, "dodge" => 65, "parry" => 95, "damage" => 220, "damage_type" => "刺伤"},
    %{"action" => "却见$N身随剑走，左边一拐，右边一弯，剑招也是越转越加狠辣，竟化「泰山十八盘」为一剑攻向$n", "force" => 250, "attack" => 135, "dodge" => 85, "parry" => 105, "damage" => 210, "damage_type" => "刺伤"},
    %{"action" => "$N剑招突变，使出衡山的「一剑落九雁」，削向$n的$l，怎知剑到中途，突然转向，大出$n意料之外", "force" => 240, "attack" => 105, "dodge" => 125, "parry" => 175, "damage" => 180, "damage_type" => "刺伤"},
    %{"action" => "$N吐气开声，一招似是「独劈华山」，手中$w向下斩落，直劈向$n的$l", "force" => 345, "attack" => 125, "dodge" => 115, "parry" => 145, "damage" => 210, "damage_type" => "刺伤"},
    %{"action" => "$N手中$w越转越快，使的居然是衡山的「百变千幻云雾十三式」，剑式有如云卷雾涌，旁观者不由得目为之眩", "force" => 350, "attack" => 145, "dodge" => 165, "parry" => 185, "damage" => 250, "damage_type" => "刺伤"},
    %{"action" => "$N含笑抱剑，气势庄严，$w轻挥，尽融「达摩剑」为一式，闲舒地刺向$n", "force" => 330, "attack" => 135, "dodge" => 95, "parry" => 125, "damage" => 260, "damage_type" => "刺伤"},
    %{"action" => "$N举起$w运使「太极剑」剑意，划出大大小小无数个圆圈，无穷无尽源源不绝地缠向$n", "force" => 230, "attack" => 105, "dodge" => 285, "parry" => 375, "damage" => 140, "damage_type" => "刺伤"},
    %{"action" => "$N神声凝重，$w上劈下切左右横扫，挟雷霆万钧之势逼往$n，「伏摩剑」的剑意表露无遗", "force" => 330, "attack" => 185, "dodge" => 135, "parry" => 155, "damage" => 280, "damage_type" => "刺伤"},
    %{"action" => "却见$N突然虚步提腰，使出酷似武当「蜻蜓点水」的一招", "force" => 180, "attack" => 95, "dodge" => 285, "parry" => 375, "damage" => 130, "damage_type" => "刺伤"},
    %{"action" => "$N运剑如风，剑光霍霍中反攻$n的$l，尝试逼$n自守，剑招似是「伏魔剑」的「龙吞式」", "force" => 270, "attack" => 155, "dodge" => 135, "parry" => 165, "damage" => 260, "damage_type" => "刺伤"},
    %{"action" => "$N突然运剑如狂，一手关外的「乱披风剑法」，猛然向$n周身乱刺乱削", "force" => 330, "attack" => 145, "dodge" => 175, "parry" => 255, "damage" => 220, "damage_type" => "刺伤"},
    %{"action" => "$N满场游走，东刺一剑，西刺一剑，令$n莫明其妙，分不出$N剑法的虚实", "force" => 310, "attack" => 165, "dodge" => 115, "parry" => 135, "damage" => 270, "damage_type" => "刺伤"},
    %{"action" => "$N抱剑旋身，转到$n身后，杂乱无章地向$n刺出一剑，不知使的是什么剑法", "force" => 330, "attack" => 135, "dodge" => 175, "parry" => 215, "damage" => 225, "damage_type" => "刺伤"},
    %{"action" => "$N突然一剑点向$n的$l，虽一剑却暗藏无数后着，$n手足无措，不知如何是好", "force" => 360, "attack" => 160, "dodge" => 150, "parry" => 285, "damage" => 210, "damage_type" => "刺伤"},
    %{"action" => "$N剑挟刀势，大开大阖地乱砍一通，但招招皆击在$n攻势的破绽，迫得$n不得不守", "force" => 510, "attack" => 225, "dodge" => 135, "parry" => 175, "damage" => 190, "damage_type" => "刺伤"},
    %{"action" => "$N反手横剑刺向$n的$l，这似有招似无招的一剑，威力竟然奇大，$n难以看清剑招来势", "force" => 334, "attack" => 135, "dodge" => 155, "parry" => 185, "damage" => 280, "damage_type" => "刺伤"},
    %{"action" => "$N举剑狂挥，迅速无比地点向$n的$l，却令人看不出其所用是什么招式", "force" => 380, "attack" => 125, "dodge" => 145, "parry" => 215, "damage" => 230, "damage_type" => "刺伤"},
    %{"action" => "$N随手一剑指向$n，落点正是$n的破绽所在，端的是神妙无伦，不可思议", "force" => 370, "attack" => 135, "dodge" => 185, "parry" => 255, "damage" => 238, "damage_type" => "刺伤"},
    %{"action" => "$N脸上突现笑容，似乎已看破$n的武功招式，胸有成竹地一剑刺向$n的$l", "force" => 390, "attack" => 155, "dodge" => 185, "parry" => 275, "damage" => 230, "damage_type" => "刺伤"},
    %{"action" => "$N将$w随手一摆，但见$n自己向$w撞将上来，神剑之威，当真人所难测", "force" => 410, "attack" => 155, "dodge" => 185, "parry" => 195, "damage" => 280, "damage_type" => "刺伤"}
  ]

  # action2：领悟“无招”后才使用的招式表
  @actions2 [
    %{"action" => "但见$N手中$w破空长吟，平平一剑刺向$n，毫无招式可言", "force" => 600, "attack" => 300, "dodge" => 300, "parry" => 300, "damage" => 460, "damage_type" => "刺伤"},
    %{"action" => "$N揉身欺近，轻描淡写间随意刺出一剑，简单之极，无招无式", "force" => 600, "attack" => 300, "dodge" => 300, "parry" => 300, "damage" => 460, "damage_type" => "刺伤"},
    %{"action" => "$N身法飘逸，神态怡然，剑意藏于胸中，手中$w随意挥洒而出，独孤九剑已到了收发自如的境界", "force" => 600, "attack" => 300, "dodge" => 300, "parry" => 300, "damage" => 460, "damage_type" => "刺伤"}
  ]

  @impl true
  def id(), do: "dugu-jiujian"

  # LPC valid_enable 依赖 “已练到>=30才可 enable sword”
  @impl true
  def valid_enable(usage, level \\ 0) do
    cond do
      usage == "parry" -> true
      usage == "sword" and level >= 30 -> true
      true -> false
    end
  end

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.attribute(stats, "int") < 39 -> {:error, "你的天资不足，无法理解独孤九剑的剑意。\n"}
      Stats.skill(stats, "sword") < 100 -> {:error, "你的基本剑法造诣太浅，无法理解独孤九剑。\n"}
      Stats.skill(stats, "sword") < Stats.skill(stats, id()) -> {:error, "你的基本剑法造诣有限，无法理解更高深的独孤九剑。\n"}
      true -> :ok
    end
  end

  @impl true
  def practice_cost(), do: nil

  @doc """
  query_action：LPC 按“无招”标记从 action / action2 里随机选。
  现有行为不含该标记，故提供按 nothing? 选表的扩展签名。
  """
  def query_action(nothing?, _level, rng \\ &:rand.uniform/1) do
    table = if nothing?, do: @actions2, else: @actions
    Enum.at(table, rng.(length(table)) - 1)
  end

  # LPC practice_skill：本身不可练（只能通过总诀式）
  def practice_skill(), do: {:error, "独孤九剑只能通过「总诀式」来演练。\n"}

  # LPC query_effect_parry：招架加成档位
  def query_effect_parry(level) do
    cond do
      level < 90 -> 0
      level < 100 -> 50
      level < 125 -> 55
      level < 150 -> 60
      level < 200 -> 70
      level < 250 -> 80
      level < 325 -> 100
      level < 350 -> 110
      true -> 120
    end
  end

  # 绝招文件映射：dugu-jiujian/<action>.c -> perform_list
  @unsupported [valid_damage: 4, hit_ob: 3, skill_improved: 1, difficult_level: 0]

  def difficult_level(nothing?), do: if(nothing?, do: 1000, else: 600)
end

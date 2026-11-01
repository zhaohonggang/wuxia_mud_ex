defmodule Kantele.Combat.Skills.SuxinJian do
  @moduledoc """
  素心剑法（对照 `kungfu/skill/suxin-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/suxin_jian/`。

  学习门槛 `valid_learn/2`（gender=="女性" / int>=28 / force>=100 / sword>=100 / max_neili>=2000 / sword>=suxin-jian）与
  练招消耗 `practice_cost`（LPC 扣 qi 60 / neili 60，须持剑）已按 LPC 迁移（2026-10-30）。
  LPC 的「玉女素心剑只有女性能练」性别门走 `meta.env[:gender]`（缺省为"男性"）；
  须持剑（weapon skill_type=="sword"）检查由 practice 流程把关。招式表已从 LPC 迁移。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N一招「雁行斜击」，身形斜飞，手中$w轻轻点向$n的$l",
      "force" => 2,
      "dodge" => 20,
      "parry" => 10,
      "damage" => 5,
      "lvl" => 0
    },
    %{
      "action" => "$N长跃而起，「白虹经天」，$w猛然下刺",
      "force" => 4,
      "dodge" => 15,
      "parry" => 10,
      "damage" => 4,
      "lvl" => 4
    },
    %{
      "action" => "$N使出「浪迹天涯」，挥剑直劈，威不可当",
      "force" => 5,
      "attack" => 1,
      "dodge" => 15,
      "parry" => 10,
      "damage" => 5,
      "lvl" => 9
    },
    %{
      "action" => "$N使「花前月下」一招自上而下搏击，模拟冰轮横空、清光铺地的光景",
      "force" => 6,
      "attack" => 2,
      "dodge" => 15,
      "parry" => 10,
      "damage" => 6,
      "lvl" => 14
    },
    %{
      "action" => "$N手中$w颤动，如鲜花招展来回挥削，只幌得$n眼花撩乱，浑不知从何攻来",
      "force" => 8,
      "attack" => 4,
      "dodge" => 15,
      "parry" => 15,
      "damage" => 7,
      "lvl" => 19
    },
    %{
      "action" => "$N使出「清饮小酌」剑柄提起，剑尖下指，有如提壶斟酒，直挥$n的$l",
      "force" => 10,
      "attack" => 6,
      "dodge" => 15,
      "parry" => 15,
      "damage" => 8,
      "lvl" => 24
    },
    %{
      "action" => "$N手中$w由内自外一刺，左手如斟茶壶，使出「扫雪烹茶」来",
      "force" => 20,
      "attack" => 8,
      "dodge" => 10,
      "parry" => 15,
      "damage" => 9,
      "lvl" => 29
    },
    %{
      "action" => "$N左掌横摆胸前，右手中$w轻轻挥拂，却是一招「抚琴按萧」",
      "force" => 30,
      "attack" => 10,
      "dodge" => 15,
      "parry" => 15,
      "damage" => 10,
      "lvl" => 34
    },
    %{
      "action" => "$N一招「松下对弈」，$w自右向左挥一个大弧，刺向$n的$l",
      "force" => 40,
      "attack" => 11,
      "dodge" => 15,
      "parry" => 15,
      "damage" => 12,
      "lvl" => 39
    },
    %{
      "action" => "$N左手如拂五弦，竟以掌为剑攻向$n，却是一招「池边调鹤」",
      "force" => 50,
      "attack" => 14,
      "dodge" => 10,
      "parry" => 20,
      "damage" => 13,
      "lvl" => 44
    },
    %{
      "action" => "$N一招「柳絮风飘」，$w轻灵地划出几个圆弧，向$n的$l挥去",
      "force" => 60,
      "attack" => 15,
      "dodge" => 15,
      "parry" => 20,
      "damage" => 15,
      "lvl" => 49
    },
    %{
      "action" => "$N一招「小园艺菊」，手中$w迅疾向$n的下盘连点三点",
      "force" => 70,
      "attack" => 21,
      "dodge" => 15,
      "parry" => 20,
      "damage" => 19,
      "lvl" => 54
    },
    %{
      "action" => "$N使出「西窗夜话」，手中$w中宫直入，攻向$n的$l",
      "force" => 80,
      "attack" => 22,
      "dodge" => 15,
      "parry" => 20,
      "damage" => 19,
      "lvl" => 59
    },
    %{
      "action" => "$N脚下左高右低，一招「柳荫联句」，$w在空中化成一道光环，急攻$n",
      "force" => 90,
      "attack" => 26,
      "dodge" => 5,
      "parry" => 20,
      "damage" => 21,
      "lvl" => 64
    },
    %{
      "action" => "$N手中$w由下而上卷起，犹如打起竹帘一般，却是「竹帘临池」",
      "force" => 100,
      "attack" => 30,
      "dodge" => 15,
      "parry" => 20,
      "damage" => 25,
      "lvl" => 70
    },
    %{
      "action" => "$N做搭弓射箭状，一招「木兰射雁」，右手$w直刺$n的$l",
      "force" => 110,
      "attack" => 31,
      "dodge" => 20,
      "parry" => 20,
      "damage" => 21,
      "lvl" => 76
    },
    %{
      "action" => "$N左手剑诀一领，右手$w平平刺向$n的$l，是一招「双蝶迷回」",
      "force" => 120,
      "attack" => 33,
      "dodge" => 40,
      "parry" => 20,
      "damage" => 25,
      "lvl" => 82
    },
    %{
      "action" => "$N手中$w合身疾刺，一招「孤云出釉」，直指$n的$l",
      "force" => 130,
      "attack" => 36,
      "dodge" => 30,
      "parry" => 20,
      "damage" => 22,
      "lvl" => 88
    },
    %{
      "action" => "$N一招「幽兰空谷」，$w看似随意地一挥，从$n不可思议的角度攻入",
      "force" => 140,
      "attack" => 37,
      "dodge" => 20,
      "parry" => 25,
      "damage" => 25,
      "lvl" => 94
    },
    %{
      "action" => "$N使出「茶花满路」，一时间空中尽是$w的影子，令$n不知如何抵挡",
      "force" => 150,
      "attack" => 40,
      "dodge" => 45,
      "parry" => 25,
      "damage" => 23,
      "lvl" => 100
    },
    %{
      "action" => "$N一招「陌路采桑」，$w连点数点，疾刺$n的$l",
      "force" => 160,
      "attack" => 43,
      "dodge" => 35,
      "parry" => 25,
      "damage" => 27,
      "lvl" => 99
    },
    %{
      "action" => "$N突然盘蹲下来，一招「秋雨萧萧」，$w自下而上刺向$n",
      "force" => 170,
      "attack" => 46,
      "dodge" => 25,
      "parry" => 25,
      "damage" => 29,
      "lvl" => 106
    },
    %{
      "action" => "$N错开脚步，手中$w突然从自己的肋下刺出，却是一招「琴心剑胆」",
      "force" => 180,
      "attack" => 48,
      "dodge" => 35,
      "parry" => 25,
      "damage" => 31,
      "lvl" => 112
    },
    %{
      "action" => "$N犹如在水面滑行一般，一招「池塘秋夜」，平平地向$n的$l挥去",
      "force" => 210,
      "attack" => 51,
      "dodge" => 40,
      "parry" => 25,
      "damage" => 35,
      "lvl" => 118
    },
    %{
      "action" => "$N一招「皓腕玉镯」，手中$w刺点$n的手腕",
      "force" => 245,
      "attack" => 53,
      "dodge" => 45,
      "parry" => 54,
      "damage" => 80,
      "lvl" => 124
    },
    %{
      "action" => "$N一招「牡丹含泪」，$w绕出数个银圈，平平地向$n的$l卷去",
      "force" => 270,
      "attack" => 57,
      "dodge" => 45,
      "parry" => 62,
      "damage" => 94,
      "lvl" => 131
    },
    %{
      "action" => "$N左脚轻点地面，身形往前一扑，一招「芍药蕴珠」，$w向$n的$l刺去",
      "force" => 290,
      "attack" => 52,
      "dodge" => 45,
      "parry" => 70,
      "damage" => 103,
      "lvl" => 148
    },
    %{
      "action" => "$N一招「檐前飞燕」，身形跃起，手中$w扫向$n的$l",
      "force" => 320,
      "attack" => 66,
      "dodge" => 50,
      "parry" => 78,
      "damage" => 115,
      "lvl" => 164
    },
    %{
      "action" => "$N脸现黯然之色，随意一招「蒹葭苍苍」，$w刺向$n的$l",
      "force" => 340,
      "attack" => 82,
      "dodge" => 65,
      "parry" => 90,
      "damage" => 130,
      "lvl" => 178
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 玉女素心剑之极意",
    "lvl" => 250,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "suxin-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  # LPC valid_learn 要求 gender=="女性" / int>=28 / force>=100 / sword>=100 / max_neili>=2000 / sword>=suxin-jian
  # （须持剑检查 weapon skill_type=="sword" 沿用 practice 流程把关，未在此建模）

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 60（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 60}

  # LPC `valid_learn(object me)`（源 suxin-jian.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    gender = gender_of(character)

    cond do
      gender != "女性" ->
        {:error, "玉女素心剑只有女性能练。\n"}

      Stats.int(stats) < 28 ->
        {:error, "你的先天悟性不够，无法学习玉女素心剑。\n"}

      Skill.wielding?(character) and Skill.wielded_skill_type(character) != "sword" ->
        {:error, "你使用的武器不对。\n"}

      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功火候不到，无法学习玉女素心剑。\n"}

      Stats.skill(stats, "sword") < 100 ->
        {:error, "你的基本剑法水平太低，无法学习玉女素心剑。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力修为不够，不能学习玉女素心剑。\n"}

      Stats.skill(stats, "sword") < lvl ->
        {:error, "你的基本剑法水平有限，无法领会更高深的玉女素心剑。\n"}

      true ->
        :ok
    end
  end

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
      "he" => Kantele.Combat.Skills.Performs.SuxinJian.He,
      "lian" => Kantele.Combat.Skills.Performs.SuxinJian.Lian
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

defmodule Kantele.Combat.Skills.MiaojiaJian do
  @moduledoc """
  苗家剑法（对照 `kungfu/skill/miaojia-jian.c`）

  剑法载体：`valid_enable("sword")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/miaojia_jian/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：已学 `daojian-guizhen` 则拒（刀剑合一互斥）/ max_neili>=1300 /
    force>=150 / sword>=120 / sword>=miaojia-jian；
  - LPC `practice_skill` 已迁移：qi 53 / neili 84，且同样带「已学 `daojian-guizhen` 则拒」与
    「须持剑（`skill_type=="sword"`）」两道门——前者已并入 `valid_learn`（practice 流程会复用），
    后者由 practice 流程把关；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N面露微笑，一招「苏秦背剑」，手中$w一抖，剑光暴长，洒向$n的$l",
      "force" => 50,
      "attack" => 15,
      "dodge" => 10,
      "parry" => 25,
      "damage" => 10,
      "lvl" => 0,
      "skill_name" => "苏秦背剑"
    },
    %{
      "action" => "$N一招「下步劈山」，身形突闪，剑招陡变，手中$w从后部斜刺向$n的$l",
      "force" => 70,
      "attack" => 25,
      "dodge" => 25,
      "parry" => 30,
      "damage" => 15,
      "lvl" => 10,
      "skill_name" => "下步劈山"
    },
    %{
      "action" => "$N暴退数尺，一招「抱剑归山」，低首抚剑，随后手中$w骤然穿上，刺向$n的$l",
      "force" => 75,
      "attack" => 33,
      "dodge" => 22,
      "parry" => 32,
      "damage" => 20,
      "lvl" => 20,
      "skill_name" => "抱剑归山"
    },
    %{
      "action" => "$N身形一晃，疾掠而上，使一招「丹凤朝阳」，手中$w龙吟一声，对准$n连递数剑",
      "force" => 90,
      "attack" => 39,
      "dodge" => 40,
      "parry" => 35,
      "damage" => 25,
      "lvl" => 30,
      "skill_name" => "丹凤朝阳"
    },
    %{
      "action" => "$N身形一展，施展出「随形腿弄花葬剑」，如影相随，手中$w疾往$n的$l刺去",
      "force" => 100,
      "attack" => 43,
      "dodge" => 60,
      "parry" => 40,
      "damage" => 29,
      "lvl" => 40,
      "skill_name" => "随形腿弄花葬剑"
    },
    %{
      "action" => "$N一招「阴阳扇折枝开合」，侧过身子，手中$w疾往斜上挑起，直指$n的$l",
      "force" => 130,
      "attack" => 51,
      "dodge" => 50,
      "parry" => 45,
      "damage" => 36,
      "lvl" => 50,
      "skill_name" => "阴阳扇折枝开合"
    },
    %{
      "action" => "$N微微一个转身，一招「空剑抚琴挥鞭」，手中$w却已自肋下穿出，罩向$n的$l",
      "force" => 150,
      "attack" => 62,
      "dodge" => 40,
      "parry" => 47,
      "damage" => 43,
      "lvl" => 60,
      "skill_name" => "空剑抚琴挥鞭"
    },
    %{
      "action" => "$N神色微变，一招「翻云手剑指澜关」，剑招顿时变得凌厉无比，手中$w闪电般射向$n",
      "force" => 180,
      "attack" => 71,
      "dodge" => 30,
      "parry" => 52,
      "damage" => 51,
      "lvl" => 80,
      "skill_name" => "翻云手剑指澜关"
    },
    %{
      "action" => "$N缓缓低首，接着一招「洗剑怀中抱月」，手中$w中宫直进，迅捷无比地往$n刺去",
      "force" => 200,
      "attack" => 85,
      "dodge" => 20,
      "parry" => 54,
      "damage" => 58,
      "lvl" => 100,
      "skill_name" => "洗剑怀中抱月"
    },
    %{
      "action" => "$N纵步上走，单腿猛的踢向$n腰间，$n正要抽身回防，只见刹那间剑光一闪，$N\n一招「迎门腿反劈华山」，$w已经反劈而下",
      "force" => 220,
      "attack" => 88,
      "dodge" => 30,
      "parry" => 62,
      "damage" => 67,
      "lvl" => 120,
      "skill_name" => "迎门腿反劈华山"
    },
    %{
      "action" => "$N矮身侧步，一招「返腕翼德闯帐」，手中$w反手疾挑而出，“唰”的一声往$n刺去",
      "force" => 240,
      "attack" => 91,
      "dodge" => 65,
      "parry" => 65,
      "damage" => 75,
      "lvl" => 140,
      "skill_name" => "返腕翼德闯帐"
    },
    %{
      "action" => "$N一招「黄龙转身吐须」，蓦地疾退一步，又冲前三步，手中$w化为一道凌厉的弧光\n往$n的$l刺去",
      "force" => 265,
      "attack" => 93,
      "dodge" => 40,
      "parry" => 68,
      "damage" => 82,
      "lvl" => 160,
      "skill_name" => "黄龙转身吐须"
    },
    %{
      "action" => "$N一招「上步云边摘月」，纵身跃起，不见踪影，接着却又从半空中穿下，双手紧紧握着\n$w，声势逼人地刺向$n的$l",
      "force" => 290,
      "attack" => 97,
      "dodge" => 60,
      "parry" => 72,
      "damage" => 88,
      "lvl" => 180,
      "skill_name" => "上步云边摘月"
    },
    %{
      "action" => "$N一招「提撩剑白鹤舒翅」，手中$w“嗤”的一声斜刺向天空，随即向下“唰唰”两\n下，划出一个叉字，往$n的$l刺去",
      "force" => 310,
      "attack" => 109,
      "dodge" => 45,
      "parry" => 75,
      "damage" => 96,
      "lvl" => 200,
      "skill_name" => "提撩剑白鹤舒翅"
    },
    %{
      "action" => "$N左腿微抬，一招「冲天掌苏秦背剑」，左手虚击，右手$w猛的自下方挑起，激起数\n股劲风反挑$n的$l",
      "force" => 330,
      "attack" => 115,
      "dodge" => 50,
      "parry" => 82,
      "damage" => 105,
      "lvl" => 220,
      "skill_name" => "冲天掌苏秦背剑"
    }
  ]



  @ultimate %{
    "action" => "$N凝神静气，使出极招 苗家剑法之极意",
    "lvl" => 300,
    "skill_name" => "极意"
  }
  @impl true
  def id(), do: "miaojia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "parry"]

  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      Stats.skill(stats, "daojian-guizhen") > 0 ->
        {:error, "你已经将苗家剑法和胡家刀法二者合一了。\n"}

      not is_nil(max_neili) and max_neili < 1300 ->
        {:error, "你的内力不够。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅。\n"}

      Stats.skill(stats, "sword") < 120 ->
        {:error, "你的基本剑法火候不够，无法学习苗家剑法。\n"}

      Stats.skill(stats, "sword") < Stats.skill(stats, id()) ->
        {:error, "你的基本剑法水平有限，无法领会更高深的苗家剑法。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  @doc "练招消耗：LPC practice_skill 扣 qi 53 / neili 84（须持剑，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 53, neili: 84}

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
      "gan" => Kantele.Combat.Skills.Performs.MiaojiaJian.Gan,
      "qian" => Kantele.Combat.Skills.Performs.MiaojiaJian.Qian,
      "zhai" => Kantele.Combat.Skills.Performs.MiaojiaJian.Zhai,
      "zhu" => Kantele.Combat.Skills.Performs.MiaojiaJian.Zhu
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

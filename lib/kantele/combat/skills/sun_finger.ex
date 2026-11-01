defmodule Kantele.Combat.Skills.SunFinger do
  @moduledoc """
  孙指（对照 `kungfu/skill/sun-finger.c`）

  指法载体：`valid_enable("finger")` / `valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/sun_finger/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 已迁移：须男性 / str>=34 / dex>=30 / force>=240 / max_neili>=2000 /
    finger>=150 / finger>=sun-finger；
  - LPC 的「须空手（`query_temp("weapon")` 为空）」检查未写入 `valid_learn`（`character` 快照
    不含持械信息），由 practice 流程把关；
  - LPC `practice_skill` 已迁移：qi 60 / neili 100；
  - 招式表未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Combat.Skill

  alias Kantele.Character.Stats


  @actions [
    %{
      "action" => "$N右手食指微点，出招「晓天初阳」，一股雄浑的一阳指力射向$n，出手沉稳，招数正大",
      "force" => 350,
      "attack" => 80,
      "dodge" => 75,
      "parry" => 55,
      "damage" => 70,
      "lvl" => 0,
      "skill_name" => "晓天初阳"
    },
    %{
      "action" => "$N一指「日出霞光」，激出的一股罡气涌向$n，看似是温淳平和，但沛然浑厚，无可与抗",
      "force" => 370,
      "attack" => 81,
      "dodge" => 65,
      "parry" => 65,
      "damage" => 72,
      "lvl" => 20,
      "skill_name" => "日出霞光"
    },
    %{
      "action" => "忽听嗤嗤轻响，一股柔和的气流自$N手指涌出，正是一招「阳春暖融」，缓缓点向$n$l",
      "force" => 410,
      "attack" => 85,
      "dodge" => 55,
      "parry" => 55,
      "damage" => 88,
      "lvl" => 40,
      "skill_name" => "阳春暖融"
    },
    %{
      "action" => "$N一步跨到$n身后，又如闪电般跃回，一式「鲁阳返日」，右手食指疾出，指向$n的$l",
      "force" => 430,
      "attack" => 79,
      "dodge" => 65,
      "parry" => 35,
      "damage" => 83,
      "lvl" => 60,
      "skill_name" => "鲁阳返日"
    },
    %{
      "action" => "$N左手轻扬，右手食指挟着雄浑内力疾点$n的$l，招式光明坦荡，正是一式「阳春白雪」",
      "force" => 460,
      "attack" => 75,
      "dodge" => 91,
      "parry" => 85,
      "damage" => 78,
      "lvl" => 80,
      "skill_name" => "阳春白雪"
    },
    %{
      "action" => "$N身影飘起，一式「阳钩挥天」，身形自上而下闪出，右手猛然劲点向$n的$l",
      "force" => 490,
      "attack" => 105,
      "dodge" => 35,
      "parry" => 24,
      "damage" => 98,
      "lvl" => 100,
      "skill_name" => "阳钩挥天"
    },
    %{
      "action" => "$N踏前一步，伸指凌空轻轻一点，$n只觉气息一紧，已被「赤日焦阳」的刚阳气劲触到$l",
      "force" => 480,
      "attack" => 95,
      "dodge" => 75,
      "parry" => 75,
      "damage" => 93,
      "lvl" => 120,
      "skill_name" => "赤日焦阳"
    },
    %{
      "action" => "$N衣袖轻摆，罡阳柔气从袖底挥出，涌向$n的$l，正是玄功若神的一招「晓阳云暖」",
      "force" => 512,
      "attack" => 105,
      "dodge" => 85,
      "parry" => 85,
      "damage" => 97,
      "lvl" => 140,
      "skill_name" => "晓阳云暖"
    },
    %{
      "action" => "$N面带微笑，伸出右食指，缓缓点向$n胸口，这招「暮云映日」劲气弥漫，却无丝毫破空之声",
      "force" => 540,
      "attack" => 113,
      "dodge" => 38,
      "parry" => 38,
      "damage" => 89,
      "lvl" => 160,
      "skill_name" => "暮云映日"
    },
    %{
      "action" => "$N左掌斜削，突然间变掌为指，嗤的一声响，一式「丹凤朝阳」，使出一阳指力，疾点$n的$l",
      "force" => 528,
      "attack" => 119,
      "dodge" => 24,
      "parry" => 23,
      "damage" => 98,
      "lvl" => 180,
      "skill_name" => "丹凤朝阳"
    },
    %{
      "action" => "只见$N食指微屈，一指「九天乾阳」点出，气象森严，雍容肃穆，于威猛之中不脱王者风度",
      "force" => 569,
      "attack" => 97,
      "dodge" => 42,
      "parry" => 42,
      "damage" => 117,
      "lvl" => 200,
      "skill_name" => "九天乾阳"
    },
    %{
      "action" => "$N头顶白气氤氲，渐聚渐浓，便似蒸笼一般，食指伸出，一式「三阳开泰」按向$n$l",
      "force" => 540,
      "attack" => 135,
      "dodge" => 75,
      "parry" => 91,
      "damage" => 138,
      "lvl" => 220,
      "skill_name" => "三阳开泰"
    }
  ]

  @impl true
  def id(), do: "sun-finger"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry"]

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 100（须空手，由 practice 流程把关）"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 100}

  # LPC `valid_learn(object me)`（源 sun-finger.c）
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    max_neili = max_neili_of(character)
    gender = gender_of(character)

    cond do
      gender != "男性" ->
        {:error, "一阳指乃是纯阳玄功，你如何可以修习？\n"}

      Stats.str(stats) < 34 ->
        {:error, "你的先天膂力孱弱，无法领会一阳指。\n"}

      Stats.dex(stats) < 30 ->
        {:error, "你的先天身法孱弱，无法修炼一阳指。\n"}

      (Skill.wielding?(character)) or (Skill.secondary_wielding?(character)) ->
        {:error, "练一阳指必须空手。\n"}

      Stats.skill(stats, "force") < 240 ->
        {:error, "你的内功火候不够，无法学一阳指。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力太弱，无法练一阳指。\n"}

      Stats.skill(stats, "finger") < 150 ->
        {:error, "你的基本指法火候不够，无法学一阳指。\n"}

      Stats.skill(stats, "finger") < lvl ->
        {:error, "你的基本指法水平有限，无法领会更高深的一阳指。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Skill.pick_action(@actions, level, rng)
  end

  @impl true
  def query_action(level, rng, _attacker), do: query_action(level, rng)

  @impl true
  def perform_list() do
    %{
      "dian" => Kantele.Combat.Skills.Performs.SunFinger.Dian,
      "heal" => Kantele.Combat.Skills.Performs.SunFinger.Heal,
      "qiankun" => Kantele.Combat.Skills.Performs.SunFinger.Qiankun
    }
  end
  def actions(), do: @actions

end

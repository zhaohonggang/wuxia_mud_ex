defmodule Kantele.Combat.Skills.YiyangZhi do
  @moduledoc """
  一阳指（对照 `kungfu/skill/yiyang-zhi.c`）

  三载体：`valid_enable` 支持 `finger` / `parry` / `staff`。

  已按 LPC 迁移（2026-10-31）：

    - 两张招式表：`@action_finger` 12 式静态（lvl 0/20/…/220）+ 动态「极意」（lvl 300）；
      `@action_staff` 5 式静态（lvl 0/20/40/60/80）。
    - `query_action/3` 按「是否持械」分表，且两表**等级过滤符号不同**（源内不对称，已保真）：
      空手表 `level >= action_finger[i-1]["lvl"]`，持杖表 `level > action_staff[i-1]["lvl"]`。
      故 0 级持械时杖法表一应不合，源落到末尾返回 0（无招式）；本实现回落首式 ——
      引擎 `select_action` 拿到 `%{}` 会在出招文案拼接处崩，属**有意偏差**
      （仅 0 级且持械这一退化场景）。
    - 「极意」五项数值由 `ultimate_values/2` 按出招者快照实时生成（源公式与弹指神通同构）。
    - `valid_learn/2`：性别须「男性」/ `con >= 34` / `int >= 32` / `force >= 240` /
      `max_neili >= 2000` / `finger >= 150` / `finger >= 本门`。

  未建模：

    - LPC `valid_learn` 的「必须空手」（`query_temp("weapon") || secondary_weapon`）——
      学习事件携带的角色切片不含持械信息，沿用本仓既有约定（`bagua_dao.ex` 等）
      由 practice 流程把关，不写入 `valid_learn`。
    - LPC `hit_ob`（一阳指穴道：空手 + `neili > 300` + 本门 > 100 + `jingluo-xue` > 100
      时 `start_busy(2)` 与额外创伤）已迁移（见 `hit_ob/5`，含空手/持械两支不对称）；
      仅攻击方 `neili` 自耗与对方 `neili` 削减因契约无通道未建模。

  招式里的 `"weapon"` 字段（`一阳指力`）在 LPC 只用于替换出招文案中的武器名，引擎不消费。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skill

  @action_finger [
    %{
      "action" => "$N右手食指微点，出招「晓天初阳」，一股雄浑的一阳指力射向$n，出手沉稳，招数正大",
      "force" => 350,
      "attack" => 80,
      "dodge" => 75,
      "parry" => 55,
      "damage" => 70,
      "lvl" => 0,
      "weapon" => "一阳指力",
      "skill_name" => "晓天初阳",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N一指「日出霞光」，激出的一股罡气涌向$n，看似是温淳平和，但沛然浑厚，无可与抗",
      "force" => 370,
      "attack" => 81,
      "dodge" => 65,
      "parry" => 65,
      "damage" => 72,
      "lvl" => 20,
      "weapon" => "一阳指力",
      "skill_name" => "日出霞光",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "忽听嗤嗤轻响，一股柔和的气流自$N手指涌出，正是一招「阳春暖融」，缓缓点向$n$l",
      "force" => 410,
      "attack" => 85,
      "dodge" => 55,
      "parry" => 55,
      "damage" => 88,
      "lvl" => 40,
      "weapon" => "一阳指力",
      "skill_name" => "阳春暖融",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N一步跨到$n身后，又如闪电般跃回，一式「鲁阳返日」，右手食指疾出，指向$n的$l",
      "force" => 430,
      "attack" => 79,
      "dodge" => 65,
      "parry" => 35,
      "damage" => 83,
      "lvl" => 60,
      "weapon" => "一阳指力",
      "skill_name" => "鲁阳返日",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N左手轻扬，右手食指挟着雄浑内力疾点$n的$l，招式光明坦荡，正是一式「阳春白雪」",
      "force" => 460,
      "attack" => 75,
      "dodge" => 91,
      "parry" => 85,
      "damage" => 78,
      "lvl" => 80,
      "weapon" => "一阳指力",
      "skill_name" => "阳春白雪",
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N身影飘起，一式「阳钩挥天」，身形自上而下闪出，右手猛然劲点向$n的$l",
      "force" => 490,
      "attack" => 105,
      "dodge" => 35,
      "parry" => 24,
      "damage" => 98,
      "lvl" => 100,
      "weapon" => "一阳指力",
      "skill_name" => "阳钩挥天",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N踏前一步，伸指凌空轻轻一点，$n只觉气息一紧，已被「赤日焦阳」的刚阳气劲触到$l",
      "force" => 480,
      "attack" => 95,
      "dodge" => 75,
      "parry" => 75,
      "damage" => 93,
      "lvl" => 120,
      "weapon" => "一阳指力",
      "skill_name" => "赤日焦阳",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N衣袖轻摆，罡阳柔气从袖底挥出，涌向$n的$l，正是玄功若神的一招「晓阳云暖」",
      "force" => 512,
      "attack" => 105,
      "dodge" => 85,
      "parry" => 85,
      "damage" => 97,
      "lvl" => 140,
      "weapon" => "一阳指力",
      "skill_name" => "晓阳云暖",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N面带微笑，伸出食指点向$n胸口，这招「暮云映日」劲气弥漫，却无丝毫破空之声",
      "force" => 540,
      "attack" => 113,
      "dodge" => 38,
      "parry" => 38,
      "damage" => 89,
      "lvl" => 160,
      "weapon" => "一阳指力",
      "skill_name" => "暮云映日",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N左掌斜削，突然间变掌为指，嗤的一式「丹凤朝阳」，使出一阳指力，疾点$n的$l",
      "force" => 528,
      "attack" => 119,
      "dodge" => 24,
      "parry" => 23,
      "damage" => 98,
      "lvl" => 180,
      "weapon" => "一阳指力",
      "skill_name" => "丹凤朝阳",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N食指微屈，一指「九天乾阳」点出，气象森严，雍容肃穆，威猛之中不脱王者风度",
      "force" => 569,
      "attack" => 97,
      "dodge" => 42,
      "parry" => 42,
      "damage" => 117,
      "lvl" => 200,
      "weapon" => "一阳指力",
      "skill_name" => "九天乾阳",
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N头顶白气氤氲，渐聚渐浓，便似蒸笼一般，食指伸出，一式「三阳开泰」按向$n$l",
      "force" => 540,
      "attack" => 135,
      "dodge" => 75,
      "parry" => 91,
      "damage" => 138,
      "lvl" => 220,
      "weapon" => "一阳指力",
      "skill_name" => "三阳开泰",
      "damage_type" => "内伤"
    }
  ]

  # 第 13 式「极意」的静态部分；五项数值由 ultimate_values/2 出招时生成
  @ultimate %{
    "action" => "$N凝神静气，使出极招 一阳指之极意 ",
    "lvl" => 300,
    "weapon" => "一阳指力",
    "skill_name" => "极意",
    "damage_type" => "内伤"
  }

  # 持杖表：源无 "skill_name" / "weapon" / "attack" / "parry"（保真不补）
  @action_staff [
    %{
      "action" => "$N嘴角轻笑，提$w平胸，看准时机一杖挥出，激起呼呼风声，迅猛无比地直插$n$l",
      "force" => 100,
      "dodge" => 15,
      "damage" => 50,
      "lvl" => 0,
      "damage_type" => "刺伤"
    },
    %{
      "action" => "$N左手捏个杖诀，右腕传动，将一阳指神功化于$w之上，出杖凝重，平平正正地打向$n",
      "force" => 150,
      "dodge" => -10,
      "damage" => 70,
      "lvl" => 20,
      "damage_type" => "内伤"
    },
    %{
      "action" => "只见$N屏息凝神，脚步沉着，杖走刀势，一式横劈，砍向$n$l，招式威猛正大",
      "force" => 200,
      "dodge" => 0,
      "damage" => 90,
      "lvl" => 40,
      "damage_type" => "割伤"
    },
    %{
      "action" =>
        "$N脚下步法微变，身随杖走，端凝自重的一杖向$n击出，轻灵中却也不失王者气象",
      "force" => 250,
      "dodge" => 10,
      "damage" => 120,
      "lvl" => 60,
      "damage_type" => "刺伤"
    },
    %{
      "action" =>
        "$N平推一杖，手中的$w看似渐渐沉重，使动时略比先前滞涩，但实是举轻若重，威猛之极",
      "force" => 300,
      "dodge" => -15,
      "damage" => 140,
      "lvl" => 80,
      "damage_type" => "刺伤"
    }
  ]

  @impl true
  def id(), do: "yiyang-zhi"

  @impl true
  def valid_enable(usage), do: usage in ["finger", "parry", "staff"]

  @doc "练招消耗：LPC practice_skill 扣 qi 60 / neili 100"
  @impl true
  def practice_cost(), do: %{qi: 60, neili: 100}

  # 源 `string *xue_name`：18 个穴位名（命中文案随机取一）
  @xue_names ~w(劳宫穴 膻中穴 曲池穴 关元穴 曲骨穴 中极穴 承浆穴 天突穴 百会穴
                幽门穴 章门穴 大横穴 紫宫穴 冷渊穴 天井穴 极泉穴 清灵穴 至阳穴)

  @doc """
  命中回调：一阳指穴道（LPC `hit_ob`）

  前置：`damage_bonus >= 150` 且 `neili > 300` 且 本门 > 100 且 `jingluo-xue > 100`。

  两支（源内不对称，已保真）：

    - **空手**：若对方未 busy 则 `start_busy(2)`（busy 时**仍**造成创伤，只是不加忙乱）；
      额外创伤 `(damage_bonus - 100) / 3`。
    - **持械**：源要求 `!victim->is_busy()` 才进入，且**不调用** `start_busy`（源内怪癖）；
      额外创伤 `(damage_bonus - 100) / 4`。

  未建模（引擎无通道）：攻击方 `me->add("neili", -50/-30)` 自耗、对方 `neili` 削减
  （`<= damage_bonus/4 + 50` 时清零，否则减 `damage_bonus/4`）。
  """
  @impl true
  def hit_ob(attacker, victim, damage_bonus, _factor, rng) do
    if damage_bonus < 150 do
      {0, nil}
    else
      skill = Map.get(attacker.skills, "yiyang-zhi", 0)
      me_neili = Map.get(attacker, :neili, 0)
      jingluo = Map.get(attacker.skills, "jingluo-xue", 0)
      victim_busy? = Map.get(victim, :busy, 0) > 0

      cond do
        me_neili <= 300 -> {0, nil}
        skill <= 100 -> {0, nil}
        jingluo <= 100 -> {0, nil}
        Skill.weapon?(attacker) -> armed_hit(victim_busy?, damage_bonus, rng)
        true -> unarmed_hit(victim_busy?, damage_bonus, rng)
      end
    end
  end

  # 持械支：源要求对方未 busy 才生效，且不 start_busy
  defp armed_hit(true, _damage_bonus, _rng), do: {0, nil}

  defp armed_hit(false, damage_bonus, rng) do
    name = Enum.at(@xue_names, Skill.lpc_random(rng, length(@xue_names)))

    {div(damage_bonus - 100, 4),
     "只听“嗤”的一声，$n被$N杖端发出的气劲刺中#{name}，真气不由得一滞。\n"}
  end

  # 空手支：busy 与否都造成创伤，仅未 busy 时追加 start_busy(2)
  defp unarmed_hit(victim_busy?, damage_bonus, rng) do
    name = Enum.at(@xue_names, Skill.lpc_random(rng, length(@xue_names)))
    affects = if victim_busy?, do: [], else: [{"busy", %{"rounds" => 2}}]

    {div(damage_bonus - 100, 3),
     "只听“嗤”的一声，$n被$N凌空一指点中#{name}，真气不由得一滞。\n", affects}
  end

  # LPC valid_learn：性别男性 / con>=34 / int>=32 / force>=240 / max_neili>=2000 /
  # finger>=150 / finger>=own
  @impl true
  def valid_learn(stats, character) do
    max_neili = max_neili_of(character)

    cond do
      gender_of(character) != "男性" ->
        {:error, "一阳指乃是纯阳玄功，你如何可以修习？\n"}

      # 源 me->query("con") / me->query("int")：裸属性，非 query_con/query_int 派生值
      Stats.con(stats) < 34 ->
        {:error, "你的先天根骨欠佳，无法修炼一阳指。\n"}

      Stats.int(stats) < 32 ->
        {:error, "你的先天悟性不足，无法领会一阳指。\n"}

      Stats.skill(stats, "force") < 240 ->
        {:error, "你的内功火候不够，无法学一阳指。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力太弱，无法练一阳指。\n"}

      Stats.skill(stats, "finger") < 150 ->
        {:error, "你的基本指法火候不够，无法学一阳指。\n"}

      Stats.skill(stats, "finger") < Stats.skill(stats, id()) ->
        {:error, "你的基本指法水平有限，无法领会更高深的一阳指。\n"}

      true ->
        :ok
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili

  defp max_neili_of(_), do: nil

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc """
  带出招者上下文选招：空手走指法表、持械走杖法表

  LPC 原文：

      if ( ! weapon)
          for(i = sizeof(action_finger); i > 0; i--)
              if(level >= action_finger[i-1]["lvl"])
                  return action_finger[NewRandom(i, 20, level/5)];
      else
          for(i = sizeof(action_staff); i > 0; i--)
              if(level > action_staff[i-1]["lvl"])
                  return action_staff[NewRandom(i, 20, level/5)];
  """
  @impl true
  def query_action(level, rng, attacker) do
    if Skill.weapon?(attacker) do
      Skill.pick_action(@action_staff, level, rng)
    else
      table = @action_finger ++ [Map.merge(@ultimate, ultimate_values(attacker, rng))]
      pick_action_ge(table, level, rng)
    end
  end

  # 源指法表用 `level >= lvl`（与基类 pick_action 的 `level > lvl` 不同）
  defp pick_action_ge(actions, level, rng) do
    case Enum.count(actions, fn action -> level >= Map.get(action, "lvl", 0) end) do
      0 -> List.first(actions) || %{}
      count -> Enum.at(actions, Skill.new_random(count, rng))
    end
  end

  # 与弹指神通/华山剑法的「极意」公式相同（源内同构）
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
  def query_action(level, rng \\ &:rand.uniform/1) do
    table =
      @action_finger ++
        [
          Map.merge(@ultimate, %{
            "force" => 0,
            "attack" => 0,
            "dodge" => 0,
            "parry" => 0,
            "damage" => 0
          })
        ]

    pick_action_ge(table, level, rng)
  end

  @doc "招式名 -> 招式数据（指法表；杖法表见 `staff_actions/0`）"
  def actions(), do: @action_finger

  @doc "杖法招式表（供 score/look 与测试）"
  def staff_actions(), do: @action_staff

  @doc "第 13 式「极意」的静态部分"
  def ultimate(), do: @ultimate

  @impl true
  def perform_list() do
    %{
      "dian" => Kantele.Combat.Skills.Performs.YiyangZhi.Dian,
      "die" => Kantele.Combat.Skills.Performs.YiyangZhi.Die,
      "heal" => Kantele.Combat.Skills.Performs.YiyangZhi.Heal,
      "jian" => Kantele.Combat.Skills.Performs.YiyangZhi.Jian,
      "qian" => Kantele.Combat.Skills.Performs.YiyangZhi.Qian
    }
  end
end

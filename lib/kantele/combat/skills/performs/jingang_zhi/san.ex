defmodule Kantele.Combat.Skills.Performs.JingangZhi.San do
  @moduledoc """
  perform「一指点三脉」（source jingang-zhi/san.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  大力金刚指>=200 → 激发 force 为少林内功（混元一气 / 易筋经 / 罗汉伏魔功之一）→
  经络学(`jingluo-xue`)>=200 → 激发 finger 为大力金刚指 →
  准备 finger 为大力金刚指 → 基本内功>=300 → 内力上限>=5000 → 真气>=1000 → 目标存活。
  起手式后按 `ap*2/3 + random(ap) vs 目标 parry`（`ap = 基本指法`）判定：
  命中则伤害 `(基本指法 + 基本内功 + jinluo-xue) + random(...)`
  （qi 伤 + 150% 外伤），并从 18 处穴道中随机取一处播报；目标忙乱 `大力金刚指/30`。
  未命中播报化解文案。攻击方无条件忙乱 `3+random(3)` 并扣 800 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 命中判定需目标 `parry`，故命中/失手两支的文案与伤害均在目标侧结算；
  - `.c` 起手式为 `msg = HIW "突然间"; msg += ...`（两段字面量），
    命中文案为 `"…一指点中" + xue_name[...] + "，…"`（两段 + 变量），
    此处均按原粒度拆为列表 + `Enum.join("")`，避免 C/E 段数不一致；
  - 18 处穴道名（`xue_name` 数组）以模块属性 `@xue_names` 承载（列表值属性不会被
    提取器剥离，字面量照常计入）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages

  @perform_id "jingang-zhi/san"
  @move_name "「一指点三脉」"

  # LPC: string *xue_name = ({ "劳宫穴", ... "至阳穴", });
  @xue_names [
    "劳宫穴",
    "膻中穴",
    "曲池穴",
    "关元穴",
    "曲骨穴",
    "中极穴",
    "承浆穴",
    "天突穴",
    "百会穴",
    "幽门穴",
    "章门穴",
    "大横穴",
    "紫宫穴",
    "冷渊穴",
    "天井穴",
    "极泉穴",
    "清灵穴",
    "至阳穴"
  ]

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jingang-zhi")
    # LPC: ap = me->query_skill("finger");
    ap = Stats.skill(stats, "finger")
    # LPC: damage = finger + force + jinluo-xue; damage += random(damage);
    damage =
      Stats.skill(stats, "finger") + Stats.skill(stats, "force") +
        Stats.skill(stats, "jinluo-xue")

    damage = damage + Engine.rand(rng, damage)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_jingang_zhi(character),
         :ok <- check_force_mapped(character),
         :ok <- check_jingluo_xue(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/jingang-zhi/san"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jingang-zhi", 1) < 200)
  defp check_jingang_zhi(character) do
    if Stats.skill(character.meta.stats, "jingang-zhi") < 200 do
      {:error, "你大力金刚指不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jingluo-xue", 1) < 200)
  defp check_jingluo_xue(character) do
    if Stats.skill(character.meta.stats, "jingluo-xue") < 200 do
      {:error, "你对经络学了解不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (mapped("force") != "hunyuan-yiqi" && != "yijinjing" && != "luohan-fumogong")
  defp check_force_mapped(character) do
    if Stats.mapped(character.meta.stats, "force") in [
         "hunyuan-yiqi",
         "yijinjing",
         "luohan-fumogong"
       ] do
      :ok
    else
      {:error, "你现在没有激发少林内功为内功，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_mapped("finger") != "jingang-zhi")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "finger") == "jingang-zhi" do
      :ok
    else
      {:error, "你没有激发大力金刚指，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("finger") != "jingang-zhi")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "finger")

    if prepared == nil or prepared |> String.split("/") |> hd() != "jingang-zhi" do
      {:error, "你没有准备大力金刚指，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 300) / if (max_neili < 5000) / if (neili < 1000)
  defp check_resources(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      vitals.max_neili < 5000 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      vitals.neili < 1000 ->
        {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, rng) do
    # LPC: msg = HIW "突然间"; msg += "$N" HIW "凝气于指，「一指点三脉」点出，顿时一股"
    #            "纯阳的内力直袭$n" HIW "胸口！\n" NOR;
    #      me->start_busy(3 + random(3)); me->add("neili", -800);
    #      命中/失手两支在目标侧结算（dp 需目标 parry）。
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 800}
    combat = Combat.start_busy(character.meta.combat, 3 + Engine.rand(rng, 3))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    msg =
      ["突然间", "$N凝气于指，#{@move_name}点出，顿时一股纯阳的内力直袭$n胸口！\n"]
      |> Enum.join("")

    conn
    |> Broadcast.publish(msg, n1: character.name, n2: target.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage = max(Map.get(data, :damage, 0), 0)
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap * 2 / 3 + random(ap) > dp)   (dp = target->query_skill("parry"))
    if div(ap * 2, 3) + Engine.rand(rng, ap) > Stats.skill(stats, "parry") do
      # LPC: do_damage(me, target, UNARMED_ATTACK, damage, 150,
      #                HIR "结果$n" HIR "被$N" HIR "一指点中" HIY + xue_name[...] +
      #                HIR "，全身真气逆流而上，登时呕出一大口鲜血。\n" NOR);
      #      target->start_busy(lvl / 30);
      xue = Enum.at(@xue_names, Engine.rand(rng, length(@xue_names)))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 150, 100))

      combat = Combat.start_busy(character.meta.combat, div(lvl, 30))
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      msg =
        ["结果$n被$N一指点中", xue, "，全身真气逆流而上，登时呕出一大口鲜血。\n"]
        |> Enum.join("")

      conn
      |> Broadcast.publish(Messages.interpolate(msg, bindings))
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "镇定自如，全力化解了$P" CYN "这精妙的一指。\n" NOR;
      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p镇定自如，全力化解了$P这精妙的一指。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DIE "「" HIR "一指点三脉" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string *xue_name = ({
  # "劳宫穴", "膻中穴", "曲池穴", "关元穴", "曲骨穴", "中极穴",
  # "承浆穴", "天突穴", "百会穴", "幽门穴", "章门穴", "大横穴",
  # "紫宫穴", "冷渊穴", "天井穴", "极泉穴", "清灵穴", "至阳穴", });
  # 
  # int perform(object me, object target)
  # {
  #         int damage, lvl;
  #         string msg;
  #         // object weapon;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/jingang-zhi/san"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  # 
  #                 return notify_fail(DIE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(DIE "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("jingang-zhi", 1) < 200)
  #                 return notify_fail("你大力金刚指不够娴熟，难以施展" DIE "。\n");
  # 
  #         if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong"))
  #                 return notify_fail("你现在没有激发少林内功为内功，难以施展" DIE "。\n");
  #         if ((int)me->query_skill("jingluo-xue", 1) < 200)
  #                 return notify_fail("你对经络学了解不够，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "jingang-zhi")
  #                 return notify_fail("你没有激发大力金刚指，难以施展" DIE "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "jingang-zhi")
  #                 return notify_fail("你没有准备大力金刚指，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功火候不够，难以施展" DIE "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，难以施展" DIE "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不够，难以施展" DIE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         damage = (int)me->query_skill("finger") + (int)me->query_skill("force") + (int)me->query_skill("jinluo-xue",1);
  #         damage += random(damage);
  #         lvl = (int)me->query_skill("jingang-zhi", 1);
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIW "突然间";
  # 
  #         msg += "$N" HIW "凝气于指，「" HIR "一指点三脉" HIW "」点出，顿时一股"
  #                "纯阳的内力直袭$n" HIW "胸口！\n" NOR;
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 150,
  #                                            HIR "结果$n" HIR "被$N" HIR "一指点中"
  #                                            HIY + xue_name[random(sizeof(xue_name))] +
  #                                            HIR "，全身真气逆流而上，登时呕出一大"
  #                                            "口鲜血。\n" NOR);
  # 
  #                 target->start_busy(lvl/30);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "镇定自如，全力化解了$P"
  #                        CYN "这精妙的一指。\n" NOR;
  #         }
  # 
  # 
  #         me->start_busy(3 + random(3));
  #         me->add("neili", -800);
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

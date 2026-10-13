defmodule Kantele.Combat.Skills.Performs.HuzhuaShou.Juehu do
  @moduledoc """
  perform「绝户神抓」（source huzhua-shou/juehu.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  正邪 `shen`>=10000 → 虎爪绝户手>=120 → 激发 claw 为虎爪绝户手 →
  准备 claw 为虎爪绝户手 → 真气>=300 → 目标存活。
  命中判定 `random(基本爪法)` vs 目标 `parry/2`：
  命中则伤害 `虎爪绝户手*3 + random(虎爪绝户手*6)`（qi 伤 + 40% 外伤）、
  扣 200 真气、忙乱 2；未命中则扣 100 真气、忙乱 3。
  两支都扣 3000 正邪值（无条件）。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方消耗/忙乱分属命中与失手两支，经 `Performs.feedback/3` 由目标侧回传；
  - `.c` 的 `userp(me) && me->query("shen") < 10000` 折算为 `stats.shen` 直读
    （本引擎 perform 恒由玩家发起，`userp` 恒真）；
  - `.c` 用 `message_combatd(msg, me, target)` 把起手式与结算文案合成一条广播，
    此处按本仓库约定拆为「攻击方发起手式 / 目标侧发结算文案」两条。
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
  alias Kantele.Combat.Performs

  @perform_id "huzhua-shou/juehu"
  @move_name "「绝户神抓」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huzhua-shou")
    # LPC: random(me->query_skill("claw"))
    claw = Stats.skill(stats, "claw")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_shen(character),
         :ok <- check_levels(character),
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
          claw: claw,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/huzhua-shou/juehu"))
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) do
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (userp(me) && me->query("shen") < 10000)
  #      return notify_fail(HIC "\n你恶念顿生，刚想施展毒招，可突然想到当初俞莲舟"
  #                         "的一番告诫，不得不中途放弃了攻击。\n" NOR);
  defp check_shen(character) do
    if character.meta.stats.shen < 10_000 do
      {:error,
       "\n你恶念顿生，刚想施展毒招，可突然想到当初俞莲舟的一番告诫，不得不中途放弃了攻击。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("huzhua-shou", 1) < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "huzhua-shou") < 120 do
      {:error, "你的虎爪绝户手不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("claw") != "huzhua-shou")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "claw") == "huzhua-shou" do
      :ok
    else
      {:error, "你没有激发虎爪绝户手，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("claw") != "huzhua-shou")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "claw")

    if prepared == nil or prepared |> String.split("/") |> hd() != "huzhua-shou" do
      {:error, "你没有准备使用虎爪绝户手，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIR "$N" HIR "大喝一声，变掌为爪，双爪化出漫天爪影，如狂风骤雨一般向$n"
    #            HIR "的要害抓去！\n" NOR; message_combatd(msg, me, target);
    #      命中/失手与攻击方消耗/忙乱均在目标侧结算（dp 需目标 parry）；
    #      me->add("shen", -3000) 命中与失手两支都执行 → 无条件扣 3000。
    stats = %{character.meta.stats | shen: character.meta.stats.shen - 3000}
    character = %{character | meta: %{character.meta | stats: stats}}

    conn
    |> Broadcast.publish(
      "$N大喝一声，变掌为爪，双爪化出漫天爪影，如狂风骤雨一般向$n的要害抓去！\n",
      n1: character.name,
      n2: target.name
    )
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
    claw = max(Map.get(data, :claw, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("claw")) > target->query_skill("parry") / 2)
    if Engine.rand(rng, claw) > div(Stats.skill(stats, "parry"), 2) do
      # LPC: damage = me->query_skill("huzhua-shou", 1);
      #      damage = damage * 3 + random(damage * 6);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                HIR "结果$p" HIR "一声惨嚎，没能招架住$P"
      #                HIR "凌厉的攻势，被抓得皮肉分离，鲜血飞溅！\n" NOR);
      #      me->add("neili", -200); me->start_busy(2);
      damage = level * 3 + Engine.rand(rng, level * 6)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 200, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$p一声惨嚎，没能招架住$P凌厉的攻势，被抓得皮肉分离，鲜血飞溅！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破了$N" CYN "的企图，躲开了这招杀着。\n" NOR;
      #      me->add("neili", -100); me->start_busy(3);
      Performs.feedback(attacker, 100, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p看破了$N的企图，躲开了这招杀着。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JUEHU "「" HIR "绝户神抓" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/huzhua-shou/juehu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUEHU "只能在战斗中对对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" JUEHU "。\n");
  # 
  #         if (userp(me) && me->query("shen") < 10000)
  #                 return notify_fail(HIC "\n你恶念顿生，刚想施展毒招，可突然想到当初俞莲舟"
  #                                    "的一番告诫，不得不中途放弃了攻击。\n" NOR);
  # 
  #         if ((int)me->query_skill("huzhua-shou", 1) < 120)
  #                 return notify_fail("你的虎爪绝户手不够娴熟，难以施展" JUEHU "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "huzhua-shou")
  #                 return notify_fail("你没有激发虎爪绝户手，难以施展" JUEHU "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "huzhua-shou")
  #                 return notify_fail("你没有准备使用虎爪绝户手，无法使用" JUEHU "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你现在真气不够，难以施展" JUEHU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "大喝一声，变掌为爪，双爪化出漫天爪影，如狂风骤雨一般向$n"
  #               HIR "的要害抓去！\n" NOR;
  # 
  #         if (random(me->query_skill("claw")) > target->query_skill("parry") / 2)
  #         {
  #                 me->start_busy(2);
  # 
  #                 damage = me->query_skill("huzhua-shou", 1);
  #                 damage = damage * 3 + random(damage * 6);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "结果$p" HIR "一声惨嚎，没能招架住$P"
  #                                            HIR "凌厉的攻势，被抓得皮肉分离，鲜血飞溅！\n" NOR);
  #                 me->add("neili", -200);
  #             me->add("shen", -3000);
  #         } else
  #         {
  #                 me->start_busy(3);
  #             me->add("neili", -100);
  #             me->add("shen", -3000);
  #                 msg += CYN "可是$p" CYN "看破了$N"
  #                        CYN "的企图，躲开了这招杀着。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

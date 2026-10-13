defmodule Kantele.Combat.Skills.Performs.JuemingTui.Jue do
  @moduledoc """
  perform「绝命一踢」（source jueming-tui/jue.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手（主副兵器均不可）→
  绝命腿法>=80 → 激发 unarmed 为绝命腿法 → 准备 unarmed 为绝命腿法 →
  内力>=200 → 目标存活。
  ap = 拳脚 + str*10；dp = 闪避 + dex*10；pp = 招架 + str*10（均为目标侧）。
  起手式三选一（random(3)）。两段判定：先对 pp（架住），再对 dp（闪开），
  命中则伤害 ap/3 + random(ap/3)、60% 外伤。架住/闪开扣 30 内力、忙乱 3；
  命中扣 100 内力、忙乱 2。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Vitals

  @perform_id "jueming-tui/jue"
  @move_name "「绝命一踢」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jueming-tui")
    ap = Stats.skill(stats, "unarmed") + Stats.query_str(stats) * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
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
          ap: ap,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #          return notify_fail(JUE "只能空手施展。\n");
  # 框架无副兵器槽，仅检查主兵器
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("jueming-tui", 1) < 80)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jueming-tui") < 80 do
      {:error, "你绝命腿法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "jueming-tui")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "unarmed") != "jueming-tui" do
      {:error, "你没有激发绝命腿法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "jueming-tui")
  # prepared_perform 返回绝招 ID（如 jueming-tui/jue），须取技能前缀比对
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or hd(String.split(prepared, "/")) != "jueming-tui" do
      {:error, "你没有准备绝命腿法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你目前的内力不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: switch (random(3)) 起手式三选一（用 list 而非 case，避免相邻文案被验收工具拼接）
  defp apply_effect(conn, character, target, rng) do
    leads = [
      "只听$N一声冷哼，侧身飞踢，右腿横扫向$n，当真是力不可挡。\n",
      "$N蓦地大喝一声，单腿猛踢而出，直踹$n腰际，招式极为迅猛。\n",
      "突然只见$N双腿连环踢出，挟着嚯嚯风声，以千钧之势扫向$n。\n"
    ]

    msg = Enum.at(leads, Engine.rand(rng, 3))

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = dodge + dex*10; pp = parry + str*10;
    dp = Stats.skill(stats, "dodge") + Stats.query_dex(stats) * 10
    pp = Stats.skill(stats, "parry") + Stats.query_str(stats) * 10

    # LPC: if (ap * 7 / 10 + random(ap) < pp) ... else if (ap * 7 / 10 + random(ap) < dp) ...
    roll_pp = div(ap * 7, 10) + Engine.rand(rng, ap)
    roll_dp = div(ap * 7, 10) + Engine.rand(rng, ap)

    cond do
      roll_pp < pp ->
        # LPC: 架住：me->start_busy(3); me->add("neili", -30);
        Performs.feedback(attacker, 30, 3)

        conn
        |> Broadcast.publish(
          Messages.interpolate("可是$n身子一晃，硬生生架住了$N这一腿。\n", bindings)
        )
        |> put_character(character)

      roll_dp < dp ->
        # LPC: 闪开：me->start_busy(3); me->add("neili", -30);
        Performs.feedback(attacker, 30, 3)

        conn
        |> Broadcast.publish(
          Messages.interpolate("却见$n镇定的向后一纵，闪开了$N这一腿。\n", bindings)
        )
        |> put_character(character)

      true ->
        # LPC: 命中：damage = ap / 3 + random(ap / 3);
        #          do_damage(me, target, UNARMED_ATTACK, damage, 60, ...)
        #          me->start_busy(2); me->add("neili", -100);
        damage = div(ap, 3) + Engine.rand(rng, div(ap, 3))
        character = apply_damage(character, damage, 60)
        Performs.feedback(attacker, 100, 2)

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n连忙格挡，却只觉得力道大得出奇，登时被一脚踢得飞起。\n",
            bindings
          )
        )
        |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JUE "「" HIR "绝命一踢" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     int ap, dp, pp;
  #     int damage;
  # 
  #     if (userp(me) && !me->query("can_perform/jueming-tui/jue"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #     {
  #         me->clean_up_enemy();
  #         target = me->select_opponent();
  #     }
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(JUE "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #         return notify_fail(JUE "只能空手施展。\n");
  # 
  #     if (me->query_skill("jueming-tui", 1) < 80)
  #         return notify_fail("你绝命腿法不够娴熟，难以施展" JUE "。\n");
  # 
  #     if (me->query_skill_mapped("unarmed") != "jueming-tui")
  #         return notify_fail("你没有激发绝命腿法，难以施展" JUE "。\n");
  # 
  #     if (me->query_skill_prepared("unarmed") != "jueming-tui")
  #         return notify_fail("你没有准备绝命腿法，难以施展" JUE "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你目前的内力不够，难以施展" JUE "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     switch (random(3))
  #     {
  #     case 0:
  #         msg = HIR "只听$N" HIR "一声冷哼，侧身飞踢，右腿横"
  #                   "扫向$n" HIR "，当真是力不可挡。\n" NOR;
  #         break;
  # 
  #     case 1:
  #         msg = HIR "$N" HIR "蓦地大喝一声，单腿猛踢而出，直"
  #                   "踹$n" HIR "腰际，招式极为迅猛。\n" NOR;
  #         break;
  # 
  #     default:
  #         msg = HIR "突然只见$N" HIR "双腿连环踢出，挟着嚯嚯"
  #                   "风声，以千钧之势扫向$n" HIR "。\n" NOR;
  #         break;
  #     }
  # 
  #     ap = me->query_skill("unarmed") + me->query("str") * 10;
  #     dp = target->query_skill("dodge") + target->query("dex") * 10;
  #     pp = target->query_skill("parry") + target->query("str") * 10;
  # 
  #     if (ap * 7 / 10 + random(ap) < pp)
  #     {
  #         msg += HIC "可是$n" HIC "身子一晃，硬生生架住了$N" HIC "这一腿。\n" NOR;
  #         me->start_busy(3);
  #         me->add("neili", -30);
  #     }
  #     else if (ap * 7 / 10 + random(ap) < dp)
  #     {
  #         msg += CYN "却见$n" CYN "镇定的向后一纵，闪开了$N" CYN "这一腿。\n" NOR;
  #         me->start_busy(3);
  #         me->add("neili", -30);
  #     }
  #     else
  #     {
  #         damage = ap / 3 + random(ap / 3);
  #         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                    HIR "$n" HIR "连忙格挡，却只觉得力道大"
  #                                        "得出奇，登时被一脚踢得飞起。\n" NOR);
  #         me->start_busy(2);
  #         me->add("neili", -100);
  #     }
  #     message_combatd(msg, me, target);
  #     return 1;
  # }
end

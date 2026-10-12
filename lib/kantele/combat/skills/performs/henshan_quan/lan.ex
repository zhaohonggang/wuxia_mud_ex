defmodule Kantele.Combat.Skills.Performs.HenshanQuan.Lan do
  @moduledoc """
  perform「青天揽日月」（source henshan-quan/lan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手（weapon/secondary_weapon）→
  衡山拳法>=60 → 激发衡山拳法(cuff) → 准备衡山拳法(cuff) → 内功>=80 →
  真气>=200 → 目标存活。命中判定 `ap/2 + random(ap)` vs 目标 `parry`
  （`ap = cuff`）：命中则伤害 `henshan-quan + random(henshan-quan/2)`
  （qi 伤 + 40% 外伤），攻击方扣 100 真气并忙乱 `2 + random(2)`；
  未命中扣 30 真气并忙乱 `2 + random(3)`。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方消耗/忙乱分属命中与失手两支，经 `Performs.feedback/3` 由目标侧回传
    （攻击方 `start_busy` 取 max，`busy: 0` 不改动）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "henshan-quan/lan"
  @move_name "「青天揽日月」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "henshan-quan")
    ap = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_force(character),
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

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/henshan-quan/lan"))
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
  defp check_weapon(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("henshan-quan", 1) < 60)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "henshan-quan") < 60 do
      {:error, "你衡山拳法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("cuff") != "henshan-quan")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "cuff") != "henshan-quan" do
      {:error, "你没有激发衡山拳法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "henshan-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared == nil or prepared |> String.split("/") |> hd() != "henshan-quan" do
      {:error, "你没有准备衡山拳法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 80)
  defp check_force(character) do
    if Stats.skill(character.meta.stats, "force") < 80 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIC "\n$N" HIC "双拳挥出，施一招「" HIG "青天揽日月"
    #           HIC "」，拳速极快，部位极准，" HIC "分袭$n" HIC "面"
    #           "门和胸口。" NOR;
    #      message_sort(msg, me, target);
    #      消耗/忙乱分属命中与失手两支，由目标侧回传。
    conn
    |> Broadcast.publish(
      "\n$N双拳挥出，施一招#{@move_name}，拳速极快，部位极准，分袭$n面门和胸口。",
      n1: character.name,
      n2: target.name
    )
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
    lvl = Map.get(data, :level, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = (int)me->query_skill("henshan-quan", 1);
      #      damage += random(damage / 2);
      damage = lvl + Engine.rand(rng, max(div(lvl, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -100); me->start_busy(2 + random(2));
      Performs.feedback(attacker, 100, 2 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        Messages.interpolate("$N出手既快，方位又奇，$n闪避不及，闷哼一声，已然中拳。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -30); me->start_busy(2 + random(3));
      Performs.feedback(attacker, 30, 2 + Engine.rand(rng, 3))

      conn
      |> Broadcast.publish(
        Messages.interpolate("$n不慌不忙，以快打快，将$N这招化去。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LAN "「" HIG "青天揽日月" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/henshan-quan/lan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(LAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("henshan-quan", 1) < 60)
  #                 return notify_fail("你衡山拳法不够娴熟，难以施展" LAN "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "henshan-quan")
  #                 return notify_fail("你没有激发衡山拳法，难以施展" LAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "henshan-quan")
  #                 return notify_fail("你没有准备衡山拳法，难以施展" LAN "。\n");
  # 
  #         if (me->query_skill("force") < 80)
  #                 return notify_fail("你的内功修为不够，难以施展" LAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" LAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "双拳挥出，施一招「" HIG "青天揽日月"
  #               HIC "」，拳速极快，部位极准，" HIC "分袭$n" HIC "面"
  #               "门和胸口。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = (int)me->query_skill("henshan-quan", 1);
  #                 damage += random(damage / 2);
  # 
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                           HIR "$N" HIR "出手既快，方位又奇，$n"
  #                                           HIR "闪避不及，闷哼一声，已然中拳。\n" NOR);
  # 
  #                 me->add("neili", -100);
  #             me->start_busy(2 + random(2));
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "不慌不忙，以快打快，将$N"
  #                       CYN "这招化去。\n" NOR;
  # 
  #                 me->add("neili", -30);
  #             me->start_busy(2 + random(3));
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end

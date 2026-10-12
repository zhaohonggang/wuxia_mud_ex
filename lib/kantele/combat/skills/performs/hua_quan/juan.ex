defmodule Kantele.Combat.Skills.Performs.HuaQuan.Juan do
  @moduledoc """
  perform「风卷霹雳上九天」（source hua-quan/juan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手（weapon/secondary_weapon）→
  西岳华拳>=120 → 基本内功>=180 → 真气>=400 → 激发 cuff 为西岳华拳 →
  准备 cuff 为西岳华拳 → 目标存活。
  命中判定 `random(cuff)` vs `目标 dodge/2`：命中则伤害 `cuff/2 + random(cuff)`
  （qi 伤 + 45% 外伤），攻击方忙乱 2、扣 250 真气；未命中则忙乱 3、扣 80 真气。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方消耗/忙乱分属命中与失手两支，经 `Performs.feedback/3` 由目标侧回传
    （攻击方 `start_busy` 取 max）。
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

  @perform_id "hua-quan/juan"
  @move_name "「风卷霹雳上九天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hua-quan")
    ap = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/hua-quan/juan"))
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

  # LPC: if (query_skill("hua-quan",1) < 120) / if (query_skill("force") < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "hua-quan") < 120 ->
        {:error, "你的西岳华拳不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 400)
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("cuff") != "hua-quan")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "cuff") == "hua-quan" do
      :ok
    else
      {:error, "你没有激发西岳华拳，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "hua-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared == nil or prepared |> String.split("/") |> hd() != "hua-quan" do
      {:error, "你现在没有准备使用西岳华拳，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIY "只见$N" HIY "身形疾转，双拳聚力齐发，一式「风卷霹雳上九天」携"
    #           "着隐隐风雷之势贯向$n" HIY "！\n" NOR;
    #      命中/失手与攻击方消耗/忙乱均在目标侧结算（dp 需目标 dodge）。
    conn
    |> Broadcast.publish(
      "只见$N身形疾转，双拳聚力齐发，一式#{@move_name}携着隐隐风雷之势贯向$n！\n",
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
    dodge = Stats.skill(stats, "dodge")

    if Engine.rand(rng, ap) > div(dodge, 2) do
      # LPC: me->start_busy(2);
      #      damage = me->query_skill("cuff"); damage = damage / 2 + random(damage);
      #      me->add("neili", -250);
      damage = div(ap, 2) + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 45, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 250, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$n闪避不及，被$P双拳贯中，凄然一声惨嚎，口喷鲜血，身子向后飞出丈许。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(3); me->add("neili", -80);
      Performs.feedback(attacker, 80, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("$p见$P拳势汹涌，不敢硬作抵挡，当即斜斜一跃避开。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JUAN "「" HIY "风卷霹雳上九天" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/hua-quan/juan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JUAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("hua-quan", 1) < 120)
  #                 return notify_fail("你的西岳华拳不够娴熟，难以施展" JUAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" JUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "hua-quan")
  #                 return notify_fail("你没有激发西岳华拳，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "hua-quan")
  #                 return notify_fail("你现在没有准备使用西岳华拳，难以施展" JUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "只见$N" HIY "身形疾转，双拳聚力齐发，一式「风卷霹雳上九天」携"
  #               "着隐隐风雷之势贯向$n" HIY "！\n" NOR;
  # 
  #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("cuff");
  #                 damage = damage / 2 + random(damage);
  #                 me->add("neili", -250);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "结果$n" HIR "闪避不及，被$P" HIR
  #                                            "双拳贯中，凄然一声惨嚎，口喷鲜血，身"
  #                                            "子向后飞出丈许。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -80);
  #                 msg += CYN "$p" CYN "见$P" CYN "拳势汹涌，不敢硬"
  #                        "作抵挡，当即斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

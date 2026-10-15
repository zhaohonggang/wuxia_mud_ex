defmodule Kantele.Combat.Skills.Performs.QishiJi.Juan do
  @moduledoc """
  旋转卷刺「juan」（对照 `kungfu/skill/qishi-ji/juan.c`）

  齐氏戟法单体攻击：需持棍棒类武器（club）、齐氏戟法>=100、激发 club 为
  齐氏戟法、内功>=150、真气>=200、目标存活。命中判定
  `ap/2 + random(ap) > 目标parry`（ap = club）：命中造成 `ap + random(ap)`
  （外伤 90%）并扣 50 真气、忙乱 2；未命中扣 30 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 引子在攻击方广播，命中/落空在目标侧结算；命中文案需攻击方兵器名，随 data 传递。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "qishi-ji/juan"
  @move_name "「旋转卷刺」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/qishi-ji/juan"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "club")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "club" do
      {:ok, weapon}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("qishi-ji", 1) < 100)
  defp check_level(stats) do
    if Stats.skill(stats, "qishi-ji") < 100 do
      {:error, "你圣骑士戟修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("club") != "qishi-ji")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "club") == "qishi-ji" do
      :ok
    else
      {:error, "你没有激发圣骑士戟，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIY "$N" HIY "连退数步，手中" + weapon->name() + HIY "急速旋"
    #           "转，戟尖顿时激起一股气流，直刺$n" HIY "而去！\n" NOR;
    #      ap = me->query_skill("club");
    conn =
      Broadcast.publish(
        conn,
        "$N连退数步，手中" <> weapon_name <> "急速旋转，戟尖顿时激起一股气流，直刺$n而去！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "club"),
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("club"); dp = target->query_skill("parry");
    ap = max(Map.get(data, :ap, 0), 1)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap); do_damage(..., damage, 90, ...);
      #      me->add("neili", -50); me->start_busy(2);
      damage = ap + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 90, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "结果$n躲闪不慎，被$N的" <> weapon_name <> "戟尖刺中要害，登时鲜血飞溅！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 50, 2)
      put_character(conn, character)
    else
      # LPC: me->add("neili", -30); me->start_busy(3);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "可是$p并不慌乱，收敛心神，闪避开了$P的疾刺攻击。\n",
            bindings
          )
        )

      Performs.feedback(attacker, 30, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "qishi-ji/juan",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JUAN "「" HIY "旋转卷刺" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/qishi-ji/juan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUAN "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "club")
  #                 return notify_fail("你所使用的武器不对，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill("qishi-ji", 1) < 100)
  #                 return notify_fail("你圣骑士戟修为不够，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill_mapped("club") != "qishi-ji")
  #                 return notify_fail("你没有激发圣骑士戟，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功修为不够，难以施展" JUAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" JUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "连退数步，手中" + weapon->name() + HIY "急速旋"
  #               "转，戟尖顿时激起一股气流，直刺$n" HIY "而去！\n" NOR;
  # 
  #         ap = me->query_skill("club");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 me->add("neili", -50);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 90,
  #                                            HIR "结果$n" HIR "躲闪不慎，被$N" HIR
  #                                            "的" + weapon->name() + HIR "戟尖刺中"
  #                                            "要害，登时鲜血飞溅！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -30);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "并不慌乱，收敛心神，闪避开了$P"
  #                        CYN "的疾刺攻击。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

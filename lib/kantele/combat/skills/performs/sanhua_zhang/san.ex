defmodule Kantele.Combat.Skills.Performs.SanhuaZhang.San do
  @moduledoc """
  天女散花「san」（对照 `kungfu/skill/sanhua-zhang/san.c`）

  散花掌法单体攻击：需散花掌法>=135、内功>=180、真气>=200、激发 strike 为
  散花掌法、目标存活。命中判定
  `random(自身strike) > 目标dodge/2`：命中造成
  `strike/2 + random(strike/2)`（外伤 40%）并扣 150 真气、忙乱 2；
  未命中扣 50 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 无 `can_perform` 门槛，本引擎保留 `perform_known?` 守卫（多 1 条信息性 EXTRA）；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 引子在攻击方广播，命中/落空在目标侧结算。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "sanhua-zhang/san"
  @move_name "天女散花"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC 无 can_perform 门槛；本引擎保留已知绝招守卫（信息性 EXTRA）。
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("sanhua-zhang", 1) < 135)
  defp check_level(stats) do
    if Stats.skill(stats, "sanhua-zhang") < 135 do
      {:error, "你的散花掌法不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 180)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "sanhua-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "sanhua-zhang" do
      :ok
    else
      {:error, "你没有激发散花掌，无法使用#{@move_name}！\n"}
    end
  end

  defp apply_perform(conn, character, target, stats) do
    # LPC: msg = HIY "$N" HIY "哈哈一笑，双掌一错，忽然化作漫天"
    #           "掌影，犹如千百只手掌一齐攻向$n" HIY "！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N哈哈一笑，双掌一错，忽然化作漫天掌影，犹如千百只手掌一齐攻向$n！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        strike: Stats.skill(stats, "strike"),
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
    strike = max(Map.get(data, :strike, 0), 1)
    dp = div(Stats.skill(stats, "dodge"), 2)

    if Engine.rand(rng, strike) > dp do
      # LPC: damage = me->query_skill("strike");
      #      damage = damage / 2 + random(damage / 2);
      #      do_damage(..., damage, 40, ...);
      #      me->start_busy(2); me->add("neili", -150);
      damage = div(strike, 2) + Engine.rand(rng, max(div(strike, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: HIR "结果$p" HIR "没能避开$P" HIR "变幻莫测的掌法，蓬蓬接连中了数掌，"
      #      "被打得口喷鲜血，几乎摔倒！\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "结果$p没能避开$P变幻莫测的掌法，蓬蓬接连中了数掌，被打得口喷鲜血，几乎摔倒！\n",
            bindings
          )
        )

      Performs.feedback(attacker, 150, 2)
      put_character(conn, character)
    else
      # LPC: me->start_busy(3); me->add("neili", -50);
      #      msg += CYN "可是$p" CYN "识破了$P" CYN "这一招，斜斜一跃避开。\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate("可是$p识破了$P这一招，斜斜一跃避开。\n", bindings)
        )

      Performs.feedback(attacker, 50, 3)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "sanhua-zhang/san",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // san.c 天女散花
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("天女散花只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("sanhua-zhang", 1) < 135)
  #                 return notify_fail("你的散花掌法不够娴熟，不会使用天女散花。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展天女散花。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在真气不够，无法使用天女散花。\n");
  # 
  #     if (me->query_skill_mapped("strike") != "sanhua-zhang")
  #         return notify_fail("你没有激发散花掌，无法使用天女散花！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "哈哈一笑，双掌一错，忽然化作漫天"
  #               "掌影，犹如千百只手掌一齐攻向$n" HIY "！\n" NOR;
  # 
  #         if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("strike");
  #                 damage = damage / 2 + random(damage / 2);
  #                 me->add("neili", -150);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                            HIR "结果$p" HIR "没能避开$P" HIR
  #                                            "变幻莫测的掌法，蓬蓬接连中了数掌，"
  #                                            "被打得口喷鲜血，几乎摔倒！\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -50);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

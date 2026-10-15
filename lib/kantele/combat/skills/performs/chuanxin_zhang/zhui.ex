defmodule Kantele.Combat.Skills.Performs.ChuanxinZhang.Zhui do
  @moduledoc """
  穿心锥「zhui」（对照 `kungfu/skill/chuanxin-zhang/zhui.c`，inherit F_SSERVER）

  穿心掌法攻击绝招：要求内力 >= 200、内功 force >= 150、chuanxin-zhang >= 100、
  已激发 strike 映射；按 strike 技能与 target dodge/2 判定命中，命中扣攻击方内力 150
  （落空 50）并令其忙乱。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "chuanxin-zhang/zhui"
  @move_name "「穿心锥」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
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

  defp check_skill_level(stats) do
    if Stats.skill(stats, "chuanxin-zhang") < 100 do
      {:error, "你的穿心掌不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "chuanxin-zhang" do
      :ok
    else
      {:error, "你没有激发穿心掌，无法使用#{@move_name}！\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    # LPC: msg = HIY "\n$N" HIY "一声冷笑，双掌一错，陡然施出一招"
    #            "「" HIW "穿心锥" HIY "」，幻出千百之手掌一齐" "插向$n" HIY "！" NOR;
    start_msg = "$N一声冷笑，双掌一错，陡然施出一招「穿心锥」，幻出千百之手掌一齐插向$n！\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
    ap = Stats.skill(stats, "strike")
    dp = div(Stats.skill(target.meta.stats, "dodge"), 2)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
    hit = Engine.rand(rng, ap) > dp

    if hit do
      # LPC: damage = me->query_skill("strike");  damage = damage / 2 + random(damage / 2);
      #      me->add("neili", -150);  me->start_busy(2);
      #      COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45, msg);
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 45, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: "结果$p" "没能避开$P" "变幻莫测的掌法，掌劲顿时透胸而过，"
      #      "口喷鲜血，几乎摔倒！\n"
      hit_msg = "结果$p没能避开$P变幻莫测的掌法，掌劲顿时透胸而过，口喷鲜血，几乎摔倒！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 150, 2)
    else
      # LPC: me->add("neili", -50);  me->start_busy(3);
      #      "可是$p" "识破了$P" "这一招，斜斜一跃避开。\n"
      miss_msg = "可是$p识破了$P这一招，斜斜一跃避开。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 50, 3)
    end

    conn
    |> put_character(character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  # ===== 原始 LPC 源码（逐行保留，供核对；移植稳定后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # inherit F_SSERVER;
  #
  # #define ZHUI "「" HIW "穿心锥" NOR "」"
  #
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  #
  #         if (! target) target = offensive_target(me);
  #
  #         if (userp(me) && ! me->query("can_perform/chuanxin-zhang/zhui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUI "只能对战斗中的对手使用。\n");
  #
  #         if ((int)me->query_skill("chuanxin-zhang", 1) < 100)
  #                 return notify_fail("你的穿心掌不够娴熟，不会使用" ZHUI "。\n");
  #
  #         if ((int)me->query_skill("force", 1) < 150)
  #                 return notify_fail("你的内功修为不够，难以施展" ZHUI "。\n");
  #
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在真气不够，无法使用" ZHUI "。\n");
  #
  #         if (me->query_skill_mapped("strike") != "chuanxin-zhang")
  #                 return notify_fail("你没有激发穿心掌，无法使用" ZHUI "！\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIY "\n$N" HIY "一声冷笑，双掌一错，陡然施出一招"
  #               "「" HIW "穿心锥" HIY "」，幻出千百之手掌一齐"
  #               "插向$n" HIY "！" NOR;
  #
  #         if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("strike");
  #                 damage = damage / 2 + random(damage / 2);
  #                 me->add("neili", -150);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                           HIR "结果$p" HIR "没能避开$P" HIR
  #                                           "变幻莫测的掌法，掌劲顿时透胸而过，"
  #                                           "口喷鲜血，几乎摔倒！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -50);
  #                 me->start_busy(3);
  #                 msg = CYN "可是$p" CYN "识破了$P"
  #                       CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #
  #         return 1;
  # }
end

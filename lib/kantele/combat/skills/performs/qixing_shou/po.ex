defmodule Kantele.Combat.Skills.Performs.QixingShou.Po do
  @moduledoc """
  perform「破穹」（source qixing-shou/po.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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
  alias Kantele.Combat.Performs

  @perform_id "qixing-shou/po"
  @move_name "「破穹云蛟」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qixing-shou")
    ap = Stats.skill(stats, "hand")
    damage = div(lvl, 2) + Engine.rand(rng, div(lvl, 2))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
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

      apply_effect(conn, character, target)
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "qixing-shou") < 150 -> {:error, "你七星分天手不够娴熟，难以施展#{@move_name}。\n"}
      Stats.skill(stats, "force") < 200 -> {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "hand") != "qixing-shou" ->
        {:error, "你没有激发七星分天手，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "hand") == nil or
          String.split(Stats.prepared_perform(stats, "hand"), "/") |> hd() != "qixing-shou" ->
        {:error, "你没有准备七星分天手，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "只有空手才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character, target) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        Enum.join(["双目圆睁，单手陡然一振，袖底顿时窜出一道", "紫光，直射$n前胸。"]),
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    vitals = character.meta.vitals

    {vitals, conn} =
      landing(
        conn,
        stats,
        bindings,
        vitals,
        ap,
        damage,
        rng,
        "parry",
        "但见$P这道气劲来势迅猛之极，$n如何避得，顿时被紫劲震开了数尺！",
        "$p见势不妙，急忙向后纵开数尺，避开了$P这招。"
      )

    conn =
      Broadcast.publish(
        conn,
        "紧接着$N左掌蓦的一抬，凭空虚划了道弧芒，至上而下反推$n后颈。",
        bindings
      )

    {vitals, conn} =
      landing(
        conn,
        stats,
        bindings,
        vitals,
        ap,
        damage,
        rng,
        "dodge",
        "$p只觉后颈一麻，已被$N这招击个正中，顿时全身瘫软，呕出一口鲜血！",
        "可是$p丝毫不为$P所动，奋力格挡，稳稳将这一招架开。"
      )

    conn =
      Broadcast.publish(
        conn,
        "便在此时，却见$N双掌猛然回圈，平推而出，顿时层层气浪直袭$n。",
        bindings
      )

    {vitals, conn} =
      landing(
        conn,
        stats,
        bindings,
        vitals,
        ap,
        damage,
        rng,
        "force",
        "$p在$N的猛攻之下，已再无余力招架，竟被这一掌震得飞起，摔了出去！",
        "然而$p沉身聚气，奋力一格，便将$P这掌驱于无形。"
      )

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 3))

    put_character(conn, character)
  end

  defp landing(conn, stats, bindings, vitals, ap, damage, rng, dp_skill, hit_msg, miss_msg) do
    dp = Stats.skill(stats, dp_skill)
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp

    if hit do
      vitals = Vitals.damage(vitals, :qi, damage)
      {vitals, Broadcast.publish(conn, hit_msg, bindings)}
    else
      {vitals, Broadcast.publish(conn, miss_msg, bindings)}
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"ap", "hand"}, {"damage", "qixing-shou"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(3));"], "level_gates": [{"force", "200"}, {"qixing-shou", "150"}], "map_gates": [{"hand", "qixing-shou"}], "prepared_gates": [{"hand", "qixing-shou"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIC "破穹" HIW "云" HIC "蛟" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  #         // string wname;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/qixing-shou/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("只有空手才能施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("qixing-shou", 1) < 150)
  #                 return notify_fail("你七星分天手不够娴熟，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "qixing-shou")
  #                 return notify_fail("你没有激发七星分天手，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "qixing-shou")
  #                 return notify_fail("你没有准备七星分天手，难以施展" PO "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功修为不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不足，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         damage = (int)me->query_skill("qixing-shou", 1) / 2;
  #         damage += random(damage);
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("parry");
  #         msg = HIC "$N" HIC "双目圆睁，单手陡然一振，袖底顿时窜出一道" NOR + MAG
  #               "紫光" HIC "，直射$n" HIC "前胸。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "但见$P" HIR "这道气劲来势迅猛之极"
  #                                            "，$n" HIR "如何避得，顿时被紫劲震开了"
  #                                            "数尺！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "见势不妙，急忙向后纵开数尺，避开了$P"
  #                        CYN "这招。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("dodge");
  #         msg += "\n" HIC "紧接着$N" HIC "左掌蓦的一抬，凭空虚划了道" HIY "弧芒" HIC
  #                "，至上而下反推$n" HIC "后颈。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
  #                                            HIR "$p" HIR "只觉后颈一麻，已被$N" HIR
  #                                            "这招击个正中，顿时全身瘫软，呕出一口鲜"
  #                                            "血！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "丝毫不为$P"
  #                        CYN "所动，奋力格挡，稳稳将这一招架开。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("force");
  #         msg += "\n" HIC "便在此时，却见$N" HIC "双掌猛然回圈，平推而出，顿时层层"
  #                HIW "气浪" HIC "直袭$n" HIC "。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$p" HIR "在$N" HIR "的猛攻之下，已"
  #                                            "再无余力招架，竟被这一掌震得飞起，摔了"
  #                                            "出去！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "然而$p" CYN "沉身聚气，奋力一格，便将$P"
  #                        CYN "这掌驱于无形。\n" NOR;
  #         }
  #         me->start_busy(2 + random(3));
  #         me->add("neili", -200);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end

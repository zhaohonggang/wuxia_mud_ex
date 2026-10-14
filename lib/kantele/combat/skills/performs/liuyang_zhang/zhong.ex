defmodule Kantele.Combat.Skills.Performs.LiuyangZhang.Zhong do
  @moduledoc """
  perform「生死符」（source liuyang-zhang/zhong.c，inherit F_SSERVER）

  手工补齐：门槛文案按字符串宏 `ZHONG`（→「生死符」）展开；命中判定、精神外伤、
  生死符毒与双方忙乱按原始 LPC 语义建模。本式无内力消耗。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "liuyang-zhang/zhong"

  # LPC: #define ZHONG "「" HIW "生死符" NOR "」"
  @move_name "「生死符」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(stats),
         :ok <- check_mapped(stats),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      # LPC: ap = me->query_skill("force") + me->query_skill("throwing")
      #              + me->query_skill("medical");
      #      flvl = me->query("jiali");
      ap = Stats.skill(stats, "force") + Stats.skill(stats, "throwing") + Stats.skill(stats, "medical")
      flvl = combat.jiali

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          flvl: flvl,
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

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 200)
  #      if (me->query_skill("liuyang-zhang", 1) < 150)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "force") < 200 ->
        {:error, "你的内功不够火候，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "liuyang-zhang") < 150 ->
        {:error, "你的天山六阳掌不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #      if (me->query_skill_mapped("throwing") != "liuyang-zhang")
  #      if (me->query_skill_prepared("strike") != "liuyang-zhang")
  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "strike") != "liuyang-zhang" ->
        {:error, "你没有激发掌法天山六阳掌，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "throwing") != "liuyang-zhang" ->
        {:error, "你没有激发暗器天山六阳掌，难以施展#{@move_name}。\n"}

      prepared_is_not?(stats, "strike", "liuyang-zhang") ->
        {:error, "你现在没有准备天山六阳掌，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC query_skill_prepared 返回绝招 ID（如 "liuyang-zhang/zhong"），需按技能前缀比对。
  defp prepared_is_not?(stats, skill, mapped) do
    case Stats.prepared_perform(stats, skill) do
      nil -> true
      prepared -> hd(String.split(prepared, "/")) != mapped
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # 本式无 neili 消耗、无攻击方忙乱（LPC 未出现 add/start_busy 于施法者）。
  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "$N" HIW "逆运真气，化空气中的水露为寒冰，凝于掌中，继而掌"
    #               "出如风，轻飘飘地向$n" HIW "拍落。\n";（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "$N逆运真气，化空气中的水露为寒冰，凝于掌中，继而掌出如风，轻飘飘地向$n拍落。\n",
        n1: character.name,
        n2: target.name
      )

    conn
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
    flvl = Map.get(data, :flvl, 0)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("force") + target->query_skill("medical");
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "medical")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 3 + random(ap) > dp)
    hit? = div(ap, 3) + Engine.rand(rng, ap) > dp

    if hit? do
      # LPC: target->receive_wound("jing", 10 + random(5), me);
      vitals = Vitals.wound(character.meta.vitals, :jing, 10 + Engine.rand(rng, 5))
      # LPC: damage = ap / 2 + random(ap / 2);
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))
      vitals = vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 50, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: target->affect_by("ss_poison",
      #      ([ "level" : flvl + random(flvl * 2), "id" : me->query("id"),
      #         "duration" : ap / 70 + random(ap / 30) ]));
      poison_duration = div(ap, 70) + Engine.rand(rng, div(ap, 30))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => flvl + Engine.rand(rng, flvl * 2),
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "生死符"
        })

      # LPC: me->start_busy(1 + random(4));（仅命中分支，跨进程回执）
      _ = Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 4))

      # LPC: HIR "只见$n" HIR "被$N" HIR "一掌拍中" "，紧接着身子一颤，$P" HIR "那枚生死符"
      #      "已种入$p" HIR "体内！\n" NOR;（合并为单段）
      conn
      |> Broadcast.publish("只见$n被$N一掌拍中，紧接着身子一颤，$P那枚生死符已种入$p体内！\n", bindings)
      |> put_character(character)
    else
      # LPC: CYN "可是$p" CYN "内力激荡，将$P" CYN "那枚生死符硬生生震出体外。\n" NOR;
      # （合并为单段）
      # LPC: me->start_busy(3); target->start_busy(1);
      _ = Performs.feedback(attacker, 0, 3)
      combat = Combat.start_busy(character.meta.combat, 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish("可是$p内力激荡，将$P那枚生死符硬生生震出体外。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHONG "「" HIW "生死符" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int damage;
  #         int ap, dp, flvl;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyang-zhang/zhong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHONG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功不够火候，难以施展" ZHONG "。\n");
  # 
  #         if ((int)me->query_skill("liuyang-zhang", 1) < 150)
  #                 return notify_fail("你的天山六阳掌不够娴熟，难以施展" ZHONG "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyang-zhang")
  #                 return notify_fail("你没有激发掌法天山六阳掌，难以施展" ZHONG "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "liuyang-zhang")
  #                 return notify_fail("你没有激发暗器天山六阳掌，难以施展" ZHONG "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyang-zhang")
  #                 return notify_fail("你现在没有准备天山六阳掌，难以施展" ZHONG "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你的真气不够，难以施展" ZHONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "逆运真气，化空气中的水露为寒冰，凝于掌中，继而掌"
  #               "出如风，轻飘飘地向$n" HIW "拍落。\n";
  # 
  #         ap = me->query_skill("force") + me->query_skill("throwing") + me->query_skill("medical");
  #         dp = target->query_skill("force") + target->query_skill("medical");
  #         flvl = me->query("jiali");
  #         if (ap / 3 + random(ap) > dp)
  #         {
  #                 target->receive_wound("jing", 10 + random(5), me);
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 50,
  #                                            HIR "只见$n" HIR "被$N" HIR "一掌拍中"
  #                                            "，紧接着身子一颤，$P" HIR "那枚生死符"
  #                                            "已种入$p" HIR "体内！\n" NOR);
  #                 target->affect_by("ss_poison",
  #                                ([ "level" : flvl + random(flvl * 2),
  #                                   "id"    : me->query("id"),
  #                                   "duration" : ap / 70 + random(ap / 30) ]));
  #                 me->start_busy(1 + random(4));
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "内力激荡，将$P"
  #                        CYN "那枚生死符硬生生震出体外。\n" NOR;
  #                 me->start_busy(3);
  #                 target->start_busy(1);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

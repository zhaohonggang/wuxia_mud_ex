defmodule Kantele.Combat.Skills.Performs.HuaguMianzhang.Hua do
  @moduledoc """
  perform「化骨掌」（source huagu-mianzhang/hua.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 基本内功>=150 → 化骨绵掌>=100 →
  真气>=300 → 激发 strike 为化骨绵掌 → 目标存活。
  攻击方恒扣 100 真气；命中判定 `ap/2 + random(ap)` vs 目标 `force`
  （`ap = 化骨绵掌/2*3`）：命中则伤害 `ap/3 + random(ap/2)`（qi 伤 + 40% 外伤）、
  附加 huagu 毒（`level = jiali + random(jiali)`，`duration = ap/60 + random(ap/60)`）、
  攻击方忙乱 2；未命中攻击方忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `do_damage(..., 40, (: final, me, target, damage :))` 的 `final` 回调折算为
    命中分支内的毒附着 + 结果文案；
  - `target->affect_by("huagu", …)` 折算为 `ConditionEvent.apply_poison/2`
    （`.c` 未给毒名，此处补 `"name" => "化骨掌伤"`，取自
    `kungfu/condition/huagu.c` 的 `chinese_name()`，仅供显示）；
  - `me->query("jiali")` 取 `combat.jiali` 经事件数据传给目标侧。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "huagu-mianzhang/hua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huagu-mianzhang")
    # LPC: ap = me->query_skill("huagu-mianzhang", 1) / 2 * 3;
    ap = div(lvl, 2) * 3

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
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
          jiali: combat.jiali,
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
      [] -> {:error, "辣手化骨只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (query_skill("force") < 150) / if (query_skill("huagu-mianzhang", 1) < 100)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，无法施展化骨掌。\n"}

      Stats.skill(stats, "huagu-mianzhang") < 100 ->
        {:error, "你的化骨绵掌还不够娴熟，不会化骨掌。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili", 1) < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的真气不够，不能化骨。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "huagu-mianzhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "huagu-mianzhang" do
      :ok
    else
      {:error, "你没有激发化骨绵掌，无法施展化骨掌。\n"}
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
    # LPC: me->add("neili", -100);
    #      msg = MAG "$N" MAG "掌出如风，轻轻拍向$n" MAG "的肩头。\n"NOR;
    #      命中/失手与攻击方忙乱均在目标侧结算（dp 需目标 force）。
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish("$N掌出如风，轻轻拍向$n的肩头。\n",
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
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    jiali = Map.get(data, :jiali, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force");
    dp = Stats.skill(stats, "force")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC final(): lvl = me->query_skill("huagu-mianzhang", 1) / 2 * 3;
      #              target->affect_by("huagu",
      #                ([ "level" : me->query("jiali") + random(me->query("jiali")),
      #                   "id"    : me->query("id"),
      #                   "duration" : lvl / 60 + random(lvl / 60) ]));
      poison_level = jiali + Engine.rand(rng, max(jiali, 1))
      poison_duration = div(ap, 60) + Engine.rand(rng, max(div(ap, 60), 1))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "化骨掌伤"
        })

      # LPC: damage = ap / 3 + random(ap / 2);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 40, (: final, … :));
      #      me->start_busy(2);
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 2), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果只听扑的一声，$p被$P一掌拍中，只觉得全身暖洋洋的，感到有点轻飘无力。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "急忙闪在一旁，躲了开去。\n" NOR;
      #      me->start_busy(3);
      Performs.feedback(attacker, 0, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p急忙闪在一旁，躲了开去。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // hua.c 化骨绵掌
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         string msg;
  #         int damage;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("辣手化骨只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，无法施展化骨掌。\n");
  # 
  #         if ((int)me->query_skill("huagu-mianzhang", 1) < 100)
  #                 return notify_fail("你的化骨绵掌还不够娴熟，不会化骨掌。\n");
  # 
  #         if ((int)me->query("neili", 1) < 300)
  #                 return notify_fail("你的真气不够，不能化骨。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "huagu-mianzhang")
  #                 return notify_fail("你没有激发化骨绵掌，无法施展化骨掌。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -100);
  # 
  #         msg = MAG "$N" MAG "掌出如风，轻轻拍向$n" MAG "的肩头。\n"NOR;
  # 
  #         ap = me->query_skill("huagu-mianzhang", 1) / 2 * 3;
  #         dp = target->query_skill("force");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->start_busy(2);
  #                 damage = ap / 3 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                           (: final, me, target, damage :));
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "急忙闪在一旁，躲了开去。\n" NOR;
  #                 me->start_busy(3);
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         int lvl = me->query_skill("huagu-mianzhang", 1) / 2 * 3;
  # 
  #         target->affect_by("huagu",
  #                 ([ "level"    : me->query("jiali") + random(me->query("jiali")),
  #                    "id"       : me->query("id"),
  #                    "duration" : lvl / 60 + random(lvl / 60) ]));
  # 
  #         return HIR "结果只听扑的一声，$p被$P一掌拍中，只"
  #                "觉得全身暖洋洋的，感到有点轻飘无力。\n" NOR;
  # }
end

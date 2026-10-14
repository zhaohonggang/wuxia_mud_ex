defmodule Kantele.Combat.Skills.Performs.PiaoxuZhang.Piao do
  @moduledoc """
  perform「飞絮飘零」（对照 `kungfu/skill/piaoxu-zhang/piao.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手 → 飘絮掌法>=80 →
  激发 strike 为飘絮掌法 → 准备 strike 为飘絮掌法 → 真气>=100 → 目标存活。
  起手广播后攻击方扣 50 真气，由目标侧判定
  `random(内功 + 掌法) > 目标内功`：命中则广播「眼花缭乱…」并取
  `count = 飘絮掌法/5`，否则广播「丝毫不受掌影的干扰，。」且 `count = 0`；
  随后连出 3 击（空手），攻击方忙乱 `random(3)`。

  差异（TODO(migrate)）：
  - `me->add_temp("apply/attack", ±count)` 的临时加成折入目标侧逐击命中判定
    （攻击方本地 temp 对远程结算无意义），收招的 `-count` 不再重复落账
    （同 `luoyan_jian/luo.ex`、`panlong_suo/sha.ex`）；
  - 分支判定需目标内功，故两条分支文案在目标侧广播（起手文案在攻击方）；
  - `.c` 的 `me->start_busy(random(3))` 位于 3 击之后，而 E 侧起手效果与目标侧
    连击是两个异步事件，故收敛在攻击方 apply_effect 中统一结算；
  - `.c` 起手文案「全全笼罩」与未命中文案「丝毫不受掌影的干扰，。」按原文
    逐字保留（不改写叠字与多余标点）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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

  @perform_id "piaoxu-zhang/piao"
  @move_name "「飞絮飘零」"

  # LPC: for (i = 0; i < 3; i++) COMBAT_D->do_attack(me, target, 0, 0);
  @strikes 3

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: random(me->query_skill("force") + me->query_skill("strike")) —— 分支判定基数。
    ap = Stats.skill(stats, "force") + Stats.skill(stats, "strike")

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
          ap: ap,
          strikes: @strikes,
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

  # LPC: if (userp(me) && ! me->query("can_perform/piaoxu-zhang/piao"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "#{@move_name}只能空手施展。\n"}
    end
  end

  # LPC: if ((lvl = me->query_skill("piaoxu-zhang", 1)) < 80)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "piaoxu-zhang") < 80 do
      {:error, "你飘絮掌法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "piaoxu-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "piaoxu-zhang" do
      :ok
    else
      {:error, "你没有激发飘絮掌法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "piaoxu-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared != nil and hd(String.split(prepared, "/")) == "piaoxu-zhang" do
      :ok
    else
      {:error, "你没有准备飘絮掌法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, rng) do
    # LPC: msg = HIW "$N" HIW "微微一笑，单掌施出飘絮掌法绝技「飞絮飘零」，顿时掌"
    #            "影重重，虚实难辨，全全笼罩$n" HIW "而去。\n" NOR;
    #      me->add("neili", -50);
    #      … 分支 + 3 击（目标侧结算）…
    #      me->start_busy(random(3));
    conn =
      Broadcast.publish(
        conn,
        "$N微微一笑，单掌施出飘絮掌法绝技「飞絮飘零」，顿时掌影重重，虚实难辨，全全笼罩$n而去。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -50);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 50, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(random(3));（random(3) 可为 0，start_busy/2 取 max，等价无操作）
    combat = Combat.start_busy(character.meta.combat, Engine.rand(rng, 3))
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    strikes = Map.get(data, :strikes, @strikes)
    level = Stats.skill(character.meta.stats, "piaoxu-zhang")
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: target->query_skill("force")
    force = Stats.skill(character.meta.stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("force") + me->query_skill("strike")) >
    #            target->query_skill("force"))
    #      { msg += "$n顿时觉得眼花缭乱，全然分辨不清真伪，只得拼命运动抵挡。\n";
    #        count = lvl / 5; }
    #      else
    #      { msg += "可是$n凝神顿气，奋力抵挡，丝毫不受掌影的干扰，。\n";
    #        count = 0; }
    #      message_combatd(msg, me, target);
    {conn, count} =
      if Engine.rand(rng, ap) > force do
        conn =
          Broadcast.publish(
            conn,
            "$n顿时觉得眼花缭乱，全然分辨不清真伪，只得拼命运动抵挡。\n",
            bindings
          )

        {conn, div(level, 5)}
      else
        conn =
          Broadcast.publish(
            conn,
            "可是$n凝神顿气，奋力抵挡，丝毫不受掌影的干扰，。\n",
            bindings
          )

        {conn, 0}
      end

    # LPC: for (i = 0; i < 3; i++) { if (! me->is_fighting(target)) break;
    #            COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（ap/2 + count + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        if div(ap, 2) + count + Engine.rand(rng, ap) > dodge do
          per_hit = max(div(level, 15), 1)
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit)}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PIAO "「" HIW "飞絮飘零" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/piaoxu-zhang/piao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PIAO "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(PIAO "只能空手施展。\n");
  # 
  #         if ((lvl = (int)me->query_skill("piaoxu-zhang", 1)) < 80)
  #                 return notify_fail("你飘絮掌法不够娴熟，难以施展" PIAO "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "piaoxu-zhang")
  #                 return notify_fail("你没有激发飘絮掌法，难以施展" PIAO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "piaoxu-zhang")
  #                 return notify_fail("你没有准备飘絮掌法，难以施展" PIAO "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不足，难以施展" PIAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "微微一笑，单掌施出飘絮掌法绝技「飞絮飘零」，顿时掌"
  #               "影重重，虚实难辨，全全笼罩$n" HIW "而去。\n" NOR;
  #         me->add("neili", -50);
  # 
  #         if (random(me->query_skill("force") + me->query_skill("strike")) >
  #             target->query_skill("force"))
  #         {
  #                 msg += HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
  #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝"
  #                        "毫不受掌影的干扰，。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < 3; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->start_busy(random(3));
  #         me->add_temp("apply/attack", -count);
  #         return 1;
  # }
end

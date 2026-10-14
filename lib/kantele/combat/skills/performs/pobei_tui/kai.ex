defmodule Kantele.Combat.Skills.Performs.PobeiTui.Kai do
  @moduledoc """
  perform「五岳为开」（对照 `kungfu/skill/pobei-tui/kai.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手 → 内功>=150 →
  破碑腿>=100 → 激发 unarmed 为破碑腿 → 准备 unarmed 为破碑腿 →
  真气>=150 → 目标存活。
  起手广播后攻击方扣 100 真气，由目标侧判定
  `random(内功 + 拳脚) > 目标内功`：命中则广播「全然分辨不清真伪…」并取
  `count = 破碑腿/5`，否则广播「丝毫不受腿影的干扰，。」且 `count = 0`；
  随后连出 4 击，收招忙乱 `random(4)`。

  差异（TODO(migrate)）：
  - `me->add_temp("apply/attack", ±count)` 的临时加成折入目标侧逐击命中判定
    （攻击方本地 temp 对远程结算无意义），收招的 `-count` 不再重复落账
    （同 `luoyan_jian/luo.ex`）；
  - `.c` 的 4 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `level/15 + count` 基础伤害 + 命中判定（`ap/2 + count + random(ap)` vs
    目标 dodge）；`do_attack` 无独立命中/失手文案，由引擎动作表生成，故本文件
    不再自行发布逐击结果文案；
  - `.c` 的 `me->start_busy(random(4))` 位于 4 击之后，而 E 侧起手效果与目标侧
    连击是两个异步事件，故收敛在攻击方 apply_effect 中统一结算；
  - 分支文案需目标内功，故在目标侧广播（起手文案在攻击方）；
  - `.c` 未命中文案写作「丝毫不受腿影的干扰，。」（多余句号），按原文逐字保留；
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

  @perform_id "pobei-tui/kai"
  @move_name "「五岳为开」"

  # LPC: for (i = 0; i < 4; i++) COMBAT_D->do_attack(me, target, 0, 0);
  @strikes 4

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: random(me->query_skill("force") + me->query_skill("unarmed"))
    ap = Stats.skill(stats, "force") + Stats.skill(stats, "unarmed")

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

  # LPC: if (userp(me) && ! me->query("can_perform/pobei-tui/kai"))
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
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 150)
  #      if ((lvl = me->query_skill("pobei-tui", 1)) < 100)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候太浅，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "pobei-tui") < 100 ->
        {:error, "你的破碑腿不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "pobei-tui")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "unarmed") == "pobei-tui" do
      :ok
    else
      {:error, "你现在没有激发破碑腿，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "pobei-tui")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared != nil and hd(String.split(prepared, "/")) == "pobei-tui" do
      :ok
    else
      {:error, "你现在没有准备破碑腿，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili", 1) < 150)
  defp check_resources(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在真气太弱，难以施展#{@move_name}。\n"}
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
    # LPC: msg = WHT "只见$N" WHT "身形猛转，霎那间双腿流星般连环踢出，足带风尘，腿影将$n"
    #            WHT "团团笼罩。\n" NOR;
    #      me->add("neili", -100);
    #      … 分支 + 4 击（目标侧结算）…
    #      me->start_busy(random(4));
    conn =
      Broadcast.publish(
        conn,
        "只见$N身形猛转，霎那间双腿流星般连环踢出，足带风尘，腿影将$n团团笼罩。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -100);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->start_busy(random(4));
    combat = Combat.start_busy(character.meta.combat, Engine.rand(rng, 4))
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
    level = Stats.skill(character.meta.stats, "pobei-tui")
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: target->query_skill("force")
    force = Stats.skill(character.meta.stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("force") + me->query_skill("unarmed")) >
    #            target->query_skill("force"))
    #      { msg += HIR "$n" HIR "见无数腿影向自己袭来，全然分辨"
    #                     "不清真伪，只得拼命运动抵挡。\n" NOR;
    #        count = lvl / 5; }
    #      else
    #      { msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝毫不"
    #                     "受腿影的干扰，。\n" NOR;
    #        count = 0; }
    #      message_combatd(msg, me, target);
    {conn, count} =
      if Engine.rand(rng, ap) > force do
        conn =
          Broadcast.publish(
            conn,
            "$n见无数腿影向自己袭来，全然分辨不清真伪，只得拼命运动抵挡。\n",
            bindings
          )

        {conn, div(level, 5)}
      else
        conn =
          Broadcast.publish(
            conn,
            "可是$n凝神顿气，奋力抵挡，丝毫不受腿影的干扰，。\n",
            bindings
          )

        {conn, 0}
      end

    # LPC: for (i = 0; i < 4; i++) { if (! me->is_fighting(target)) break;
    #            COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击 level/15 + count 基础伤害 + 命中判定（ap/2 + count + random(ap) vs dodge）。
    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        if div(ap, 2) + count + Engine.rand(rng, ap) > dodge do
          per_hit = max(div(level, 15), 1) + count
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
  # #define KAI "「" WHT "五岳为开" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/pobei-tui/kai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" KAI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候太浅，难以施展" KAI "。\n");
  # 
  #         if ((lvl = (int)me->query_skill("pobei-tui", 1)) < 100)
  #                 return notify_fail("你的破碑腿不够娴熟，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "pobei-tui")
  #                 return notify_fail("你现在没有激发破碑腿，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "pobei-tui")
  #                 return notify_fail("你现在没有准备破碑腿，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 150)
  #                 return notify_fail("你现在真气太弱，难以施展" KAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "只见$N" WHT "身形猛转，霎那间双腿流星般连环踢出，足带风尘，腿影将$n"
  #               WHT "团团笼罩。\n" NOR;
  #         me->add("neili", -100);
  # 
  #         if (random(me->query_skill("force") + me->query_skill("unarmed")) >
  #             target->query_skill("force"))
  #         {
  #                 msg += HIR "$n" HIR "见无数腿影向自己袭来，全然分辨"
  #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝毫不"
  #                        "受腿影的干扰，。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->start_busy(random(4));
  #         me->add_temp("apply/attack", -count);
  #         return 1;
  # }
end

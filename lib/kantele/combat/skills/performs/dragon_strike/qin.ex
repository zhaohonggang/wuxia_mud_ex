defmodule Kantele.Combat.Skills.Performs.DragonStrike.Qin do
  @moduledoc """
  perform「擒龙手」（source dragon-strike/qin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 目标持有兵器 →
  内功>=260 → 内力上限>=3000 → 降龙十八掌>=180 → 激发 strike 为降龙十八掌 →
  准备降龙十八掌 → 真气>=400 → 目标存活。
  以 `ap = strike + str*10`、目标 `dp = parry + int*10` 判定
  `ap/3 + random(ap) > dp`：命中则夺械（目标武器脱手），攻击方扣 300 真气、忙乱 2；
  未命中则攻击方扣 200 真气、忙乱 3。

  差异（TODO(migrate)）：
  - 起手文案含目标兵器名、命中判定依赖目标 `parry/int`，故起手广播与结算整体
    在目标侧 `resolve_incoming/4` 完成；
  - `weapon->move(me, 1)` 的缴械折算为 `Combat.unequip(:weapon)`，不做跨进程
    物品转移（目标兵器仅解除装备）；
  - `.c` 的 `"…企图将$n" + weapon->name() + "吸入掌中。"` 等按原样拆为三段字面量；
  - 目标无兵器门槛（`target->query_temp("weapon")`）在攻击方进程无目标武器快照，
    若敌人引用带 `meta` 则照常判定，否则跳过；目标侧另做兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "dragon-strike/qin"
  @move_name "「擒龙手」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "dragon-strike")
    # LPC: ap = me->query_skill("strike") + me->query("str") * 10;
    ap = Stats.skill(stats, "strike") + stats.str * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_target_weapon(target),
         :ok <- check_gates(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          skill: level,
          ap: ap,
          rng: rng
        }
      })

      # 起手文案与结算均在目标侧完成（文案含目标兵器名）。
      assign(conn, :prompt, false)
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

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手使用。\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(weapon = target->query_temp("weapon")))
  #         return notify_fail("对方没有使用兵器，难以施展" QIN "。\n");
  # 敌人引用无武器快照，若带 meta 则照常判定，否则跳过（同 dead?/1 的保守兜底）。
  defp check_target_weapon(target) do
    case target do
      %{meta: %{combat: combat}} ->
        if Combat.weapon(combat) == nil do
          {:error, "对方没有使用兵器，难以施展#{@move_name}。\n"}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  # LPC 顺序：force < 260 → max_neili < 3000 → dragon-strike < 180 →
  #           mapped("strike") != dragon-strike → prepared("strike") != dragon-strike → neili < 400
  defp check_gates(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "force") < 260 ->
        {:error, "你内功修为不够，难以施展#{@move_name}。\n"}

      vitals.max_neili < 3000 ->
        {:error, "你内力修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dragon-strike") < 180 ->
        {:error, "你降龙十八掌火候不够，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "strike") != "dragon-strike" ->
        {:error, "你没有激发降龙十八掌，难以施展#{@move_name}。\n"}

      not prepared?(stats) ->
        {:error, "你没有准备降龙十八掌，难以施展#{@move_name}。\n"}

      vitals.neili < 400 ->
        {:error, "你现在真气不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp prepared?(stats) do
    case Stats.prepared_perform(stats, "strike") do
      nil -> false
      value -> String.split(value, "/") |> hd() == "dragon-strike"
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    case Combat.weapon(character.meta.combat) do
      nil ->
        # LPC: if (! objectp(weapon = target->query_temp("weapon"))) return notify_fail(...);
        # 攻击方门槛已拦；此处兜底（跨进程无 notify 通道，静默略过）。
        conn

      weapon ->
        weapon_name = Map.get(weapon, :name)
        # LPC: dp = target->query_skill("parry") + target->query("int") * 10;
        dp = Stats.skill(stats, "parry") + stats.int * 10

        # LPC: msg = HIR "$N" HIR "暴喝一声，全身内劲迸发，气贯右臂奋力外扯，企图将$n"
        #            HIR "的" + weapon->name() + HIR "吸入掌中。\n" NOR;
        initial =
          "$N暴喝一声，全身内劲迸发，气贯右臂奋力外扯，企图将$n的" <>
            weapon_name <> "吸入掌中。\n"

        # LPC: if (ap / 3 + random(ap) > dp) —— 夺械成功
        if div(ap, 3) + Engine.rand(rng, ap) > dp do
          # LPC: me->add("neili", -300); me->start_busy(2); weapon->move(me, 1);
          Performs.feedback(attacker, 300, 2)

          # LPC: msg += HIR "$n" HIR "只觉周围气流涌动，手中" + weapon->name()
          #            + HIR "竟然拿捏不住，向$N" HIR "掌心脱手飞去。\n" NOR;
          branch =
            "$n只觉周围气流涌动，手中" <> weapon_name <>
              "竟然拿捏不住，向$N掌心脱手飞去。\n"

          # weapon->move(me, 1)：缴械（不做跨进程物品转移，仅解除目标武器）。
          combat = Combat.unequip(character.meta.combat, :weapon)
          character = %{character | meta: %{character.meta | combat: combat}}

          conn
          |> Broadcast.publish(Messages.interpolate(initial <> branch, bindings))
          |> put_character(character)
        else
          # LPC: me->add("neili", -200); me->start_busy(3);
          Performs.feedback(attacker, 200, 3)

          # LPC: msg += CYN "$n" CYN "只觉周围气流涌动，慌忙中连将手中"
          #            + weapon->name() + CYN "挥舞得密不透风，使得$N" CYN "无从下手。\n" NOR;
          branch =
            "$n只觉周围气流涌动，慌忙中连将手中" <> weapon_name <>
              "挥舞得密不透风，使得$N无从下手。\n"

          conn
          |> Broadcast.publish(Messages.interpolate(initial <> branch, bindings))
        end
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define QIN "「" HIR "擒龙手" NOR "」"
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object weapon, target;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/dragon-strike/qin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QIN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(QIN "只能空手使用。\n");
  # 
  #         if (! objectp(weapon = target->query_temp("weapon")))
  #                 return notify_fail("对方没有使用兵器，难以施展" QIN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 260)
  #                 return notify_fail("你内功修为不够，难以施展" QIN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你内力修为不够，难以施展" QIN "。\n");
  # 
  #         if ((int)me->query_skill("dragon-strike", 1) < 180)
  #                 return notify_fail("你降龙十八掌火候不够，难以施展" QIN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "dragon-strike")
  #                 return notify_fail("你没有激发降龙十八掌，难以施展" QIN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "dragon-strike")
  #                 return notify_fail("你没有准备降龙十八掌，难以施展" QIN "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，难以施展" QIN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "暴喝一声，全身内劲迸发，气贯右臂奋力外扯，企图将$n"
  #               HIR "的" + weapon->name() + HIR "吸入掌中。\n" NOR;
  # 
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("parry") + target->query("int") * 10;
  # 
  #         if (ap / 3 + random(ap) > dp)
  #         {
  #                 me->add("neili", -300);
  #                 msg += HIR "$n" HIR "只觉周围气流涌动，手中" + weapon->name()
  #                        + HIR "竟然拿捏不住，向$N" HIR "掌心脱手飞去。\n" NOR;
  #                 me->start_busy(2);
  #                 weapon->move(me, 1);
  #         } else
  #         {
  #                 me->add("neili", -200);
  #                 msg += CYN "$n" CYN "只觉周围气流涌动，慌忙中连将手中"
  #                        + weapon->name() + CYN "挥舞得密不透风，使得$N"
  #                        CYN "无从下手。\n" NOR;
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end

defmodule Kantele.Combat.Skills.Performs.CanheZhi.You do
  @moduledoc """
  perform「幽冥剑气」（source canhe-zhi/you.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 已知此招 → 空手 →
  参合指>=200 → 激发 finger 为参合指 → 准备 finger 招式 →
  内力上限>=2500 → 真气>=500 → 目标存活。
  前置广播；攻击方忙乱 `1+random(5)` 并扣 300 真气（皆无条件）。
  随后连出 6 击（`COMBAT_D->do_attack`），每击 50% 概率在目标未忙乱时
  令其忙乱 1。

  差异（TODO(migrate)）：
  - LPC 的 6 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为
    每击独立命中判定（与 `duanjia_jian/lian.ex` 同构）。
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

  @perform_id "canhe-zhi/you"

  # LPC: #define YOU "「" MAG "幽冥剑气" NOR "」"
  @move_name "「幽冥剑气」"

  # LPC: for (i = 0; i < 6; i++) { ... COMBAT_D->do_attack(me, target, 0, 0); }
  @strikes 6

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "canhe-zhi")

    with {:ok, target} <- target(combat),
         :ok <- check_perform_known(stats),
         :ok <- check_weapon(character),
         :ok <- check_levels(stats),
         :ok <- check_mapped(stats),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          rng: rng
        }
      })

      # LPC: me->start_busy(1 + random(5)); me->add("neili", -300);
      vitals = character.meta.vitals
      vitals = %{vitals | neili: max(vitals.neili - 300, 0)}
      combat = Combat.start_busy(character.meta.combat, 1 + :rand.uniform(5))

      character = %{
        character
        | meta: character.meta |> Map.put(:vitals, vitals) |> Map.put(:combat, combat)
      }

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  #              return notify_fail(YOU "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  #         return notify_fail("你必须空手才能使用" YOU "。\n");
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "canhe-zhi") < 200 ->
        {:error, "你的参合指修为有限，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "finger") != "canhe-zhi" ->
        {:error, "你没有激发参合指，难以施展#{@move_name}。\n"}

      not prepared_canhe?(stats) ->
        {:error, "你现在没有准备使用参合指，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp prepared_canhe?(stats) do
    case Stats.prepared_perform(stats, "finger") do
      nil -> false
      value -> String.split(value, "/") |> hd() == "canhe-zhi"
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2500 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      vitals.neili < 500 ->
        {:error, "你的真气不够，难以施展#{@move_name}。\n"}

      true -> :ok
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "只见$N" HIW "身形一展，身法陡然变得诡异无比，聚力于指悄然点"
    #              "出，数股剑气直袭$n" HIW "要穴而去。\n" NOR;
    #      message_combatd(msg, me, target);
    # 连击与目标忙乱在目标侧 resolve_incoming 结算。
    conn =
      Broadcast.publish(
        conn,
        "只见$N身形一展，身法陡然变得诡异无比，聚力于指悄然点出，数股剑气直袭$n要穴而去。\n",
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
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    dodge = Stats.skill(stats, "dodge")

    # LPC: for (i = 0; i < 6; i++) { ... do_attack ... }
    {vitals, combat} =
      Enum.reduce(1..@strikes, {character.meta.vitals, character.meta.combat}, fn _,
                                                                               {v_acc, c_acc} ->
        # LPC: if (random(2) == 1 && ! target->is_busy()) target->start_busy(1);
        c_acc =
          if Engine.rand(rng, 2) == 0 and not Combat.busy?(c_acc) do
            Combat.start_busy(c_acc, 1)
          else
            c_acc
          end

        if div(level, 2) + Engine.rand(rng, level) > dodge do
          {Vitals.damage(v_acc, :qi, level + Engine.rand(rng, level)), c_acc}
        else
          {v_acc, c_acc}
        end
      end)

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "busy_lines": ["me->start_busy(1 + random(5));", "if (random(2) == 1 && ! target->is_busy())", "target->start_busy(1);"], "level_gates": [{"canhe-zhi", "200"}], "map_gates": [{"finger", "canhe-zhi"}], "prepared_gates": [{"finger", "canhe-zhi"}], "remote_damage": false, "resource_gates": [{"max_neili", "2500"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define YOU "「" MAG "幽冥剑气" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #         // int damage;
  #         string msg;
  #         // int ap, dp;
  #         int i;
  #
  #         if (! target) target = offensive_target(me);
  #
  #         if (userp(me) && ! me->query("can_perform/canhe-zhi/you"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YOU "只能对战斗中的对手使用。\n");
  #
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" YOU "。\n");
  #
  #         if ((int)me->query_skill("canhe-zhi", 1) < 200)
  #                 return notify_fail("你的参合指修为有限，难以施展" YOU "。\n");
  #
  #         if (me->query_skill_mapped("finger") != "canhe-zhi")
  #                 return notify_fail("你没有激发参合指，难以施展" YOU "。\n");
  #
  #         if (me->query_skill_prepared("finger") != "canhe-zhi")
  #                 return notify_fail("你现在没有准备使用参合指，难以施展" YOU "。\n");
  #
  #         if ((int)me->query("max_neili") < 2500)
  #                 return notify_fail("你的内力修为不足，难以施展" YOU "。\n");
  #
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，难以施展" YOU "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIW "只见$N" HIW "身形一展，身法陡然变得诡异无比，聚力于指悄然点"
  #               "出，数股剑气直袭$n" HIW "要穴而去。\n" NOR;
  #
  #         message_combatd(msg, me, target);
  #
  #         me->start_busy(1 + random(5));
  #         me->add("neili", -300);
  #
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #
  #                 if (random(2) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #
  #         return 1;
  # }
end

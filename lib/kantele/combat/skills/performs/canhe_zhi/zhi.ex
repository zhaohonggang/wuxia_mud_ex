defmodule Kantele.Combat.Skills.Performs.CanheZhi.Zhi do
  @moduledoc """
  perform「七星指穴」（source canhe-zhi/zhi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 目标未忙乱 →
  参合指>=120 → 真气>=150 → 激发 finger 为参合指 → 准备 finger 招式 → 目标存活。
  前置广播；攻击方扣 120 真气并先忙乱 1。
  ap = 基本指法，dp = 目标招架（目标侧计算）；
  命中判定 `ap*2/3 + random(ap) > dp`；
  命中：目标忙乱 `ap/20 + random(4)`；失手：攻击方忙乱 2。
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

  @perform_id "canhe-zhi/zhi"

  # LPC: #define ZHI "「" HIW "七星指穴" NOR "」"
  @move_name "「七星指穴」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    skill = Stats.skill(stats, "canhe-zhi")
    # LPC: ap = me->query_skill("finger");
    ap = Stats.skill(stats, "finger")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_not_busy(target),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: skill,
          skill: ap,
          ap: ap,
          rng: rng
        }
      })

      # LPC: me->add("neili", -120); me->start_busy(1);
      vitals = character.meta.vitals
      vitals = %{vitals | neili: max(vitals.neili - 120, 0)}
      combat = Combat.start_busy(character.meta.combat, 1)

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

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! me->is_fighting(target))
  #              return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_not_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp busy?(target) do
    case target do
      %{meta: %{combat: %{busy: busy}}} -> busy > 0
      _ -> false
    end
  end

  defp check_levels(stats) do
    # LPC: skill = me->query_skill("canhe-zhi", 1); if (skill < 120) ...
    cond do
      Stats.skill(stats, "canhe-zhi") < 120 ->
        {:error, "你的参合指修为有限，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "你的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "finger") != "canhe-zhi" ->
        {:error, "你没有激发参合指, 难以施展#{@move_name}。\n"}

      not prepared_canhe?(stats) ->
        {:error, "你现在没有准备使用参合指, 难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp prepared_canhe?(stats) do
    case Stats.prepared_perform(stats, "finger") do
      nil -> false
      value -> String.split(value, "/") |> hd() == "canhe-zhi"
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
    # LPC: msg = HIG "$N" HIG "一声冷哼，右手中两指并拢，斜斜指出，朝$n"
    #              HIG "凌空虚点七下。\n" NOR;
    #      message_combatd(msg, me, target);
    # 命中支目标忙乱与失手支攻击方忙乱 2 均在目标侧结算。
    conn =
      Broadcast.publish(
        conn,
        "$N一声冷哼，右手中食两指并拢，斜斜指出，朝$n凌空虚点七下。\n",
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
    stats = character.meta.stats
    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap * 2, 3) + Engine.rand(rng, ap) > dp do
      # LPC: 命中支 msg += "结果只听“噗噗噗”数声，$p竟被$P以指力封住穴道，动弹不得。\n";
      #      target->start_busy(ap / 20 + random(4));
      combat = Combat.start_busy(character.meta.combat, div(ap, 20) + Engine.rand(rng, 4))
      character = %{character | meta: %{character.meta | combat: combat}}

      result =
        Messages.interpolate("结果只听“噗噗噗”数声，$p竟被$P以指力封住穴道，动弹不得。\n", bindings)

      conn
      |> Broadcast.publish(result)
      |> put_character(character)
    else
      # LPC: 失手支 msg += "可是$p看破了$P的企图，轻轻一跃，躲开了这一招。\n";
      #      me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      result =
        Messages.interpolate("可是$p看破了$P的企图，轻轻一跃，躲开了这一招。\n", bindings)

      conn
      |> Broadcast.publish(result)
      |> put_character(character)
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}], "assign_refs": [{"ap", "finger"}, {"dp", "parry"}, {"skill", "canhe-zhi"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "target->start_busy(ap / 20 + random(4));", "me->start_busy(2);"], "map_gates": [{"finger", "canhe-zhi"}], "prepared_gates": [{"finger", "canhe-zhi"}], "remote_damage": false, "resource_gates": [{"neili", "150"}], "var_gates": [{"skill", "120"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define ZHI "「" HIW "七星指穴" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     string msg;
  #         int ap, dp;
  #         int skill;
  #
  #         if (userp(me) && ! me->query("can_perform/canhe-zhi/zhi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  #
  #         if (! me->is_fighting(target))
  #                 return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  #
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  #
  #         skill = me->query_skill("canhe-zhi", 1);
  #
  #         if (skill < 120)
  #                 return notify_fail("你的参合指修为有限，难以施展" ZHI "。\n");
  #
  #         if (me->query("neili") < 150)
  #                 return notify_fail("你的真气不够，难以施展" ZHI "。\n");
  #
  #         if (me->query_skill_mapped("finger") != "canhe-zhi")
  #                 return notify_fail("你没有激发参合指, 难以施展" ZHI "。\n");
  #
  #         if (me->query_skill_prepared("finger") != "canhe-zhi")
  #                 return notify_fail("你现在没有准备使用参合指, 难以施展" ZHI "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIG "$N" HIG "一声冷哼，右手中食两指并拢，斜斜指出，朝$n"
  #               HIG "凌空虚点七下。\n" NOR;
  #
  #         me->add("neili", -120);
  #         me->start_busy(1);
  #         ap = me->query_skill("finger");
  #         dp = target->query_skill("parry");
  #
  #     if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #         msg += HIR "结果只听“噗噗噗”数声，$p" HIR "竟被$P"
  #                        HIR "以指力封住穴道，动弹不得。\n" NOR;
  #         target->start_busy(ap / 20 + random(4));
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，轻轻一跃，躲开了这一招。\n" NOR;
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  #
  #     return 1;
  # }
end

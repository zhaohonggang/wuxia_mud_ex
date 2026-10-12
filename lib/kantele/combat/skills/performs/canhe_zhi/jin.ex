defmodule Kantele.Combat.Skills.Performs.CanheZhi.Jin do
  @moduledoc """
  perform「金刚剑气」（source canhe-zhi/jin.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 已知此招 → 未持兵器 →
  参合指>=160 → 准备 finger 招式 → 内力上限>=2500 → 真气>=500 → 目标存活。
  前置广播；ap = `参合指 + 基本内功`，dp = 目标 `佛学 + 基本内功`（目标侧计算）；
  攻击方先忙乱 3。
  分支 A（目标佛学>=200 且 `random(5)==1`）：-400 真气、忙乱 4，仅追加文案；
  分支 B（`ap*2/3 + random(ap) > dp`）：伤害 `ap + random(ap/2)`，
  -400 真气；`final/3` 另扣目标精气 `damage/6`、创伤 `damage/10`；
  分支 C（其余）：-200 真气、忙乱 4，仅追加文案。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "canhe-zhi/jin"

  # LPC: #define JIN "「" HIY "金刚剑气" NOR "」"
  @move_name "「金刚剑气」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "canhe-zhi")

    # LPC: ap = me->query_skill("canhe-zhi", 1) + me->query_skill("force");
    ap = Stats.skill(stats, "canhe-zhi") + Stats.skill(stats, "force")

    with {:ok, target} <- target(combat),
         :ok <- check_perform_known(stats),
         :ok <- check_weapon(character),
         :ok <- check_levels(stats),
         :ok <- check_prepared(stats),
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
          ap: ap,
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

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  #              return notify_fail(JIN "只能对战斗中的对手使用。\n");
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
  #         return notify_fail("你必须空手才能使用" JIN "。\n");
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "canhe-zhi") < 160 ->
        {:error, "你的参合指修为有限，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  # LPC: if (me->query_skill_prepared("finger") != "canhe-zhi")
  #         return notify_fail("你现在没有准备使用参合指，难以施展" JIN "。\n");
  defp check_prepared(stats) do
    if prepared_canhe?(stats) do
      :ok
    else
      {:error, "你现在没有准备使用参合指，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIY "$N" HIY "双手合十，微微一笑，颇得拈花之意。食指并中指"
    #              "轻轻一弹，顿时一屡罡气电射而出，朝$n" HIY "袭去。\n" NOR;
    #      message_combatd(msg, me, target);
    # 攻击方 me->start_busy(3) 与各分支的 neili/busy 由目标侧 Performs.feedback 回执。
    conn =
      Broadcast.publish(
        conn,
        "$N双手合十，微微一笑，颇得拈花之意。食指并中指轻轻一弹，顿时一屡罡气电射而出，朝$n袭去。\n",
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
    # LPC: dp = target->query_skill("buddhism", 1) + target->query_skill("force");
    dp = Stats.skill(stats, "buddhism") + Stats.skill(stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    cond do
      # LPC: if (target buddhism >= 200 && random(5) == 1) { -400; busy 4; }
      buddhism_high?(stats) and Engine.rand(rng, 5) == 0 ->
        Performs.feedback(attacker, 400, 4)

        result =
          Messages.interpolate(
            "但见$n也即脸露笑容，衣袖轻轻一拂，顺势裹上，顿将$N的指力消逝殆尽。\n",
            bindings
          )

        conn
        |> Broadcast.publish(result)
        |> put_character(character)

      # LPC: else if (ap * 2 / 3 + random(ap) > dp) { damage = ap + random(ap/2); -400; }
      div(ap * 2, 3) + Engine.rand(rng, ap) > dp ->
        damage = ap + Engine.rand(rng, div(ap, 2))

        # LPC final(): target->receive_damage("jing", damage / 6);
        #              target->receive_wound("jing", damage / 10);
        vitals =
          character.meta.vitals
          |> Vitals.damage(:jing, div(damage, 6))
          |> Vitals.wound(:jing, div(damage, 10))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        Performs.feedback(attacker, 400, 3)

        result =
          Messages.interpolate(
            "只听“噗嗤”一声，指力竟在$n胸前穿了一个血肉模糊的大洞，透体而入。\n",
            bindings
          )

        conn
        |> Broadcast.publish(result)
        |> put_character(character)

      true ->
        Performs.feedback(attacker, 200, 4)

        result =
          Messages.interpolate(
            "$n见$N来势汹涌，不敢轻易招架，急忙提气跃开。\n",
            bindings
          )

        conn
        |> Broadcast.publish(result)
        |> put_character(character)
    end
  end

  defp buddhism_high?(stats), do: Stats.skill(stats, "buddhism") >= 200

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "assign_refs": [{"ap", "canhe-zhi"}, {"dp", "buddhism"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);", "me->start_busy(4);"], "level_gates": [{"canhe-zhi", "160"}], "prepared_gates": [{"finger", "canhe-zhi"}], "remote_damage": true, "resource_gates": [{"max_neili", "2500"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define JIN "「" HIY "金刚剑气" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # string final(object me, object target, int damage);
  #
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #
  #         if (! target) target = offensive_target(me);
  #
  #         if (userp(me) && ! me->query("can_perform/canhe-zhi/jin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIN "只能对战斗中的对手使用。\n");
  #
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" JIN "。\n");
  #
  #         if ((int)me->query_skill("canhe-zhi", 1) < 160)
  #                 return notify_fail("你的参合指修为有限，难以施展" JIN "。\n");
  #
  #         if (me->query_skill_prepared("finger") != "canhe-zhi")
  #                 return notify_fail("你现在没有准备使用参合指，难以施展" JIN "。\n");
  #
  #         if ((int)me->query("max_neili") < 2500)
  #                 return notify_fail("你的内力修为不足，难以施展" JIN "。\n");
  #
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，难以施展" JIN "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIY "$N" HIY "双手合十，微微一笑，颇得拈花之意。食指并中指"
  #               "轻轻一弹，顿时一屡罡气电射而出，朝$n" HIY "袭去。\n" NOR;
  #
  #         ap = me->query_skill("canhe-zhi", 1) + me->query_skill("force");
  #         dp = target->query_skill("buddhism", 1) + target->query_skill("force");
  #         me->start_busy(3);
  #
  #         if ((int)target->query_skill("buddhism", 1) >= 200
  #             && random(5) == 1)
  #         {
  #                 me->add("neili", -400);
  #                 me->start_busy(4);
  #                 msg += HIY "但见$n" HIY "也即脸露笑容，衣袖轻轻一拂，顺势"
  #                        "裹上，顿将$N" HIY "的指力消逝殆尽。\n" NOR;
  #         } else
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -400);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
  #                                            (: final, me, target, damage :));
  #         } else
  #         {
  #                 me->add("neili", -200);
  #                 me->start_busy(4);
  #                 msg += CYN "$n" CYN "见$N" CYN "来势汹涌，不敢轻易"
  #                        "招架，急忙提气跃开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #
  #         return 1;
  # }
  #
  # string final(object me, object target, int damage)
  # {
  #         target->receive_damage("jing", damage / 6, me);
  #         target->receive_wound("jing", damage / 10, me);
  #         return  HIR "只听“噗嗤”一声，指力竟在$n" HIR
  #                 "胸前穿了一个血肉模糊的大洞，透体而入。\n" NOR;
  # }
end

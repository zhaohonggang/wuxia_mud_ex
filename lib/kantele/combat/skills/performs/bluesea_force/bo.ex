defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Bo do
  @moduledoc """
  perform「碧海清波」（source bluesea-force/perform/bo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 目标未忙乱 → 南海玄功>=100 → 目标存活。
  起手广播；ap = `南海玄功*3/2 + 武学修养`，
  dp = 目标 `招架 + 武学修养`（目标侧计算）。
  命中判定 `ap/2 + random(ap) > dp`；
  命中：目标忙乱 `ap/45 + 2`；失手：攻击方忙乱 1。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event

  @perform_id "bluesea-force/bo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bluesea-force")

    # LPC: ap = me->query_skill("bluesea-force", 1) * 3 / 2 +
    #            me->query_skill("martial-cognize", 1);
    ap = div(Stats.skill(stats, "bluesea-force") * 3, 2) + Stats.skill(stats, "martial-cognize")

    with {:ok, target} <- target(combat),
         :ok <- check_not_busy(target),
         :ok <- check_levels(stats),
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
  #              return notify_fail("碧海清波只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "碧海清波只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (target->is_busy())
  #              return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  defp check_not_busy(target) do
    if busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧！\n"}
    else
      :ok
    end
  end

  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "bluesea-force") < 100 ->
        {:error, "你的南海玄功不够深厚，不会使用碧海清波。\n"}

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

  defp busy?(target) do
    case target do
      %{meta: %{combat: %{busy: busy}}} -> busy > 0
      _ -> false
    end
  end

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "$N" HIC "掌力忽左忽右，形成一个个气旋，如波浪一般接连向$n"
    #              HIC "逼去！\n" NOR;
    #      message_combatd(msg, me, target);
    # 攻击方仅在失手分支忙乱 1（.c 的 else 支），由目标侧回执。
    conn =
      Broadcast.publish(
        conn,
        "$N掌力忽左忽右，形成一个个气旋，如波浪一般接连向$n逼去！\n",
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
    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    bindings = [n1: attacker.name, n2: character.name]

    {combat, result} =
      if hit do
        # LPC: 命中支 msg += HIR "结果$p" HIR "被$P" HIR "逼得施展不开半点招式！\n" NOR;
        #      target->start_busy(ap / 45 + 2);
        combat = Combat.start_busy(character.meta.combat, div(ap, 45) + 2)
        {combat, Messages.interpolate("结果$p被$P逼得施展不开半点招式！\n", bindings)}
      else
        # LPC: 失手支 msg += CYN "可是$p" CYN "看破了$P" CYN "的掌势来路，"
        #                      "镇定自若，应对自如。\n" NOR;
        #      me->start_busy(1);
        {character.meta.combat, Messages.interpolate("可是$p看破了$P的掌势来路，镇定自若，应对自如。\n", bindings)}
      end

    # LPC: 仅失手支扣除攻击方忙乱
    if not hit, do: Performs.feedback(attacker, 0, 1)

    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "bluesea-force"}, {"dp", "parry"}], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 45 + 2);", "me->start_busy(1);"], "level_gates": [{"bluesea-force", "100"}], "remote_damage": false}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // bo.c 碧海清波
  #
  # #include <ansi.h>
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  #
  #     if (! target) target = offensive_target(me);
  #
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("碧海清波只能对战斗中的对手使用。\n");
  #
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  #
  #     if ((int)me->query_skill("bluesea-force", 1) < 100)
  #         return notify_fail("你的南海玄功不够深厚，不会使用碧海清波。\n");
  #
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #     msg = HIC "$N" HIC "掌力忽左忽右，形成一个个气旋，如波浪一般接连向$n"
  #               HIC "逼去！\n" NOR;
  #
  #         ap = me->query_skill("bluesea-force", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  #
  #     if (ap / 2 + random(ap) > dp)
  #         {
  #         msg += HIR "结果$p" HIR "被$P" HIR "逼得施展不开半点招式！\n" NOR;
  #         target->start_busy(ap / 45 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的掌势来路，"
  #                        "镇定自若，应对自如。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_combatd(msg, me, target);
  #
  #     return 1;
  # }
end

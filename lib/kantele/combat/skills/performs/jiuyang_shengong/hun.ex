defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Hun do
  @moduledoc """
  perform「混沌一阳」（source jiuyang-shengong/perform/hun.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  九阳神功>=180 → 激发 unarmed 为九阳神功 → 激发 force 为九阳神功 →
  准备 unarmed 为九阳神功 → 真气>=300 → 目标存活。
  ap = 九阳神功*2 + con*10 + 武学参悟；命中判定 ap/2 + random(ap) >
  目标(force + con*10 + 武学参悟)。命中扣 200 真气/忙乱 1，50% 外伤；
  未命中忙乱 3。起手无条件扣 50 真气。
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
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "jiuyang-shengong/hun"
  @move_name "「混沌一阳」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyang-shengong")
    ap = Stats.skill(stats, "jiuyang-shengong") * 2 + Stats.query_con(stats) * 10 + Stats.skill(stats, "martial-cognize")

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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #          return notify_fail(HUN "只能空手施展。\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("jiuyang-shengong", 1) < 180)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyang-shengong") < 180 do
      {:error, "你的九阳神功还不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "jiuyang-shengong" ->
        {:error, "你现在没有激发九阳神功为拳脚，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "force") != "jiuyang-shengong" ->
        {:error, "你现在没有激发九阳神功为内功，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_prepared(character) do
    stats = character.meta.stats

    if Stats.prepared_perform(stats, "unarmed") != "jiuyang-shengong" do
      {:error, "你现在没有准备使用九阳神功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的内力不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = "$N跨前一步…向$n电射而去。\n"; me->add("neili", -50);
  defp apply_effect(conn, character, target) do
    msg = "$N跨前一步，双手回圈，颇得太极之意。掌心顿时闪出一个气团，向$n电射而去。\n"

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query("con") * 10
    #           + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "force") + Stats.query_con(stats) * 10 + Stats.skill(stats, "martial-cognize")

    if div(ap, 2) + Engine.rand(rng, ap) < dp do
      # LPC: 未命中分支
      Performs.feedback(attacker, 0, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("然而$n全力抵挡，终于将$N发出的气团拨开。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: 命中分支：damage = ap/2 + random(ap/2)，50% 外伤
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 200, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n急忙抽身后退，可是气团射得更快，只听$p一声惨叫，鲜血飞溅！\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define HUN "「" HIR "混沌一阳" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/jiuyang-shengong/hun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUN "只能空手施展。\n");
  # 
  #         if (me->query_skill("jiuyang-shengong", 1) < 180)
  #                 return notify_fail("你的九阳神功还不够娴熟，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为拳脚，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为内功，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有准备使用九阳神功，难以施展" HUN "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的内力不够，难以施展" HUN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "跨前一步，双手回圈，颇得太极之意。掌心顿时闪"
  #               "出一个气团，向$n" HIR "电射而去。\n" NOR;
  # 
  #         ap = me->query_skill("jiuyang-shengong", 1) * 2 + me->query("con") * 10 +
  #              me->query_skill("martial-cognize", 1);
  #         dp = target->query_skill("force") + target->query("con") * 10 +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         me->add("neili", -50);
  # 
  #         if (ap / 2 + random(ap) < dp)
  #         {
  #                 msg += HIY "然而$n" HIY "全力抵挡，终于将$N" HIY
  #                        "发出的气团拨开。\n" NOR;
  #             me->start_busy(3);
  #         } else
  #         {
  #                 me->add("neili", -200);
  #             me->start_busy(1);
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
  #                                            HIR "$n" HIR "急忙抽身后退，可是气团射"
  #                                            "得更快，只听$p" HIR "一声惨叫，鲜血飞"
  #                                            "溅！\n" NOR);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end

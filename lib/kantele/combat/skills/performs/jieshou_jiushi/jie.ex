defmodule Kantele.Combat.Skills.Performs.JieshouJiushi.Jie do
  @moduledoc """
  perform「截筋断脉」（source jieshou-jiushi/jie.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  截手九式>=100 → 内力上限>=800 → 真气>=200 → 激发 hand 为截手九式 →
  准备 hand 为截手九式 → 目标存活。
  命中判定 `ap/2 + random(ap)` vs 目标 `parry`（`ap = 基本手法`）：
  命中则对目标 `receive_damage/wound("jing", damage)`、
  `receive_damage/wound("qi", damage*3/2)`，另 `do_damage(damage, 10)`；
  目标忙乱 1；攻击方扣 200 真气、忙乱 3。
  未命中则攻击方扣 100 真气、忙乱 4。
  `damage = 截手九式/2 + random(截手九式/3)`（攻击方侧计算）。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - 攻击方消耗/忙乱分属命中与失手两支，经 `Performs.feedback/3` 由目标侧回传；
  - `.c` 用 `message_combatd(msg, me, target)` 把起手式与结算文案合成一条广播，
    此处按本仓库约定拆为「攻击方发起手式 / 目标侧发结算文案」两条。
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

  @perform_id "jieshou-jiushi/jie"
  @move_name "「截筋断脉」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jieshou-jiushi")
    # LPC: damage = skill / 2 + random(skill / 3);
    damage = div(lvl, 2) + Engine.rand(rng, max(div(lvl, 3), 1))
    # LPC: ap = me->query_skill("hand");
    ap = Stats.skill(stats, "hand")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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
          damage: damage,
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

  # LPC: if (userp(me) && ! me->query("can_perform/jieshou-jiushi/jie"))
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
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (skill < 100)  (skill = me->query_skill("jieshou-jiushi", 1))
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jieshou-jiushi") < 100 do
      {:error, "你的截手九式等级不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 800 ) / if (me->query("neili") < 200 )
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 800 -> {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 200 -> {:error, "你的内力不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hand") != "jieshou-jiushi")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "hand") == "jieshou-jiushi" do
      :ok
    else
      {:error, "你没有激发截手九式，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("hand") != "jieshou-jiushi")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "hand")

    if prepared == nil or prepared |> String.split("/") |> hd() != "jieshou-jiushi" do
      {:error, "你现在没有准备使用截手九式，难以施展#{@move_name}。\n"}
    else
      :ok
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
    # LPC: msg = HIR "$N" HIR "身形一展，陡然跃至$n" HIR "跟前，十指箕张，直锁$n"
    #            HIR "要穴，正是截手九式绝技「截筋断脉」。\n" NOR;
    #      命中/失手与攻击方消耗/忙乱均在目标侧结算（dp 需目标 parry）。
    conn
    |> Broadcast.publish(
      "$N身形一展，陡然跃至$n跟前，十指箕张，直锁$n要穴，正是截手九式绝技#{@move_name}。\n",
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
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage = max(Map.get(data, :damage, 0), 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: me->add("neili", -200); me->start_busy(3);
      #      target->receive_damage("jing", damage); target->receive_wound("jing", damage);
      #      target->receive_damage("qi", damage * 3 / 2);
      #      target->receive_wound("qi", damage * 3 / 2);
      #      target->start_busy(1);
      #      do_damage(me, target, REMOTE_ATTACK, damage, 10, HIR "$n" HIR "奋力格挡，…");
      qi = div(damage * 3, 2)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:jing, damage)
        |> Vitals.wound(:jing, damage)
        |> Vitals.damage(:qi, qi)
        |> Vitals.wound(:qi, qi)
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 10, 100))

      combat = Combat.start_busy(character.meta.combat, 1)
      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      Performs.feedback(attacker, 200, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n奋力格挡，可还是被$N截住腕部要穴，只觉眼前一黑，几欲晕倒。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -100); msg += CYN "$n" CYN "见状大吃一惊，急忙向后猛退数步，"
      #            "终于避开了$N" CYN "这一击。\n" NOR; me->start_busy(4);
      Performs.feedback(attacker, 100, 4)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n见状大吃一惊，急忙向后猛退数步，终于避开了$N这一击。\n",
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
  # #define JIE "「" HIR "截筋断脉" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object target;
  #         int skill, ap, dp, damage;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/jieshou-jiushi/jie"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         skill = me->query_skill("jieshou-jiushi", 1);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIE "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIE "只能空手施展。\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的截手九式等级不够，难以施展" JIE "。\n");
  # 
  #         if (me->query("max_neili") < 800 )
  #                 return notify_fail("你的内力修为不足，难以施展" JIE "。\n");
  # 
  #         if (me->query("neili") < 200 )
  #                 return notify_fail("你的内力不够，难以施展" JIE "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "jieshou-jiushi")
  #                 return notify_fail("你没有激发截手九式，难以施展" JIE "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "jieshou-jiushi")
  #                 return notify_fail("你现在没有准备使用截手九式，难以施展" JIE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "身形一展，陡然跃至$n" HIR "跟前，十指箕张，直锁$n"
  #               HIR "要穴，正是截手九式绝技「截筋断脉」。\n" NOR;
  # 
  #         damage = skill / 2 + random(skill / 3);
  # 
  #         ap = me->query_skill("hand");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -200);
  #                 me->start_busy(3);
  # 
  #                 target->receive_damage("jing", damage);
  #                 target->receive_wound("jing", damage);
  #                 target->receive_damage("qi", damage * 3 / 2);
  #                 target->receive_wound("qi", damage * 3 / 2);
  #                 target->start_busy(1);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK,
  #                        damage, 10, HIR "$n" HIR "奋力格挡，可还是被$N"
  #                                    HIR "截住腕部要穴，只觉眼前一黑，"
  #                                    "几欲晕倒。\n" NOR);
  #         }
  #         else
  #         {
  #                 me->add("neili", -100);
  #                 msg += CYN "$n" CYN "见状大吃一惊，急忙向后猛退数步，"
  #                        "终于避开了$N" CYN "这一击。\n" NOR;
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end

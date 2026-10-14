defmodule Kantele.Combat.Skills.Performs.PiliQuan.Jin do
  @moduledoc """
  perform「紫雷劲」（对照 `kungfu/skill/pili-quan/jin.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 霹雳神拳>=40 → 真气>=200 →
  准备 cuff 为霹雳神拳 → 目标存活。
  起手广播后由目标侧判定 `ap*2/3 + random(ap) > 目标招架`（`ap = 拳法`）：
  命中则 `damage = ap + random(ap/2)`、攻击方扣 120 真气并忙乱 2，目标受
  `do_damage(UNARMED_ATTACK, damage, 55)`；否则攻击方扣 80 真气并忙乱 3，
  广播「硬生生的挡开了」文案。

  差异（TODO(migrate)）：
  - 两条分支的 neili 消耗/忙乱为命中相关，故经
    `Performs.feedback(attacker, neili, busy)` 回授攻击方；
  - `COMBAT_D->do_damage(..., 55, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 55, 100))`；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "pili-quan/jin"
  @move_name "「紫雷劲」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("cuff");
    ap = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_prepared(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
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

  # LPC: if (userp(me) && ! me->query("can_perform/pili-quan/jin"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("pili-quan", 1) < 40)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "pili-quan") < 40 do
      {:error, "你的霹雳神拳不够娴熟，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "pili-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and hd(String.split(prepared, "/")) == "pili-quan" do
      :ok
    else
      {:error, "你没有准备使用霹雳神拳，无法施展#{@move_name}。\n"}
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
    # LPC: msg = HIY "$N" HIY "身形一转，运力与双拳，施出绝招「" HIW "紫雷劲" HIY "」，双拳迅猛无比"
    #            "的袭向$n" HIY "。\n" NOR;
    #      之后按分支扣 neili / start_busy / do_damage（在目标侧结算）。
    conn =
      Broadcast.publish(
        conn,
        "$N身形一转，运力与双拳，施出绝招「紫雷劲」，双拳迅猛无比的袭向$n。\n",
        n1: character.name,
        n2: target.name
      )

    put_character(conn, character)
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

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap * 2 / 3 + random(ap) > dp)
    #      { damage = ap + random(ap / 2);
    #        me->add("neili", -120);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
    #                    HIR "只见$P" HIR "这一拳把$p" HIR
    #                            "飞了出去，重重的摔在地上，吐血不止！\n" NOR);
    #        me->start_busy(2); }
    #      else
    #      { msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
    #                     HIC "这一招。\n"NOR;
    #        me->add("neili", -80);
    #        me->start_busy(3); }
    if div(ap * 2, 3) + Engine.rand(rng, ap) > dp do
      Performs.feedback(attacker, 120, 2)
      damage = ap + Engine.rand(rng, div(ap, 2))
      vitals = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 55, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn
      |> Broadcast.publish(
        "只见$P这一拳把$p飞了出去，重重的摔在地上，吐血不止！\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 80, 3)

      Broadcast.publish(
        conn,
        "可是$p奋力招架，硬生生的挡开了$P这一招。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 紫雷劲
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define PO "「" MAG "紫雷劲" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/pili-quan/jin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("pili-quan", 1) < 40)
  #         return notify_fail("你的霹雳神拳不够娴熟，无法施展" PO "。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你现在真气不够，无法施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "pili-quan")
  #                 return notify_fail("你没有准备使用霹雳神拳，无法施展" PO "。\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "身形一转，运力与双拳，施出绝招「" HIW "紫雷劲" HIY "」，双拳迅猛无比"
  #               "的袭向$n" HIY "。\n" NOR;
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("parry");
  #     if (ap * 2 / 3 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap / 2);
  # 
  #                 me->add("neili", -120);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
  #                                    HIR "只见$P" HIR "这一拳把$p" HIR
  #                                            "飞了出去，重重的摔在地上，吐血不止！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
  #                        HIC "这一招。\n"NOR;
  #         me->add("neili", -80);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end

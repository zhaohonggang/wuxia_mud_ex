defmodule Kantele.Combat.Skills.Performs.PikongZhang.Dai do
  @moduledoc """
  perform「披星戴月」（对照 `kungfu/skill/pikong-zhang/dai.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手 → 劈空掌>=80 →
  内功>=120 → 真气>=100 → 激发 strike 为劈空掌 → 准备 strike 为劈空掌 →
  目标存活。
  起手广播后由目标侧判定 `random(掌法) > 目标闪避/2`：命中则攻击方忙乱 2、
  扣 50 真气，`damage = 掌法/2 + random(掌法/2)`，目标受
  `do_damage(UNARMED_ATTACK, damage, 20)`；否则攻击方忙乱 3、扣 30 真气，
  广播「斜斜一跃避开」文案。

  差异（TODO(migrate)）：
  - 两条分支的 neili 消耗/忙乱为命中相关，故经
    `Performs.feedback(attacker, neili, busy)` 回授攻击方；
  - `COMBAT_D->do_damage(..., 20, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 20, 100))`；
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
  alias Kantele.Combat.Performs

  @perform_id "pikong-zhang/dai"
  @move_name "「披星戴月」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: random(me->query_skill("strike")) —— 分支判定用掌法等级。
    ap = Stats.skill(stats, "strike")

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

  # LPC: if (userp(me) && ! me->query("can_perform/pikong-zhang/dai"))
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

  # LPC: if (objectp(weapon = me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "#{@move_name}只能空手施展。\n"}
    end
  end

  # LPC: if (me->query_skill("pikong-zhang", 1) < 80)
  #      if (me->query_skill("force", 1) < 120)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "pikong-zhang") < 80 ->
        {:error, "你劈空掌不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "pikong-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "pikong-zhang" do
      :ok
    else
      {:error, "你没有激发劈空掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "pikong-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared != nil and hd(String.split(prepared, "/")) == "pikong-zhang" do
      :ok
    else
      {:error, "你没有准备劈空掌，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIB "只见$N" HIB "双掌交叠，云贯而出，舞出无数圈劲气，一环环"
    #            "向$n" HIB "斫去。\n" NOR;
    #      之后按分支扣 neili / start_busy / do_damage（在目标侧结算）。
    conn =
      Broadcast.publish(
        conn,
        "只见$N双掌交叠，云贯而出，舞出无数圈劲气，一环环向$n斫去。\n",
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

    # LPC: target->query_skill("dodge") / 2
    dodge = Stats.skill(character.meta.stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
    #      { me->start_busy(2);  damage = strike;  damage = damage/2 + random(damage/2);
    #        me->add("neili", -50);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
    #                    HIR "$n" HIR "一惊，被$N" HIR "掌劲击"
    #                    "在胸前，经脉受震，登时呕出一口鲜血！\n" NOR); }
    #      else
    #      { me->start_busy(3);  me->add("neili", -30);
    #        msg += CYN "可是$p" CYN "识破了$P"
    #               CYN "这一招，斜斜一跃避开。\n" NOR; }
    if Engine.rand(rng, ap) > div(dodge, 2) do
      Performs.feedback(attacker, 50, 2)
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))
      vitals = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 20, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn
      |> Broadcast.publish(
        "$n一惊，被$N掌劲击在胸前，经脉受震，登时呕出一口鲜血！\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 30, 3)

      Broadcast.publish(
        conn,
        "可是$p识破了$P这一招，斜斜一跃避开。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DAI "「" HIB "披星戴月" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/pikong-zhang/dai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DAI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail(DAI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("pikong-zhang", 1) < 80)
  #                 return notify_fail("你劈空掌不够娴熟，难以施展" DAI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120)
  #                 return notify_fail("你的内功修为不够，难以施展" DAI "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不够，难以施展" DAI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "pikong-zhang") 
  #                 return notify_fail("你没有激发劈空掌，难以施展" DAI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "pikong-zhang")
  #                 return notify_fail("你没有准备劈空掌，难以施展" DAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIB "只见$N" HIB "双掌交叠，云贯而出，舞出无数圈劲气，一环环"
  #               "向$n" HIB "斫去。\n" NOR;
  # 
  #         if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("strike");
  #                 damage = damage / 2 + random(damage / 2);
  #                 me->add("neili", -50);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "$n" HIR "一惊，被$N" HIR "掌劲击"
  #                                            "在胸前，经脉受震，登时呕出一口鲜血！\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -30);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

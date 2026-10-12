defmodule Kantele.Combat.Skills.Performs.HeishaZhang.Cui do
  @moduledoc """
  perform「催魂掌」（source heisha-zhang/cui.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 空手 → 激发黑砂掌(strike) →
  准备黑砂掌(strike) → 黑砂掌>=100 → 内功>=150 → 真气>=200 → 目标存活。
  攻击方恒忙乱 3。命中判定 `ap/2 + random(ap)` vs 目标 `force`（`ap = strike`）：
  命中则伤害 `ap/2 + random(ap/3)`（qi 伤 + 20% 外伤）、附加 sha_poison
  （`level = jiali + random(jiali)`，`duration = lvl/50 + random(lvl/20)`），
  攻击方扣 100 真气；未命中不扣真气。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->affect_by("sha_poison", …)` 折算为 `ConditionEvent.apply_poison/2`
    （`.c` 未给毒名，此处补 `"name" => "砂毒"`，取自 `kungfu/condition/sha_poison.c`
    的 `chinese_name()`，仅供显示）；
  - `me->query("jiali")` 取 `combat.jiali`，经事件数据传给目标侧（同 `cuixin-zhang/cui`）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "heisha-zhang/cui"
  @move_name "「催魂掌」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "heisha-zhang")
    ap = Stats.skill(stats, "strike")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_levels(character),
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
          jiali: combat.jiali,
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

  # LPC: if (userp(me) && ! me->query("can_perform/heisha-zhang/cui"))
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

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "heisha-zhang")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") != "heisha-zhang" do
      {:error, "你没有激发黑砂掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "heisha-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared == nil or prepared |> String.split("/") |> hd() != "heisha-zhang" do
      {:error, "你现在没有准备使用黑砂掌，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("heisha-zhang", 1) < 100) / if ((int)me->query_skill("force") < 150)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "heisha-zhang") < 100 ->
        {:error, "你的黑砂掌不够熟练，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIB "$N" HIB "冷笑数声，单掌陡然一振，催魂般悄然拍至$n"
    #           HIB "前胸，不着半点力道。\n" NOR;
    #      me->start_busy(3);（无条件；命中/失手的资源消耗在目标侧结算）
    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(
      "$N冷笑数声，单掌陡然一振，催魂般悄然拍至$n前胸，不着半点力道。\n",
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
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    lvl = Map.get(data, :level, 0)
    jiali = Map.get(data, :jiali, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force");
    dp = Stats.skill(stats, "force")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: target->affect_by("sha_poison",
      #          ([ "level" : me->query("jiali") + random(me->query("jiali")),
      #             "id"    : me->query("id"),
      #             "duration" : lvl / 50 + random(lvl / 20) ]));
      poison_level = jiali + Engine.rand(rng, max(jiali, 1))
      poison_duration = div(lvl, 50) + Engine.rand(rng, max(div(lvl, 20), 1))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "砂毒"
        })

      # LPC: damage = ap / 2 + random(ap / 3);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                 HIR "$n" HIR "只觉$N" HIR "掌劲穿"
      #                                 "胸而过，一时说不出的难受，呕出一大口黑血。\n" NOR);
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 20, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -100);
      Performs.feedback(attacker, 100, 0)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n只觉$N掌劲穿胸而过，一时说不出的难受，呕出一大口黑血。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "$n" CYN "见$N" CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR;
      conn
      |> Broadcast.publish(
        Messages.interpolate("$n见$N来势汹涌，奋力格挡，终于化解开来。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define CUI "「" HIB "催魂掌" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         int lvl;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/heisha-zhang/cui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CUI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" CUI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "heisha-zhang")
  #                 return notify_fail("你没有激发黑砂掌，难以施展" CUI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "heisha-zhang")
  #                 return notify_fail("你现在没有准备使用黑砂掌，难以施展" CUI "。\n");
  # 
  #         if ((int)me->query_skill("heisha-zhang", 1) < 100)
  #                 return notify_fail("你的黑砂掌不够熟练，难以施展" CUI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内力修为不足，难以施展" CUI "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" CUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIB "$N" HIB "冷笑数声，单掌陡然一振，催魂般悄然拍至$n"
  #               HIB "前胸，不着半点力道。\n" NOR;  
  # 
  #         lvl = me->query_skill("heisha-zhang", 1);
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("force");
  # 
  #         me->start_busy(3);
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap / 2 + random(ap / 3);
  #                 me->add("neili", -100);
  #                 target->affect_by("sha_poison",
  #                                ([ "level" : me->query("jiali") + random(me->query("jiali")),
  #                                   "id"    : me->query("id"),
  #                                   "duration" : lvl / 50 + random(lvl / 20) ]));
  #                                   msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
  #                                          damage, 20, HIR "$n" HIR "只觉$N" HIR "掌劲穿"
  #                                          "胸而过，一时说不出的难受，呕出一大口黑血。\n"
  #                                          NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N"
  #                        CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

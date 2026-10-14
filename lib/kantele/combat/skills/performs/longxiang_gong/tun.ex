defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Tun do
  @moduledoc """
  perform「龙吞势」（source longxiang-gong/perform/tun.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 → 未在「龙吞势」冷却中 →
  龙象般若功>=180 → 内力上限>=3000 → 激发 unarmed 为龙象般若功 →
  激发 force 为龙象般若功 → 准备 unarmed 为龙象般若功 → 真气>=500 → 目标存活。
  施展后置 50 秒冷却（`long_tun`）；`ap = 基本拳脚 + 内功`，目标
  `dp = 招架 + 内功`。
  - `ap/2 + random(ap) > dp`：伤害 `ap/2 + random(ap) + random(目标内功)`（外伤 80%），
    攻击方扣 300 真气、忙乱 3；
  - 否则：攻击方扣 200 真气、忙乱 4。

  差异（TODO(migrate)）：
  - 起手文案与命中结算依赖目标属性，故结算（含起手广播）在目标侧
    `resolve_incoming/4` 完成；攻击方的内力/忙乱经 `combat/perform-feedback` 回执；
  - `COMBAT_D->do_damage(..., UNARMED_ATTACK, damage, 80, …)` 折算为
    `Vitals.damage(:qi, damage)` + `Vitals.wound(:qi, damage*80/100)`；
  - `.c` 的 `set_temp("long_tun", 1)` + `start_call_out(remove_effect, 50)`
    折合 `Combat.Buff{key: "long_tun"}` + 50 秒后自投递 `combat/buff-expire`
    （同 huntian-qigong/shield）；
  - `living(target)` 门槛由目标侧死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "longxiang-gong/tun"
  @move_name "「龙吞势」"
  @key "long_tun"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longxiang-gong")
    # LPC: ap = me->query_skill("unarmed") + me->query_skill("force");
    ap = Stats.skill(stats, "unarmed") + Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_cooldown(character),
         :ok <- check_levels(character),
         :ok <- check_max_neili(character),
         :ok <- check_mapped(character),
         :ok <- check_mapped_force(character),
         :ok <- check_prepared(character),
         :ok <- check_neili(character),
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

      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/longxiang-gong/tun"))
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

  # LPC: if (me->query_temp("long_tun")) return notify_fail(TUN "无法连续施展。\n");
  defp check_cooldown(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "#{@move_name}无法连续施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("longxiang-gong", 1) < 180)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "longxiang-gong") < 180 do
      {:error, "你的龙象般若功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("max_neili") < 3000)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 3000 do
      {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "unarmed") != "longxiang-gong" do
      {:error, "你没有激发龙象般若功为拳脚，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("force") != "longxiang-gong")
  defp check_mapped_force(character) do
    if Stats.mapped(character.meta.stats, "force") != "longxiang-gong" do
      {:error, "你没有激发龙象般若功为内功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "unarmed")

    if prepared == nil or prepared |> String.split("/") |> hd() != "longxiang-gong" do
      {:error, "你没有准备使用龙象般若功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 500)
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
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

  # LPC: me->set_temp("long_tun", 1);
  #      me->start_call_out((: call_other, __FILE__, "remove_effect", me :), 50);
  defp apply_effect(conn, character) do
    buff = %Buff{key: @key, applies: %{}}
    combat = Combat.add_buff(character.meta.combat, buff)
    character = %{character | meta: %{character.meta | combat: combat}}

    schedule_expire(buff, 50)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # 到期自投递（同 huntian-qigong/shield 的写法）。
  defp schedule_expire(buff, seconds) do
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: buff.key, applies: buff.applies, message: expire_message()}
      },
      max(seconds, 1) * 1000
    )
  end

  # LPC remove_effect：tell_object(me, "你经过调气养息，又可以继续施展" TUN "了。\n");
  @doc false
  def expire_message, do: "你经过调气养息，又可以继续施展「龙吞势」了。\n"

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

    # LPC: msg = HIY "$N" HIY "双臂左右分张，形若龙嘴，所施正是龙象般若功绝学「"
    #            HIR "龙吞势" HIY "」。霎时呼\n啸声大作，但见一股澎湃无比的罡劲"
    #            "至$N" HIY "双掌间涌出，云贯向$n" HIY "而去。\n" NOR;
    opening =
      "$N双臂左右分张，形若龙嘴，所施正是龙象般若功绝学「龙吞势」。霎时呼\n啸声大作，但见一股澎湃无比的罡劲至$N双掌间涌出，云贯向$n而去。\n"

    # LPC: dp = target->query_skill("parry") + target->query_skill("force");
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "force")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: foc = target->query_skill("force");
      #      damage = ap / 2 + random(ap) + random(foc);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80, …);
      #      me->start_busy(3); me->add("neili", -300);
      foc = Stats.skill(stats, "force")
      damage = div(ap, 2) + Engine.rand(rng, ap) + Engine.rand(rng, foc)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 80, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 300, 3)

      conn
      |> Broadcast.publish(
        opening <> "$n一声哀嚎，被$N的罡气划中气门，真气在体内四处乱窜，惨不堪言。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(4); me->add("neili", -200);
      #      msg += CYN "可是$n" CYN "见$N" CYN "此招来势非凡，急忙向后横移数尺，终于躲避开来。\n" NOR;
      Performs.feedback(attacker, 200, 4)

      conn
      |> Broadcast.publish(
        opening <> "可是$n见$N此招来势非凡，急忙向后横移数尺，终于躲避开来。\n",
        bindings
      )
      |> put_character(character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TUN "「" HIR "龙吞势" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me);
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int ap, dp, foc, damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/longxiang-gong/tun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TUN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(TUN "只能空手施展。\n");
  # 
  #         if (me->query_temp("long_tun"))
  #                 return notify_fail(TUN "无法连续施展。\n");
  # 
  #         if ((int)me->query_skill("longxiang-gong", 1) < 180)
  #                 return notify_fail("你的龙象般若功修为不够，难以施展" TUN "。\n");
  # 
  #         if (me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，难以施展" TUN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为拳脚，难以施展" TUN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功为内功，难以施展" TUN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "longxiang-gong")
  #                 return notify_fail("你没有准备使用龙象般若功，难以施展" TUN "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" TUN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "双臂左右分张，形若龙嘴，所施正是龙象般若功绝学「"
  #               HIR "龙吞势" HIY "」。霎时呼\n啸声大作，但见一股澎湃无比的罡劲"
  #               "至$N" HIY "双掌间涌出，云贯向$n" HIY "而去。\n" NOR;
  # 
  #         me->set_temp("long_tun", 1);
  #         me->start_call_out((: call_other, __FILE__, "remove_effect", me :), 50);
  # 
  #         ap = me->query_skill("unarmed") +
  #              me->query_skill("force");
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 foc = target->query_skill("force");
  #                 damage = ap / 2 + random(ap) + random(foc);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                                HIR "$n" HIR "一声哀嚎，被$N" HIR "的罡"
  #                                                "气划中气门，真气在体内四处乱窜，惨不堪"
  #                                                "言。\n" NOR);
  # 
  #                 me->start_busy(3);
  #                 me->add("neili", -300);
  #         } else
  #         {
  #                 me->start_busy(4);
  #                 me->add("neili", -200);
  #                 msg += CYN "可是$n" CYN "见$N" CYN "此招来势非凡，急"
  #                        "忙向后横移数尺，终于躲避开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me)
  # {
  #         if (me->query_temp("long_tun"))
  #         {
  #                 me->delete_temp("long_tun");
  #                 tell_object(me, "你经过调气养息，又可以继续施展" TUN "了。\n");
  #         }
  # }
end

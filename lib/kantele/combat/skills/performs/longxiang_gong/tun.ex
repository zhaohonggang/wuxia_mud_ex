defmodule Kantele.Combat.Skills.Performs.LongxiangGong.Tun do
  @moduledoc """
  perform「龙吞势」（source longxiang-gong/tun.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "longxiang-gong/tun"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "longxiang-gong")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "longxiang-gong") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "longxiang-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "longxiang-gong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 4)
    result = Messages.interpolate("$N双臂左右分张，形若龙嘴，所施正是龙象般若功绝学「龙吞势」。霎时呼
啸声大作，但见一股澎湃无比的罡劲至$N双掌间涌出，云贯向$n而去。
$n一声哀嚎，被$N的罡气划中气门，真气在体内四处乱窜，惨不堪言。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"foc", "force"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"longxiang-gong", "180"}], "map_gates": [{"force", "longxiang-gong"}, {"unarmed", "longxiang-gong"}], "prepared_gates": [{"unarmed", "longxiang-gong"}], "remote_damage": true, "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "temp_set": ["long_tun"]}

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

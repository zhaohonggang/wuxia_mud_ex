defmodule Kantele.Combat.Skills.Performs.CanheZhi.Jin do
  @moduledoc """
  perform「金刚剑气」（source canhe-zhi/jin.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "canhe-zhi/jin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "canhe-zhi")
    ap = (Stats.skill(stats, "canhe-zhi") + Stats.skill(stats, "force"))
    damage = (ap + Engine.rand(rng, div(ap, 2)))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "canhe-zhi") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 400}
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
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :jing, div(damage, 6))
          vitals = Vitals.wound(vitals, :jing, div(damage, 10))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 400, 4)
    result = if hit, do: Messages.interpolate("", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

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

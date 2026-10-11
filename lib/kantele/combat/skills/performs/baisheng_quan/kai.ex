defmodule Kantele.Combat.Skills.Performs.BaishengQuan.Kai do
  @moduledoc """
  perform「混沌初开」（source baisheng-quan/kai.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "baisheng-quan/kai"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baisheng-quan")
    damage = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "baisheng-quan") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 140 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "cuff") != "baisheng-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 60}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
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
    Performs.feedback(attacker, 60, 3)
    result = Messages.interpolate("$N身子蓦的横移，两臂向后反钩，呼的一声朝$n攻去，正是「混沌初开」绝技。
结果$n闪避不及，$N双拳正中$p头部两侧，顿时口喷鲜血，几欲昏厥。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-60"}], "assign_refs": [{"damage", "cuff"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"baisheng-quan", "100"}, {"force", "140"}], "map_gates": [{"cuff", "baisheng-quan"}], "prepared_gates": [{"cuff", "baisheng-quan"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KAI "「" WHT "混沌初开" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/baisheng-quan/kai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("只有空手才能施展" KAI "。\n");
  # 
  #         if ((int)me->query_skill("baisheng-quan", 1) < 100)
  #                 return notify_fail("你的百胜神拳不够娴熟，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 140)
  #                 return notify_fail("你的内功修为不够，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "baisheng-quan") 
  #                 return notify_fail("你没有激发百胜神拳，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "baisheng-quan")
  #                 return notify_fail("你没有准备百胜神拳，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" KAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = WHT "$N" WHT "身子蓦的横移，两臂向后反钩，呼的一声朝$n"
  #               WHT "攻去，正是「" NOR + HIR "混沌初开" NOR + WHT "」绝"
  #               "技。\n" NOR;
  # 
  #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("cuff");
  #                 damage = damage / 2 + random(damage * 2 / 3);
  #                 me->add("neili", -100);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
  #                                            HIR "结果$n" HIR "闪避不及，$N" HIR "双"
  #                                            "拳正中$p" HIR "头部两侧，顿时口喷鲜血"
  #                                            "，几欲昏厥。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -60);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

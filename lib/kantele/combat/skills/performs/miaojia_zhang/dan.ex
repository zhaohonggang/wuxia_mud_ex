defmodule Kantele.Combat.Skills.Performs.MiaojiaZhang.Dan do
  @moduledoc """
  perform「丹阳劲」（source miaojia-zhang/dan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "miaojia-zhang/dan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "miaojia-zhang")

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
      Stats.skill(stats, "miaojia-zhang") < 40 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "miaojia-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 50 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 30}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
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
    Performs.feedback(attacker, 30, 3)
    result = Messages.interpolate("$n见势连忙向后一纵，但却只觉胸口一震，顿时两耳轰鸣，已被$N掌劲所伤！
:内伤@?", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-30"}], "assign_refs": [{"damage", "force"}], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(3);"], "level_gates": [{"miaojia-zhang", "40"}], "map_gates": [{"strike", "miaojia-zhang"}], "prepared_gates": [{"strike", "miaojia-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "200"}, {"neili", "50"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DAN "「" HIM "丹阳劲" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/miaojia-zhang/dan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DAN "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" DAN "。\n");         
  #                 
  #         if ((int)me->query_skill("miaojia-zhang", 1) < 40)
  #                 return notify_fail("你的苗家掌法不够娴熟，难以施展" DAN "。\n");
  # 
  #         if (me->query("max_neili") < 200)
  #                 return notify_fail("你的内功修为不足，难以施展" DAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "miaojia-zhang")
  #                 return notify_fail("你没有激发苗家掌法，难以施展" DAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "miaojia-zhang")
  #                 return notify_fail("你没有准备苗家掌法，难以施展" DAN "。\n");
  # 
  #         if (me->query("neili") < 50)
  #                 return notify_fail("你现在真气太弱，难以施展" DAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "$N" HIM "凝聚内力，深深吸入一口气，掌劲吞吐，对准$n"
  #               HIM "平平拍出。\n" NOR;
  #         me->add("neili", -30);
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 me->start_busy(3);
  #                 target->start_busy(random(3));
  #                 
  #                 damage = (int)me->query_skill("force", 1);
  #                 damage = damage / 3 + random(damage / 3);
  #                 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "见势连忙向后一纵，但却只觉"
  #                                            "胸口一震，顿时两耳轰鸣，已被$N" HIR "掌"
  #                                            "劲所伤！\n:内伤@?");
  #         } else 
  #         {
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，并没有上当。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end

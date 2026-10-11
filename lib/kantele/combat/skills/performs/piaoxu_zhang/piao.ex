defmodule Kantele.Combat.Skills.Performs.PiaoxuZhang.Piao do
  @moduledoc """
  perform「飞絮飘零」（source piaoxu-zhang/piao.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "piaoxu-zhang/piao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "piaoxu-zhang")
    count = 0
    i = 0

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
      Stats.skill(stats, "piaoxu-zhang") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "piaoxu-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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
    Performs.feedback(attacker, 50, 1)
    result = Messages.interpolate("$n顿时觉得眼花缭乱，全然分辨不清真伪，只得拼命运动抵挡。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "apply_adds": ["attack"], "assign_refs": [{"lvl", "piaoxu-zhang"}], "busy_lines": ["me->start_busy(random(3));"], "level_gates": [{"piaoxu-zhang", "80"}], "map_gates": [{"strike", "piaoxu-zhang"}], "prepared_gates": [{"strike", "piaoxu-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "3"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PIAO "「" HIW "飞絮飘零" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/piaoxu-zhang/piao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PIAO "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(PIAO "只能空手施展。\n");
  # 
  #         if ((lvl = (int)me->query_skill("piaoxu-zhang", 1)) < 80)
  #                 return notify_fail("你飘絮掌法不够娴熟，难以施展" PIAO "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "piaoxu-zhang")
  #                 return notify_fail("你没有激发飘絮掌法，难以施展" PIAO "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "piaoxu-zhang")
  #                 return notify_fail("你没有准备飘絮掌法，难以施展" PIAO "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不足，难以施展" PIAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "微微一笑，单掌施出飘絮掌法绝技「飞絮飘零」，顿时掌"
  #               "影重重，虚实难辨，全全笼罩$n" HIW "而去。\n" NOR;
  #         me->add("neili", -50);
  # 
  #         if (random(me->query_skill("force") + me->query_skill("strike")) >
  #             target->query_skill("force"))
  #         {
  #                 msg += HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
  #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝"
  #                        "毫不受掌影的干扰，。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < 3; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->start_busy(random(3));
  #         me->add_temp("apply/attack", -count);
  #         return 1;
  # }
end

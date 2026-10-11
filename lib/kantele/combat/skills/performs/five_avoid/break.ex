defmodule Kantele.Combat.Skills.Performs.FiveAvoid.Break do
  @moduledoc """
  perform「break」（source five-avoid/break.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "five-avoid/break"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "five-avoid")
    count = 5

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 20 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.qi < 20 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.qi < 70 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 10}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 10, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-10"}], "assign_refs": [{"count", "five-avoid"}], "busy_lines": ["me->start_busy(1);"], "level_gates": [{"force", "200"}], "remote_damage": false, "resource_gates": [{"neili", "20"}, {"qi", "20"}, {"qi", "70"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // break.c 五遁绝杀
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「五遁绝杀」只能在战斗中使用。\n");
  # 
  #         if ((int)me->query("qi") < 70)
  #                 return notify_fail("你的气不够，无法施展「五遁绝杀」！\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不够，难以施展「五遁绝杀」！\n");
  # 
  #         if ((int)me->query("neili") < (int)me->query("max_neili") / 2)
  #                 return notify_fail("你的真气不够，无法施展「五遁绝杀」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "使出五行遁中的「五遁绝杀」，身法"
  #               "陡然间变得变幻莫测！\n" NOR;
  # 
  #         message_combatd(msg, me);
  #         count = (int)me->query_skill("five-avoid") / 30 + 2;
  #         if (count > 5 ) count = 5;
  # 
  #         while (count--)
  #         {
  #                 if (! target || (environment(target) != environment(me)) ||
  #                     ! me->is_fighting(target) ||
  #                     me->query("qi") < 20 ||
  #                     me->query("neili") < 20)
  #                 {
  #                         message_combatd(WHT "$N" WHT "的身形倏地一"
  #                                         "转，收身停住了脚步。\n" NOR, me);
  #                         break;
  #                 } else
  # 
  #                 message_combatd(WHT "$N" WHT "的身影在$n"
  #                                 WHT "身旁时隐时现 ...\n" NOR, me, target);
  #                 if (! COMBAT_D->fight(me, target))
  #                         message_combatd(WHT "但是$N" WHT "始终没有找到机会出手！\n" NOR, me);
  #                 me->receive_damage("qi", 10);
  #                 me->add("neili", -10);
  #         }
  # 
  #         me->start_busy(1);
  #         return 1;
  # }
end

defmodule Kantele.Combat.Skills.Performs.Shenzhaojing.Wu do
  @moduledoc """
  perform「无影拳舞」（source shenzhaojing/wu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "shenzhaojing/wu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shenzhaojing")
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
      Stats.skill(stats, "shenzhaojing") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "unarmed") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "shenzhaojing" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
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
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("$N一声暴喝，将神照功功力聚之于拳，携着雷霆万钧之势向$n连环攻出。
$n面对$N这排山倒海的攻势，不禁心生惧意，慌乱中破绽迭出。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "force"}, {"dp", "dodge"}], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"shenzhaojing", "200"}, {"unarmed", "200"}], "map_gates": [{"unarmed", "shenzhaojing"}], "prepared_gates": [{"unarmed", "shenzhaojing"}], "remote_damage": false, "resource_gates": [{"max_neili", "5000"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define WU "「" HIR "无影拳舞" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         //if (userp(me) && ! me->query("can_perform/shenzhaojing/wu"))
  #          //       return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(WU "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能施展" WU "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "shenzhaojing")
  #                 return notify_fail("你没有激发神照经神功为拳脚，无法施展" WU "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "shenzhaojing")
  #                 return notify_fail("你现在没有准备使用神照经神功，无法施展" WU "。\n");
  # 
  #         if ((int)me->query_skill("shenzhaojing", 1) < 200)
  #                 return notify_fail("你的神照经神功火候不够，无法施展" WU "。\n");
  # 
  #         if ((int)me->query_skill("unarmed", 1) < 200)
  #                 return notify_fail("你的基本拳脚火候不够，无法施展" WU "。\n");
  # 
  #         if ((int)me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，无法施展" WU "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法施展" WU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "一声暴喝，将神照功功力聚之于拳，携着雷霆万"
  #               "钧之势向$n"HIR"连环攻出。\n"NOR;
  # 
  #         ap = me->query_skill("force") + me->query("con") * 10;
  #         dp = target->query_skill("dodge") + target->query("dex") * 10;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 10;
  #                 msg += HIR "$n" HIR "面对$N" HIR "这排山倒海的攻"
  #                        "势，不禁心生惧意，慌乱中破绽迭出。\n" NOR;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "微一凝神，面对$N" HIC "这排"
  #                        "山倒海的攻势却丝毫不乱，小心招架。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -200);
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 0 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end

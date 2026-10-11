defmodule Kantele.Combat.Skills.Performs.TieZhang.Juesha do
  @moduledoc """
  perform「juesha」（source tie-zhang/juesha.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tie-zhang/juesha"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tie-zhang")
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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tie-zhang") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "tianlei-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "strike") != "tie-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    vitals = %{vitals | qi: vitals.qi - 100}
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
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("$N一声怒喝，猛然施出铁掌掌法绝技「九穹绝刹掌」！体内天雷真气急速运转，双臂陡然
暴长数尺。只听破空之声骤响，双掌幻出漫天掌影，铺天盖地向$n连环拍出！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}, {"qi", "-100"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "busy_lines": ["if (random(5) < 2 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"force", "300"}, {"tie-zhang", "200"}], "map_gates": [{"force", "tianlei-shengong"}, {"strike", "tie-zhang"}], "prepared_gates": [{"strike", "tie-zhang"}], "remote_damage": false, "resource_gates": [{"max_neili", "2200"}, {"neili", "500"}], "var_gates": [{"i", "6"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
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
  #         if (userp(me) && ! me->query("can_perform/tie-zhang/juesha"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「九穹绝刹掌」只能在战斗中对对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail("「九穹绝刹掌」只能空手使用。\n");
  #                 
  #         if (me->query("max_neili") < 2200)
  #                 return notify_fail("你的内力修为还不够，无法施展「九穹绝刹掌」。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #         if ((int)me->query_skill("tie-zhang", 1) < 200)
  #                 return notify_fail("你的铁掌火候不够，无法使用「九穹绝刹掌」！\n");
  # 
  #         if ((int)me->query_skill("force") < 300)
  #                 return notify_fail("你的内功修为不够，无法使用「九穹绝刹掌」！\n");
  # 
  #         if (me->query_skill_mapped("strike") != "tie-zhang")
  #                 return notify_fail("你没有激发铁掌掌法，难以施展「九穹绝刹掌」。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "tie-zhang")
  #                 return notify_fail("你现在没有准备使用铁掌掌法，难以施展「九穹绝刹掌」。\n");
  # 
  #         if (me->query_skill_prepared("cuff") == "tiexian-quan"
  #             || me->query_skill_prepared("unarmed") == "tiexian-quan" )
  #                 return notify_fail("施展「九穹绝刹掌」时铁掌掌法不宜和铁线拳互背！\n");
  # 
  #         if ((string)me->query_skill_mapped("force") != "tianlei-shengong")
  #                 return notify_fail("你必须激发天雷神功才能施展出「九穹绝刹掌」！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "一声怒喝，猛然施出铁掌掌法绝技「" NOR + WHT 
  #               "九穹绝刹掌" NOR + HIR "」！体内天雷真气急速运转，双臂陡"
  #               "然\n暴长数尺。只听破空之声骤响，双掌幻出漫天掌影，铺天"
  #               "盖地向$n" HIR "连环拍出！\n\n" NOR;
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("parry") + target->query("dex") * 6;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 9;
  #                 msg += RED "$n" RED "面对$P" RED "这排山倒海攻势，完全"
  #                        "无法抵挡，唯有退后。\n" NOR;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "凝神应战，竭尽所能化解$P" HIC "这"
  #                        "几掌。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_vision(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  #         me->add("qi", -100);    // Why I don't use receive_damage ?
  #                                 // Becuase now I was use it as a cost
  #         for (i = 0; i < 6; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
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

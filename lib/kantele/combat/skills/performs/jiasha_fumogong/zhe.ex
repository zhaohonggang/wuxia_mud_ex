defmodule Kantele.Combat.Skills.Performs.JiashaFumogong.Zhe do
  @moduledoc """
  perform「避云遮日」（source jiasha-fumogong/zhe.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jiasha-fumogong/zhe"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiasha-fumogong")
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
      Stats.skill(stats, "jiasha-fumogong") < 140 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "jiasha-fumogong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    vitals = %{vitals | neili: vitals.neili - 500}
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
    Performs.feedback(attacker, 500, 3)
    result = Messages.interpolate("$N大喝一声，施出绝招「避云遮日」，顿时真气迸发，衣衫鼓动，双手猛然如闪电般地拍向$n。
$n全身一颤，立足不稳，被$N这招击得飞起，重重的跌落在地上。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}, {"neili", "-500"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(3);", "//  if (random(5) < 2 && ! target->is_busy())", "//         target->start_busy(1);", "me->start_busy(1 + random(5));"], "level_gates": [{"jiasha-fumogong", "140"}], "map_gates": [{"unarmed", "jiasha-fumogong"}], "prepared_gates": [{"unarmed", "jiasha-fumogong"}], "remote_damage": false, "resource_gates": [{"max_neili", "2000"}, {"neili", "400"}], "set_flags": [{"eff_jing", "0"}, {"eff_qi", "0"}], "var_gates": [{"i", "9"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JIU "「" HIR "避云遮日" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/jiasha-fumogong/zhe"))
  #                return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIU "只能对战斗中的对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIU "只能空手施展。\n");
  #                 
  #         if (me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力的修为不够，现在无法使用" JIU "。\n");
  # 
  #         if (me->query_skill("jiasha-fumogong", 1) < 140)
  #                 return notify_fail("你的袈裟伏魔功还不够娴熟，难以施展" JIU "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "jiasha-fumogong")
  #                 return notify_fail("你现在没有激发袈裟伏魔功为拳脚，难以施展" JIU "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "jiasha-fumogong")
  #                 return notify_fail("你现在没有准备使用袈裟伏魔功，难以施展" JIU "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，无法运用" JIU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "大喝一声，施出绝招「" HIR "避云遮日" HIG "」，顿时真气迸发，衣衫鼓动，双手"
  #               "猛然如闪电般地拍向$n" HIG "。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query("con") * 20;
  #         dp = target->query_skill("parry") + target->query("con") * 20;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 4;
  #                 if ( me->query("max_neili") > target->query("max_neili") * 2
  #                      && me->query("neili") > 500 )
  #                 {
  #                 msg += HIR "$n" HIR "全身一颤，立足不稳，被$N"
  #                        HIR "这招击得飞起，重重的跌落在地上。\n" NOR;
  # 
  #                 me->add("neili", -500);
  #                 me->start_busy(3);
  # 
  #               //  message_combatd(msg, me, target);
  # 
  #                 target->set("eff_qi", 0);
  #                 target->set("eff_jing", 0);
  #                 //target->unconcious(me);
  #                 }
  #         } else
  #         {
  #                 count = ap / 9;
  # 
  #         }
  # 
  #         message_sort(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #               //  if (random(5) < 2 && ! target->is_busy())
  #                //         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(5));
  # 
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end

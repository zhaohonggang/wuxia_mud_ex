defmodule Kantele.Combat.Skills.Performs.PiliQuan.Jin do
  @moduledoc """
  perform「紫雷劲」（source pili-quan/jin.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "pili-quan/jin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "pili-quan")
    ap = Stats.skill(stats, "cuff")
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
      Stats.skill(stats, "pili-quan") < 40 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 120}
    vitals = %{vitals | neili: vitals.neili - 80}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 3)
    result = Messages.interpolate("只见$P这一拳把$p飞了出去，重重的摔在地上，吐血不止！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-80"}], "assign_refs": [{"ap", "cuff"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"pili-quan", "40"}], "prepared_gates": [{"cuff", "pili-quan"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 紫雷劲
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define PO "「" MAG "紫雷劲" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/pili-quan/jin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("pili-quan", 1) < 40)
  #         return notify_fail("你的霹雳神拳不够娴熟，无法施展" PO "。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你现在真气不够，无法施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "pili-quan")
  #                 return notify_fail("你没有准备使用霹雳神拳，无法施展" PO "。\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "身形一转，运力与双拳，施出绝招「" HIW "紫雷劲" HIY "」，双拳迅猛无比"
  #               "的袭向$n" HIY "。\n" NOR;
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("parry");
  #     if (ap * 2 / 3 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap / 2);
  # 
  #                 me->add("neili", -120);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
  #                                    HIR "只见$P" HIR "这一拳把$p" HIR
  #                                            "飞了出去，重重的摔在地上，吐血不止！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
  #                        HIC "这一招。\n"NOR;
  #         me->add("neili", -80);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end

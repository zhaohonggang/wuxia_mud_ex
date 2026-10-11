defmodule Kantele.Combat.Skills.Performs.SuohouGong.Suo do
  @moduledoc """
  perform「铁爪锁喉」（source suohou-gong/suo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "suohou-gong/suo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "suohou-gong")
    ap = Stats.skill(stats, "claw")
    damage = (-1)

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
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "suohou-gong") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "claw") != "suohou-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 180}
    vitals = %{vitals | neili: vitals.neili - 20}
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 4)
    result = Messages.interpolate("$N一声冷笑，蓦地拔地而起，右手一招「铁爪锁喉」直取$n颈部。
霎时只听「喀嚓」一声脆响，$N五指竟将$n的喉结捏个粉碎。
( $n受伤过重，已经有如风中残烛，随时都可能断气。)
$n慌忙躲闪，却听「喀嚓」一声，$N五指正拿中$n的。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}, {"neili", "-20"}, {"neili", "-50"}], "assign_refs": [{"ap", "claw"}, {"damage", "force"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1);", "target->start_busy(1 + random(3));", "me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"suohou-gong", "150"}], "map_gates": [{"claw", "suohou-gong"}], "prepared_gates": [{"claw", "suohou-gong"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SUO "「" CYN "铁爪锁喉" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int ap, dp, damage;
  #         string msg;
  #         string *limbs, limb;
  # 
  #         if (userp(me) && ! me->query("can_perform/suohou-gong/suo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SUO "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(SUO "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("suohou-gong", 1) < 150)
  #                 return notify_fail("你琐喉功火候不够，难以施展" SUO "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "suohou-gong")
  #                 return notify_fail("你没有激发琐喉功，难以施展" SUO "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "suohou-gong")
  #                 return notify_fail("你没有准备琐喉功，难以施展" SUO "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" SUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "一声冷笑，蓦地拔地而起，右手一招「" NOR +
  #               CYN "铁爪锁喉" HIR "」直取$n" HIR "颈部。\n" NOR;
  #         me->add("neili", -20);
  # 
  #         ap = me->query_skill("claw");
  #         dp = target->query_skill("dodge");
  # 
  #         if (ap / 2 + random(ap * 2 / 3) > dp)
  #         {
  #                 damage = 0;
  # 
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIR "霎时只听「喀嚓」一声脆响，$N" HIR "五"
  #                                "指竟将$n" HIR "的喉结捏个粉碎。\n" NOR "("
  #                                " $n" RED "受伤过重，已经有如风中残烛，随时"
  #                                "都可能断气。" NOR ")\n";
  # 
  #                         damage = -1;
  #                         me->start_busy(1);
  #                         me->add("neili", -50);
  # 
  #                 } else
  #                 {
  #                         target->start_busy(1 + random(3));
  #         
  #                         damage = ap + (int)me->query_skill("force");
  #                         damage = damage / 2 + random(damage / 2);
  #                         
  #                         if (arrayp(limbs = target->query("limbs")))
  #                                 limb = limbs[random(sizeof(limbs))];
  #                         else
  #                                 limb = "要害";
  # 
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
  #                                                    HIR "$n" HIR "慌忙躲闪，却听「喀嚓」一"
  #                                                    "声，$N" HIR "五指正拿中$n" HIR "的" +
  #                                                    limb + "。\n" NOR);
  #                         me->start_busy(3);
  #                         me->add("neili", -180);
  #                 }
  #         } else 
  #         {
  #                 msg += CYN "可是$n" CYN "看破了$P"
  #                        CYN "的企图，身形急动，躲开了这一抓。\n"NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #         return 1;
  # }
end

defmodule Kantele.Combat.Skills.Performs.YinlongBian.Zhu do
  @moduledoc """
  perform「天诛龙蛟诀」（source yinlong-bian/zhu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinlong-bian/zhu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinlong-bian")
    ap = (Stats.skill(stats, "whip") + Stats.skill(stats, "force"))
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
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 130 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yinlong-bian") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "yinlong-bian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 200}
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
    Performs.feedback(attacker, 200, 3)
    result = Messages.interpolate("结果$n一声惨叫，未能看破$N的企图，被这一鞭硬击在胸口，鲜血飞溅，皮肉绽开！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "assign_refs": [{"ap", "whip"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "130"}, {"yinlong-bian", "100"}], "map_gates": [{"whip", "yinlong-bian"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define DUO "「" HIC "天诛龙蛟诀" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #  
  #         if (playerp(me) && ! me->query("can_perform/yinlong-bian/zhu"))
  #                 return notify_fail("你使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DUO "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #         if (me->query_skill("force", 1) < 130)
  #                 return notify_fail("你的内功火候不够，使不了" DUO "。\n");
  # 
  #         if (me->query_skill("yinlong-bian", 1) < 100)
  #                 return notify_fail("你的银龙鞭法功力太浅，使不了" DUO "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，无法使用" DUO "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "yinlong-bian")
  #                 return notify_fail("你没有激发银龙鞭法，使不了" DUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "诡异的一笑，手中" + weapon->name() +
  #               HIW "犹如一条银龙猛然飞向$n" HIW "，正是九阴真经中的"
  #              "绝招「" HIC "天诛龙蛟诀" HIW "」！\n" NOR;
  # 
  #         ap = me->query_skill("whip") + me->query_skill("force");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  # 
  #         if (ap * 11 / 20 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 me->add("neili", -200);
  #                 me->start_busy(2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
  #                                            HIR "结果$n" HIR "一声惨叫，未能看破$N"
  #                                            HIR "的企图，被这一鞭硬击在胸口，鲜血飞"
  #                                            "溅，皮肉绽开！\n" NOR);
  #                 message_combatd(msg, me, target);
  #                 
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "飞身一跃而起，躲避开了"
  #                        CYN "$P" CYN "的攻击！\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  # 
  #         return 1;
  # }
end

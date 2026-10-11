defmodule Kantele.Combat.Skills.Performs.ZhongnanZhi.Zhi do
  @moduledoc """
  perform「剑指南山」（source zhongnan-zhi/zhi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zhongnan-zhi/zhi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zhongnan-zhi")
    damage = Stats.skill(stats, "finger")

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
      Stats.skill(stats, "force") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "zhongnan-zhi") < 60 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "zhongnan-zhi" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 60 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 20}
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
    result = Messages.interpolate("结果$p招架失误，被$P这一指点了个正着，内息登时一滞，气血倒流。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-20"}, {"neili", "-60"}], "assign_refs": [{"damage", "finger"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "80"}, {"zhongnan-zhi", "60"}], "map_gates": [{"finger", "zhongnan-zhi"}], "prepared_gates": [{"finger", "zhongnan-zhi"}], "remote_damage": true, "resource_gates": [{"neili", "60"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHI "「" HIG "剑指南山" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/zhongnan-zhi/zhi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("zhongnan-zhi", 1) < 60)
  #                 return notify_fail("你终南指法不够娴熟，难以施展" ZHI "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "zhongnan-zhi")
  #                 return notify_fail("你没有激发终南指法，难以施展" ZHI "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "zhongnan-zhi")
  #                 return notify_fail("你没有准备终南指法，难以施展" ZHI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 80)
  #                 return notify_fail("你内功修为不够，难以施展" ZHI "。\n");
  # 
  #         if ((int)me->query("neili") < 60)
  #                 return notify_fail("你现在的真气不够，难以施展" ZHI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "斜斜一指刺出，指尖晃动不已，遥遥点向$n"
  #               HIG "要穴所在。\n" NOR;
  # 
  #         if (random(me->query_skill("finger")) > target->query_skill("parry") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("finger");
  #                 damage = 40 + damage / 3 + random(damage / 4);
  #                 me->add("neili", -60);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "结果$p" HIR "招架失误，被$P" HIR
  #                                            "这一指点了个正着，内息登时一滞，气血倒流。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -20);
  #                 msg += CYN "可是$p" CYN "识破了$P"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

defmodule Kantele.Combat.Skills.Performs.SunFinger.Qiankun do
  @moduledoc """
  perform「qiankun」（source sun-finger/qiankun.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "sun-finger/qiankun"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "sun-finger")
    ap = (Stats.skill(stats, "finger") + Stats.skill(stats, "force"))
    damage = (div(ap, 3) + Engine.rand(rng, div(ap, 4)))

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
      Stats.skill(stats, "force") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sun-finger") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "sun-finger" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 50, 3)
    result = Messages.interpolate("结果$p没能避开$P这一指，正被点中檀中大穴，浑身气血登时倒流，哇哇连吐几口鲜血！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "assign_refs": [{"ap", "finger"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "level_gates": [{"force", "160"}, {"sun-finger", "100"}], "map_gates": [{"finger", "sun-finger"}], "remote_damage": true, "resource_gates": [{"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // qiankun.c 一阳指 「一指乾坤」
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「一指乾坤」只能在战斗中使用。\n");
  # 
  #     if ((int)me->query_skill("sun-finger", 1) < 100)
  #         return notify_fail("你的一阳指修为不够，目前还不能施展一指乾坤绝技！\n");
  # 
  #     if ((int)me->query_skill("force") < 160)
  #         return notify_fail("你内功火候不够，难以施展一指乾坤！\n");
  # 
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你的真气不够，无法施展「一指乾坤」！\n");
  # 
  #     if (me->query_skill_mapped("finger") != "sun-finger")
  #         return notify_fail("你没有激发一阳指法，无法使用「一指乾坤」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "使出一阳指绝技「一指乾坤」，攻向$n"
  #               HIY "的要穴，招式变化精奇之极！\n" HIY;
  # 
  #         ap = me->query_skill("finger") + me->query_skill("force");
  #         dp = target->query_skill("parry") + target->query_skill("force");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #                 damage = ap / 3 + random(ap / 4);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 66,
  #                                            HIR "结果$p" HIR "没能避开$P"
  #                                            HIR "这一指，正被点中檀中大穴，浑身"
  #                                            "气血登时倒流，哇哇连吐几口鲜血！\n" NOR);
  #         me->add("neili", -200);
  #                 me->start_busy(1);
  #     } else
  #     {
  #         msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "急忙退闪，连消带打躲开了这一击。\n" NOR;
  #         me->start_busy(3);
  #                 me->add("neili", -50);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end

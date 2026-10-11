defmodule Kantele.Combat.Skills.Performs.RiyueLun.Po do
  @moduledoc """
  perform「破立势」（source riyue-lun/po.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "riyue-lun/po"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "riyue-lun")
    improve = 0
    n = 0
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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "riyue-lun") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "longxiang-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "hammer") != "riyue-lun" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 300}
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
    Performs.feedback(attacker, 300, 3)
    result = Messages.interpolate("$n被$N这强悍无比的内劲冲击得左摇右晃，接连中招，狂喷鲜血。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-300"}], "assign_refs": [{"ap", "force"}, {"dp", "force"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "level_gates": [{"force", "180"}, {"riyue-lun", "120"}], "map_gates": [{"force", "longxiang-gong"}, {"hammer", "riyue-lun"}], "remote_damage": true, "resource_gates": [{"max_neili", "1500"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PO "「" HIR "破立势" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg, wp;
  #     int ap, dp, damage;
  # 
  #         float improve;
  #         int lvl, i, n;
  #         string martial;
  #         string *ks;
  #         martial = "hammer";
  # 
  #         if (userp(me) && ! me->query("can_perform/riyue-lun/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target ) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_temp("yuan_man"))
  #                 return notify_fail("你现在无暇施展" PO "。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "hammer")
  #                 return notify_fail("你所使用的武器不对，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "riyue-lun")
  #                 return notify_fail("你没有激发日月轮法，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong")
  #                 return notify_fail("你没有激发龙象般若功，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("riyue-lun", 1) < 120)
  #                 return notify_fail("你的日月轮法火候不足，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功火候不足，难以施展" PO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1500)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wp = weapon->name();
  # 
  #     msg = HIY "$N" HIY "单手高举" + wp + HIY "奋力朝$n" HIY "砸下，气"
  #               "浪迭起，全然把$n" HIY "卷在其中！\n" NOR;
  # 
  #     lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #     lvl = lvl * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (i = 0; i < sizeof(ks); i++)
  #         {
  #             if (SKILL_D(ks[i])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[i], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 4 / 100 / lvl;
  # 
  #     ap = me->query_skill("force") + me->query("str") * 10;
  #     dp = target->query_skill("force") + target->query("con") * 10;
  # 
  #     ap += ap * improve;
  # 
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         me->add("neili", -300);
  #         damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "$n" HIR "被$N" HIR "这强悍无比的"
  #                                            "内劲冲击得左摇右晃，接连中招，狂喷鲜"
  #                                            "血。\n" NOR);
  #         me->start_busy(3);
  # 
  #     } else
  #     {
  #         msg += CYN "却见$p" CYN "浑不在意，轻轻一闪就躲过了$P"
  #                CYN "的凶悍招数。\n"NOR;
  #         me->add("neili", -150);
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end

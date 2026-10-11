defmodule Kantele.Combat.Skills.Performs.QishangQuan.Fei do
  @moduledoc """
  perform「魂魄飞扬」（source qishang-quan/fei.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qishang-quan/fei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qishang-quan")
    ap = (Stats.skill(stats, "cuff") + Stats.skill(stats, "force"))
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
      Stats.skill(stats, "force") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "qishang-quan") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 350 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 180}
    vitals = %{vitals | neili: vitals.neili - 320}
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
    Performs.feedback(attacker, 320, 3)
    result = Messages.interpolate("$N深吸一口起，将真气运于双拳之上，施出绝招「魂魄飞扬」，右拳平平一拳直出，但见普通一拳之中蕴涵了无穷的力量，拳未到风先至，猛然间袭向$n。
只听“砰”地一声，$N一拳正好打中$n胸口，$n怪叫一声，吐出一口淤血！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-180"}, {"neili", "-320"}], "assign_refs": [{"ap", "cuff"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "160"}, {"qishang-quan", "160"}], "prepared_gates": [{"cuff", "qishang-quan"}], "remote_damage": true, "resource_gates": [{"max_neili", "2200"}, {"neili", "350"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 伤字诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define PO "「" HIR "魂魄飞扬" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #     int damage;
  #     string msg;
  #   int ap, dp;
  # 
  #   if (! target)
  #   {
  #     me->clean_up_enemy();
  #     target = me->select_opponent();
  #   }
  # 
  #   if (userp(me) && ! me->query("can_perform/qishang-quan/fei"))
  #           return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("qishang-quan", 1) < 160)
  #         return notify_fail("你的七伤拳不够娴熟，无法施展" PO "。\n");
  # 
  #     if ((int)me->query_skill("force", 1) < 160)
  #         return notify_fail("你的内功修为还不够，无法施展" PO "\n");
  # 
  #         if (me->query("max_neili") < 2200)
  #                 return notify_fail("你内力修为不足，无法施展" PO "\n");
  # 
  #     if ((int)me->query("neili") < 350)
  #         return notify_fail("你现在真气不够，无法施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "qishang-quan")
  #                 return notify_fail("你没有准备使用七伤拳，无法施展" PO "。\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "\n$N" HIY "深吸一口起，将真气运于双拳之上，施出绝招「" HIR "魂魄飞扬" HIY
  #               "」，右拳平平一拳直出，但见普通一拳之中蕴涵了无穷的力量，拳未到风先至，猛然"
  #               "间袭向$n" HIY "。\n" NOR;
  # 
  #         ap = me->query_skill("cuff") + me->query_skill("force");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap / 2);
  # 
  #                 me->add("neili", -320);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
  #                                    HIR "只听“砰”地一声，$N" HIR "一拳正好打中$n" HIR "胸"
  #                                            "口，$n" HIR "怪叫一声，吐出一口淤血！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
  #                        HIC "这一招。\n"NOR;
  #         me->add("neili", -180);
  #         me->start_busy(3);
  #     }
  #     message_sort(msg, me, target);
  # 
  #     return 1;
  # }
end

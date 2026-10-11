defmodule Kantele.Combat.Skills.Performs.HuaQuan.Juan do
  @moduledoc """
  perform「风卷霹雳上九天」（source hua-quan/juan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "hua-quan/juan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hua-quan")
    damage = Stats.skill(stats, "cuff")

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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "hua-quan") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "cuff") != "hua-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 250}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 3)
    result = Messages.interpolate("结果$n闪避不及，被$P双拳贯中，凄然一声惨嚎，口喷鲜血，身子向后飞出丈许。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-250"}, {"neili", "-80"}], "assign_refs": [{"damage", "cuff"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "180"}, {"hua-quan", "120"}], "map_gates": [{"cuff", "hua-quan"}], "prepared_gates": [{"cuff", "hua-quan"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JUAN "「" HIY "风卷霹雳上九天" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/hua-quan/juan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JUAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("hua-quan", 1) < 120)
  #                 return notify_fail("你的西岳华拳不够娴熟，难以施展" JUAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" JUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "hua-quan")
  #                 return notify_fail("你没有激发西岳华拳，难以施展" JUAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "hua-quan")
  #                 return notify_fail("你现在没有准备使用西岳华拳，难以施展" JUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "只见$N" HIY "身形疾转，双拳聚力齐发，一式「风卷霹雳上九天」携"
  #               "着隐隐风雷之势贯向$n" HIY "！\n" NOR;
  # 
  #         if (random(me->query_skill("cuff")) > target->query_skill("dodge") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("cuff");
  #                 damage = damage / 2 + random(damage);
  #                 me->add("neili", -250);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "结果$n" HIR "闪避不及，被$P" HIR
  #                                            "双拳贯中，凄然一声惨嚎，口喷鲜血，身"
  #                                            "子向后飞出丈许。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -80);
  #                 msg += CYN "$p" CYN "见$P" CYN "拳势汹涌，不敢硬"
  #                        "作抵挡，当即斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

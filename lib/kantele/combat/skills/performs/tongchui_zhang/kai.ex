defmodule Kantele.Combat.Skills.Performs.TongchuiZhang.Kai do
  @moduledoc """
  perform「五丁开山」（source tongchui-zhang/kai.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tongchui-zhang/kai"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tongchui-zhang")
    damage = Stats.skill(stats, "strike")

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
      Stats.skill(stats, "force") < 90 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tongchui-zhang") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "tongchui-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 30}
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
    result = Messages.interpolate("$N右掌暗聚力道，十指分张，蓦地一招「五丁开山」向$n背心拍去。
结果$n闪避不及，顿被$N这掌击个正中，五脏六腑翻腾不已。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-30"}, {"neili", "-80"}], "assign_refs": [{"damage", "strike"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "90"}, {"tongchui-zhang", "80"}], "map_gates": [{"strike", "tongchui-zhang"}], "prepared_gates": [{"strike", "tongchui-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KAI "「" HIY "五丁开山" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int damage;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/tongchui-zhang/kai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KAI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(KAI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("tongchui-zhang", 1) < 80)
  #                 return notify_fail("你铜锤掌法不够娴熟，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "tongchui-zhang") 
  #                 return notify_fail("你没有激发铜锤掌法，难以施展" KAI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "tongchui-zhang") 
  #                 return notify_fail("你没有准备铜锤掌法，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 90)
  #                 return notify_fail("你的内功修为不够，难以施展" KAI "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不够，难以施展" KAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "右掌暗聚力道，十指分张，蓦地一招「"
  #               HIR "五丁开山" HIY "」向$n" HIY "背心拍去。\n" NOR;
  # 
  #         if (random(me->query_skill("strike")) > target->query_skill("dodge") / 2)
  #         {
  #                 damage = me->query_skill("strike");
  #                 damage = damage / 3 + random(damage / 2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "结果$n" HIR "闪避不及，顿被$N" HIR
  #                                            "这掌击个正中，五脏六腑翻腾不已。\n" NOR);
  #                 me->start_busy(2);
  #                 me->add("neili", -80);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "毫不慌张，当即向后轻"
  #                        "轻一跃，闪避开来。\n" NOR;
  #                 me->start_busy(3);
  #                 me->add("neili", -30);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end

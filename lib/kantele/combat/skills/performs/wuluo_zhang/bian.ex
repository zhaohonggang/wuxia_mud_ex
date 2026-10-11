defmodule Kantele.Combat.Skills.Performs.WuluoZhang.Bian do
  @moduledoc """
  perform「风云变幻」（source wuluo-zhang/bian.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "wuluo-zhang/bian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "wuluo-zhang")
    count = 0
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
      Stats.skill(stats, "wuluo-zhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "wuluo-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
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
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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
    Performs.feedback(attacker, 50, 1)
    result = Messages.interpolate("$n顿时觉得眼花缭乱，全然分辨不清真伪，只得拼命运动抵挡。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "apply_adds": ["attack", "unarmed_damage"], "assign_refs": [{"lvl", "wuluo-zhang"}], "busy_lines": ["me->start_busy(1 + random(5));"], "level_gates": [{"wuluo-zhang", "100"}], "map_gates": [{"strike", "wuluo-zhang"}], "prepared_gates": [{"strike", "wuluo-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "5"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BIAN "「" HIC "风云变幻" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/wuluo-zhang/bian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(BIAN "只能空手施展。\n");
  # 
  #         if ((lvl = (int)me->query_skill("wuluo-zhang", 1)) < 100)
  #                 return notify_fail("你五罗轻烟掌不够娴熟，难以施展" BIAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "wuluo-zhang")
  #                 return notify_fail("你没有激发五罗轻烟掌，难以施展" BIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "wuluo-zhang")
  #                 return notify_fail("你没有准备五罗轻烟掌，难以施展" BIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不足，难以施展" BIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "施出五罗轻烟掌绝技，单掌轻轻一抖，登时化出五道掌"
  #               "影，轻飘飘向$n" HIC "拍去。\n" NOR;
  #         me->add("neili", -50);
  # 
  #         if (random(me->query_skill("force") + me->query_skill("strike")) >
  #             target->query_skill("force"))
  #         {
  #                 msg += HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
  #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
  #                 count = lvl / 10;
  #                 me->add_temp("apply/attack", count);
  #                 me->add_temp("apply/unarmed_damage", count / 2);
  #         } else
  #         {
  #                 msg += HIC "可是$n" HIC "凝神顿气，奋力抵挡，丝"
  #                        "毫不受掌影的干扰，。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #         me->start_busy(1 + random(5));
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/unarmed_damage", -count / 2);
  #         return 1;
  # }
end

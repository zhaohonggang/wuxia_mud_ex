defmodule Kantele.Combat.Skills.Performs.XuanmingZhang.Ying do
  @moduledoc """
  perform「如影相随」（source xuanming-zhang/ying.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuanming-zhang/ying"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuanming-zhang")
    ap = Stats.skill(stats, "strike")

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
      Stats.skill(stats, "dodge") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xuanming-zhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "xuanming-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
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
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 180, 2)
    result = Messages.interpolate("$n顿觉寒气避人，一时间无从应对，竟被困在$N的掌风之中。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-180"}], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["if (target->is_busy())", "target->start_busy(1 + ap / 18);", "me->start_busy(1);", "me->start_busy(2);"], "level_gates": [{"dodge", "180"}, {"xuanming-zhang", "100"}], "map_gates": [{"strike", "xuanming-zhang"}], "prepared_gates": [{"strike", "xuanming-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YING "「" HIW "如影相随" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/xuanming-zhang/ying"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YING "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(YING "只能空手施展。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("xuanming-zhang", 1) < 100)
  #                 return notify_fail("你玄冥神掌不够娴熟，难以施展" YING "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "xuanming-zhang")
  #                 return notify_fail("你没有激发玄冥神掌，难以施展" YING "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "xuanming-zhang")
  #                 return notify_fail("你没有准备玄冥神掌，难以施展" YING "。\n");
  # 
  #         if (me->query_skill("dodge") < 180)
  #                 return notify_fail("你的轻功修为不够，难以施展" YING "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" YING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  # 
  #         dp = target->query_skill("dodge");
  # 
  #         msg = HIC "\n$N" HIC "长啸一声，施出绝招「" HIW "如影相随" HIC "」，"
  #               "双掌不断翻腾，掌风中透出阵阵阴寒之气，将$n" HIC "笼罩。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #         msg = HIR "$n" HIR "顿觉寒气避人，一时间无从应对，"
  #                       "竟被困在$N" HIR "的掌风之中。\n" NOR;
  # 
  #                 target->start_busy(1 + ap / 18);
  #                    me->start_busy(1);
  #                 me->add("neili", -180);
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "看破$N" CYN "毫无攻击之意，于"
  #                       "是大胆反攻，将$N" CYN "这招尽数化解。\n" NOR;
  # 
  #                 me->start_busy(2);
  #                 me->add("neili", -100);
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end

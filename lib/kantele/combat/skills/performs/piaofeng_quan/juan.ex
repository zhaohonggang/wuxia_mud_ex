defmodule Kantele.Combat.Skills.Performs.PiaofengQuan.Juan do
  @moduledoc """
  perform「卷字决」（source piaofeng-quan/juan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "piaofeng-quan/juan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "piaofeng-quan")

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "piaofeng-quan") < 30 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 80 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 40}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 40, 1)
    result = Messages.interpolate("结果$p运力招架，一时却觉得内力不济，被$P抢住手腕一拉，顿时立足不稳，滴溜溜打了两个圈子。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-40"}], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("cuff") / 22);", "me->start_busy(1);"], "level_gates": [{"piaofeng-quan", "30"}], "prepared_gates": [{"cuff", "piaofeng-quan"}], "remote_damage": false, "resource_gates": [{"neili", "80"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define JUAN "「" HIW "卷字决" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     string msg;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/piaofeng-quan/juan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(JUAN "只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("piaofeng-quan", 1) < 30)
  #         return notify_fail("你的飘风拳法不够娴熟，不会使用" JUAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "piaofeng-quan")
  #                 return notify_fail("你没有准备使用飘风拳法，无法施展" JUAN "。\n");
  # 
  #         if (me->query("neili") < 80)
  #                 return notify_fail("你现在真气不够，无法施展" JUAN "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "\n只见$N" HIC "右拳直出，中途猛地一转，突然发力，身法"
  #               "陡快，将$n" HIC "笼罩， 正是飘风拳法绝招「" HIW "卷字决" HIC "」。\n" NOR;
  # 
  #         me->add("neili", -40);
  #     if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
  #         {
  #         msg += HIR "结果$p" HIR "运力招架，一时却觉得"
  #                        "内力不济，被$P" HIR "抢住手腕一拉，顿时立足"
  #                        "不稳，滴溜溜打了两个圈子。\n" NOR;
  #         target->start_busy((int)me->query_skill("cuff") / 22);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "奋力一架，硬生生格开了$P"
  #                        CYN "这一拳。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_sort(msg, me, target);
  # 
  #     return 1;
  # }
end

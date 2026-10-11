defmodule Kantele.Combat.Skills.Performs.YitianZhang.Zheng do
  @moduledoc """
  perform「谁与争锋」（source yitian-zhang/zheng.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yitian-zhang/zheng"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yitian-zhang")
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
      Stats.skill(stats, "yitian-zhang") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "yitian-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 150}
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
    Performs.feedback(attacker, 150, 1)
    result = Messages.interpolate("$n顿时觉得呼吸不畅，全然被这股力道所制，只得拼命运动抵挡。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "apply_adds": ["attack"], "assign_refs": [{"lvl", "yitian-zhang"}], "busy_lines": ["me->start_busy(1 + random(4));"], "level_gates": [{"yitian-zhang", "120"}], "map_gates": [{"strike", "yitian-zhang"}], "prepared_gates": [{"strike", "yitian-zhang"}], "remote_damage": false, "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "4"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHENG "「" HIY "谁与争锋" NOR "」"
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
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/yitian-zhang/zheng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHENG "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" ZHENG "。\n");
  # 
  #         if ((lvl = (int)me->query_skill("yitian-zhang", 1)) < 120)
  #                 return notify_fail("你的倚天屠龙掌不够娴熟，难以施展" ZHENG "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 500)
  #                 return notify_fail("你现在真气太弱，难以施展" ZHENG "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "yitian-zhang")
  #                 return notify_fail("你没有激发倚天屠龙掌，难以施展" ZHENG "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "yitian-zhang")
  #                 return notify_fail("你没有准备使用倚天屠龙掌，难以施展" ZHENG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "神气贯通，将倚天屠龙掌二十四字一气呵成，双掌"
  #               "携带着排山倒海之劲贯向$n" HIY "。\n\n" NOR;
  #         me->add("neili", -150);
  # 
  #         if (random(me->query_skill("force") + me->query_skill("strike")) >
  #             target->query_skill("force"))
  #         {
  #                 msg += HIR "$n" HIR "顿时觉得呼吸不畅，全然被这"
  #                        "股力道所制，只得拼命运动抵挡。\n" NOR;
  #                 count = lvl / 5;
  #                 me->add_temp("apply/attack", count);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "深吸一口气，凝神抵挡，犹如轻舟立"
  #                        "于惊涛骇浪之中，左右颠簸，却是不倒。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(4));
  #         return 1;
  # }
end

defmodule Kantele.Combat.Skills.Performs.XuanfengTui.Kuang do
  @moduledoc """
  perform「狂风绝技」（source xuanfeng-tui/kuang.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuanfeng-tui/kuang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuanfeng-tui")
    count = div(lvl, 4)
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
      Stats.skill(stats, "xuanfeng-tui") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "xuanfeng-tui" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
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
    Performs.feedback(attacker, 100, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "apply_adds": ["attack", "unarmed_damage"], "assign_refs": [{"lvl", "xuanfeng-tui"}], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"xuanfeng-tui", "100"}], "map_gates": [{"unarmed", "xuanfeng-tui"}], "prepared_gates": [{"unarmed", "xuanfeng-tui"}], "remote_damage": false, "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KUANG "「" HIY "狂风绝技" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     //object weapon;
  #     string msg;
  #     int i;
  #     int lvl, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/xuanfeng-tui/kuang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target)
  #     {
  #         me->clean_up_enemy();
  #             target = me->select_opponent();
  #     }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KUANG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(KUANG "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("xuanfeng-tui", 1) < 100)
  #                 return notify_fail("你旋风扫叶腿不够娴熟，难以施展" KUANG "。\n");
  # 
  #         if ((int)me->query_skill("xuanfeng-tui", 1) < 100)
  #                 return notify_fail("你的旋风扫叶腿不够娴熟，难以施展" KUANG "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "xuanfeng-tui")
  #                 return notify_fail("你没有激发旋风扫叶腿，难以施展" KUANG "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "xuanfeng-tui")
  #                 return notify_fail("你没有准备旋风扫叶腿，难以施展" KUANG "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" KUANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "使出桃花岛狂风绝技，身法飘忽不定，足带风尘，掌携"
  #               "万钧，有若天仙！\n" NOR;
  #     message_combatd(msg, me);
  #     me->add("neili", -100);
  #     lvl = me->query_skill("xuanfeng-tui", 1);
  #     count = 0;
  # 
  #     if (me->query("family/family_name") == "桃花岛")
  #         count = lvl / 4;
  # 
  #     me->add_temp("apply/attack", count);
  #     me->add_temp("apply/unarmed_damage", count / 2);
  # 
  #     for (i = 0; i < 6; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #                 if (random(3) == 0 && ! target->is_busy())
  #                         target->start_busy(1);
  #         COMBAT_D->do_attack(me, target, 0, 0);
  #     }
  # 
  #     me->start_busy(1 + random(6));
  #     me->add_temp("apply/attack", -count);
  #     me->add_temp("apply/unarmed_damage", -count / 2);
  #     return 1;
  # }
end

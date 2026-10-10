defmodule Kantele.Combat.Skills.Performs.XuanfengTui.Kuang do
  @moduledoc """
  perform「狂风绝技」（source xuanfeng-tui/kuang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
      #   %{"assign_refs": [{"lvl", "xuanfeng-tui"}], "level_gates": [{"xuanfeng-tui", "100"}], "map_gates": [{"unarmed", "xuanfeng-tui"}], "prepared_gates": [{"unarmed", "xuanfeng-tui"}], "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你旋风扫叶腿不够娴熟，难以施展", "你的旋风扫叶腿不够娴熟，难以施展", "你没有激发旋风扫叶腿，难以施展", "你没有准备旋风扫叶腿，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "使出桃花岛狂风绝技，身法飘忽不定，足带风尘，掌携"
      #                 "万钧，有若天仙！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack", "unarmed_damage"], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

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

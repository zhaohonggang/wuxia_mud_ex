defmodule Kantele.Combat.Skills.Performs.LanhuaShou.Fei do
  @moduledoc """
  perform「影落飞花」（source lanhua-shou/fei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "lanhua-shou"}], "level_gates": [{"lanhua-shou", "140"}], "map_gates": [{"hand", "lanhua-shou"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你兰花拂穴手不够娴熟，难以施展", "你没有激发兰花拂穴手，难以施展", "你没有准备兰花拂穴手，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "微一凝神，双手作兰花状疾拂而出，一环环的劲气登时直逼$n"
      #                 HIC "全身各大要穴。\n" NOR", "= HIY "可是$n" HIY "凝神顿气，奋力抵挡，丝"
      #                          "毫不受手影的干扰，。\n" NOR"], "success": ["= HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
      #                          "不清真伪，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(random(3));"], "remote_damage": false, "set_flags": [], "temp_set": ["action_flag"]}
      #   - me->start_busy(random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define FEI "「" HIC "影落飞花" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         mapping p;
      #         int i, af, lvl, count;
      # 
      #         if (userp(me) && ! me->query("can_perform/lanhua-shou/fei"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(FEI "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail(FEI "只能空手施展。\n");
      # 
      #         if ((lvl = (int)me->query_skill("lanhua-shou", 1)) < 140)
      #                 return notify_fail("你兰花拂穴手不够娴熟，难以施展" FEI "。\n");
      # 
      #         if (me->query_skill_mapped("hand") != "lanhua-shou")
      #                 return notify_fail("你没有激发兰花拂穴手，难以施展" FEI "。\n");
      # 
      #         if (! mapp(p = me->query_skill_prepare())
      #            || p["hand"] != "lanhua-shou")
      #                 return notify_fail("你没有准备兰花拂穴手，难以施展" FEI "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在真气不足，难以施展" FEI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIC "$N" HIC "微一凝神，双手作兰花状疾拂而出，一环环的劲气登时直逼$n"
      #               HIC "全身各大要穴。\n" NOR;
      #         me->add("neili", -150);
      # 
      #         if (random(me->query_skill("parry") + me->query_skill("hand")) >
      #             target->query_skill("parry"))
      #         {
      #                 msg += HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
      #                        "不清真伪，只得拼命运动抵挡。\n" NOR;
      #                 count = lvl / 5;
      #                 me->add_temp("apply/attack", count);
      #         } else
      #         {
      #                 msg += HIY "可是$n" HIY "凝神顿气，奋力抵挡，丝"
      #                        "毫不受手影的干扰，。\n" NOR;
      #                 count = 0;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         af = member_array("hand", keys(p));
      # 
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 me->set_temp("action_flag", af);
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      #         me->start_busy(random(3));
      #         me->add_temp("apply/attack", -count);
      #         return 1;
      # }
end

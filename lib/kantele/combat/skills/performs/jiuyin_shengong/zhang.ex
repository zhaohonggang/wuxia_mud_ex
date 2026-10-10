defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhang do
  @moduledoc """
  perform「九阴神掌」（source jiuyin-shengong/zhang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "jiujin-shengong"}, {"dp", "parry"}], "level_gates": [{"jiuyin-shengong", "260"}, {"strike", "220"}], "map_gates": [], "prepared_gates": [{"strike", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "resource_gates": [], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "此招只能空手施展！\n", "你的九阴神功不够深厚，不会使用", "你的基本掌法修为不够，不会使用", "你没有准备使用九阴神功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("jiujin-shengong", 1)", "dp_formula": "target->query_skill("parry", 1)"}, "color_codes": ["HIM", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "双掌一错，幻化出无数掌影，层层叠荡向$n" HIY "逼去！\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-320"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-320"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(2) == 1 && !target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) == 1 && !target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // zhang.c 九阴神掌
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define ZHANG "「" HIM "九阴神掌" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #     string msg;
      #     int ap, dp;
      #     int i, count;
      # 
      #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/zhang"))
      #         return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (!target)
      #         target = offensive_target(me);
      # 
      #     if (!target || !me->is_fighting(target))
      #         return notify_fail(ZHANG "只能对战斗中的对手使用。\n");
      # 
      #     if (me->query_temp("weapon"))
      #         return notify_fail("此招只能空手施展！\n");
      # 
      #     if ((int)me->query_skill("jiuyin-shengong", 1) < 260)
      #         return notify_fail("你的九阴神功不够深厚，不会使用" ZHANG "。\n");
      # 
      #     if ((int)me->query_skill("strike", 1) < 220)
      #         return notify_fail("你的基本掌法修为不够，不会使用" ZHANG "。\n");
      # 
      #     if (me->query_skill_prepared("unarmed") != "jiuyin-shengong" && me->query_skill_prepared("strike") != "jiuyin-shengong")
      #         return notify_fail("你没有准备使用九阴神功，无法施展" ZHANG "。\n");
      # 
      #     if (!living(target))
      #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "双掌一错，幻化出无数掌影，层层叠荡向$n" HIY "逼去！\n" NOR;
      #     message_combatd(msg, me, target); //修正pfm描述信息显示时间错误 by MK
      # 
      #     ap = me->query_skill("jiujin-shengong", 1);
      #     dp = target->query_skill("parry", 1);
      # 
      #     if (ap / 2 + random(ap) > dp)
      #         // count = ap / 7;
      #         count = ap / 5;
      # 
      #     else
      #         count = 9;
      # 
      #     me->add_temp("apply/attack", count);
      #     for (i = 0; i < 9; i++)
      #     {
      #         if (!me->is_fighting(target))
      #             break;
      # 
      #         if (random(2) == 1 && !target->is_busy())
      #             target->start_busy(1);
      # 
      #         COMBAT_D->do_attack(me, target, 0, );
      #     }
      #     me->start_busy(2 + random(4));
      #     me->add("neili", -320);
      # 
      #     me->add_temp("apply/attack", -count);
      # 
      #     return 1;
      # }
end

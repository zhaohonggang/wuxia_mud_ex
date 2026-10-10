defmodule Kantele.Combat.Skills.Performs.TianshanZhang.Fugu do
  @moduledoc """
  perform「如蛆附骨」（source tianshan-zhang/fugu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "staff"}, {"dp", "dodge"}], "level_gates": [{"tianshan-zhang", "60"}], "map_gates": [{"staff", "tianshan-zhang"}], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对。\n", "你的天山杖法不够娴熟，不会使用", "你没有激发天山杖法，使不了", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("staff")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "桀桀奸笑，手中的" + weapon->name() +
      #                 HIG "就像影子一般袭向$n。\n" NOR"], "success": ["= HIR "结果$n" HIR "被$N" HIR "吓得惊慌失措，"
      #                          "一时间手忙脚乱，难以应对！\n" NOR", "= "可是$n" HIR "看破了$N" HIR "的企图，"
      #                          "轻轻一退，闪去了$N" HIR "的追击。\n" NOR"]}, "hit_formula": %{"left_side": "ap * 11 / 20 + random(ap)", "operator": ">", "right_side": "dp"}, "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("staff") / 25 + 2);", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("staff") / 25 + 2);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // fugu.c 如蛆附骨
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define GU "「" HIW "如蛆附骨" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/tianshan-zhang/fugu"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(GU "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "staff")
      #                 return notify_fail("你使用的武器不对。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
      #                 
      #         if ((int)me->query_skill("tianshan-zhang", 1) < 60)
      #                 return notify_fail("你的天山杖法不够娴熟，不会使用" GU "。\n");
      # 
      #         if (me->query_skill_mapped("staff") != "tianshan-zhang")
      #                 return notify_fail("你没有激发天山杖法，使不了" GU "。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIG "$N" HIG "桀桀奸笑，手中的" + weapon->name() +
      #               HIG "就像影子一般袭向$n。\n" NOR;
      # 
      #         ap = me->query_skill("staff");
      #         dp = target->query_skill("dodge");
      #         if (ap * 11 / 20 + random(ap) > dp)
      #         {
      #                 msg += HIR "结果$n" HIR "被$N" HIR "吓得惊慌失措，"
      #                        "一时间手忙脚乱，难以应对！\n" NOR;
      #                 target->start_busy((int)me->query_skill("staff") / 25 + 2);
      #         } else
      #         {
      #                 msg += "可是$n" HIR "看破了$N" HIR "的企图，"
      #                        "轻轻一退，闪去了$N" HIR "的追击。\n" NOR;
      #                 me->start_busy(1);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.YunzhouFufa.Feng do
  @moduledoc """
  perform「风魔舞」（source yunzhou-fufa/feng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"yunzhou-fufa", "60"}], "map_gates": [{"whip", "yunzhou-fufa"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你的武器不对，无法施展", "你的云帚拂法级别不够，无法施展", "你现在真气不够，无法施展", "你没有激发云帚拂法，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n$N暴喝一声，潜运体内真气，将" + weapon->name() + HIY 
      #                 "挥舞得呼呼直响，直破长空，犹如漫天狂沙般卷向$n。" NOR", "CYN "可是$p" CYN "看破了$P"
      #                         CYN "的企图，斜跳躲闪开来。\n" NOR"], "success": ["HIR "$n" HIR "只觉风声萧萧，眼前万千鞭影，顿感"
      #                         "手脚无措，惊慌不已。\n" NOR"]}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "target->start_busy((int)me->query_skill("yunzhou-fufa") / 25 + 2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1);
      #   - target->start_busy((int)me->query_skill("yunzhou-fufa") / 25 + 2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define FENG "「" HIG "风魔舞" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(FENG "只能对战斗中的对手使用。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放"
      #                                    "胆攻击吧。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             weapon->query("skill_type") != "whip")
      #                 return notify_fail("你的武器不对，无法施展" FENG "\n");
      # 
      #         if (me->query_skill("yunzhou-fufa", 1) < 60)
      #                 return notify_fail("你的云帚拂法级别不够，无法施展" FENG "！\n");
      # 
      #         if (me->query("neili") < 100)
      #                 return notify_fail("你现在真气不够，无法施展" FENG "！\n");
      # 
      #         if (me->query_skill_mapped("whip") != "yunzhou-fufa")
      #                 return notify_fail("你没有激发云帚拂法，无法施展" FENG "！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "\n$N暴喝一声，潜运体内真气，将" + weapon->name() + HIY 
      #               "挥舞得呼呼直响，直破长空，犹如漫天狂沙般卷向$n。" NOR;
      # 
      #         me->start_busy(1);
      # 
      #         message_sort(msg, me, target);
      # 
      #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
      #         {
      #                 msg = HIR "$n" HIR "只觉风声萧萧，眼前万千鞭影，顿感"
      #                       "手脚无措，惊慌不已。\n" NOR;
      #                 target->start_busy((int)me->query_skill("yunzhou-fufa") / 25 + 2);
      #         } else
      #         {
      #                 msg = CYN "可是$p" CYN "看破了$P"
      #                       CYN "的企图，斜跳躲闪开来。\n" NOR;
      #         }
      #         me->add("neili", -80);
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

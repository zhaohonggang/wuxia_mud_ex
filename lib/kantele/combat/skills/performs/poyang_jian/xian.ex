defmodule Kantele.Combat.Skills.Performs.PoyangJian.Xian do
  @moduledoc """
  perform「神光再现」（source poyang-jian/xian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "poyang-jian"}], "level_gates": [{"force", "200"}], "map_gates": [{"sword", "poyang-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": [{"level", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你破阳冷光剑不够娴熟，难以施展", "你没有激发破阳冷光剑，难以施展", "你的内功火候不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "\n$N" HIG "长啸一声，使出破阳冷光剑绝招「" HIY "神光再"
      #                 "现" HIG "」，手中" + weapon->name() + HIG "光芒瀑涨，刺眼"
      #                 "眩目，犹如神光降世，刹那间只觉得天地为之失辉，光芒已盖"
      #                 "向$n\n" HIG "。" NOR", "CYN "可是$n" CYN "看破了$N"
      #                         CYN "的企图，一丝不乱，应对自若。\n" NOR"], "success": ["HIR "$n" HIR "被耀眼的光芒所惑，心中惊"
      #                         "疑不定，一时间不知如何应对！\n" NOR"]}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 26 + 2);", "me->start_busy(1);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 26 + 2);
      #   - me->start_busy(1);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define XIAN "「" HIY "神光再现" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         object weapon;
      #         int level;
      # 
      #         if (userp(me) && ! me->query("can_perform/poyang-jian/xian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(XIAN "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" XIAN "。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         level = me->query_skill("poyang-jian", 1);
      # 
      #         if (level < 120)
      #         return notify_fail("你破阳冷光剑不够娴熟，难以施展" XIAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "poyang-jian")
      #                 return notify_fail("你没有激发破阳冷光剑，难以施展" XIAN "。\n");
      # 
      #     if ((int)me->query_skill("force") < 200)
      #         return notify_fail("你的内功火候不足，难以施展" XIAN "。\n");
      # 
      #         if (me->query("neili") < 150)
      #                 return notify_fail("你现在的真气不够，难以施展" XIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      # 
      #     msg = HIG "\n$N" HIG "长啸一声，使出破阳冷光剑绝招「" HIY "神光再"
      #               "现" HIG "」，手中" + weapon->name() + HIG "光芒瀑涨，刺眼"
      #               "眩目，犹如神光降世，刹那间只觉得天地为之失辉，光芒已盖"
      #               "向$n\n" HIG "。" NOR;
      #         message_sort(msg, me, target);
      # 
      #         me->add("neili", -120);
      #         if (level / 2 + random(level) > target->query_skill("dodge", 1))
      #         {
      #         msg = HIR "$n" HIR "被耀眼的光芒所惑，心中惊"
      #                       "疑不定，一时间不知如何应对！\n" NOR;
      #                 target->start_busy(level / 26 + 2);
      #                 me->start_busy(1);
      #     } else
      #         {
      #         msg = CYN "可是$n" CYN "看破了$N"
      #                       CYN "的企图，一丝不乱，应对自若。\n" NOR;
      #                 me->start_busy(2);
      #     }
      #     message_vision(msg, me, target);
      # 
      #     return 1;
      # }
end

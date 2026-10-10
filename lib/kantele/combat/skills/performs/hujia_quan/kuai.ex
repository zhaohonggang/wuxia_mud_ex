defmodule Kantele.Combat.Skills.Performs.HujiaQuan.Kuai do
  @moduledoc """
  perform「奔拳快打」（source hujia-quan/kuai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "100"}, {"hujia-quan", "80"}], "map_gates": [{"cuff", "hujia-quan"}], "prepared_gates": [{"cuff", "hujia-quan"}], "resource_gates": [{"neili", "80"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功火候不足，难以施展", "你的胡家拳法不够娴熟，难以施展", "你没有激发胡家拳法，难以施展", "你没有准备胡家拳法，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "纵步上前，拳招迭出，疾如奔雷，霎时已向$n" WHT "攻出数拳。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的虚招，轻轻一闪，"
      #                          "避开了这骤雨般的拳影。\n" NOR"], "success": ["= HIR "结果$n" HIR "无法分清$N" HIR "招式中的虚实，"
      #                          "不由手忙脚乱。\n" NOR"]}, "resource_adds": [{"neili", "-40"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-40"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy((int)me->query_skill("cuff") / 25 + 2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy((int)me->query_skill("cuff") / 25 + 2);
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
      # #define KUAI "「" WHT "奔拳快打" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //    object weapon;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/hujia-quan/kuai"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(KUAI "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(KUAI "只能空手施展。\n");
      # 
      #     if (target->is_busy())
      #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #     if ((int)me->query_skill("force") < 100)
      #         return notify_fail("你的内功火候不足，难以施展" KUAI "。\n");
      # 
      #     if ((int)me->query_skill("hujia-quan", 1) < 80)
      #         return notify_fail("你的胡家拳法不够娴熟，难以施展" KUAI "。\n");
      # 
      #         if (me->query_skill_mapped("cuff") != "hujia-quan")
      #                 return notify_fail("你没有激发胡家拳法，难以施展" KUAI "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "hujia-quan")
      #                 return notify_fail("你没有准备胡家拳法，难以施展" KUAI "。\n");
      # 
      #         if (me->query("neili") < 80)
      #                 return notify_fail("你现在真气不够，难以施展" KUAI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = WHT "$N" WHT "纵步上前，拳招迭出，疾如奔雷，霎时已向$n" WHT "攻出数拳。\n" NOR;
      # 
      #         me->add("neili", -40);
      #     if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3)
      #         {
      #         msg += HIR "结果$n" HIR "无法分清$N" HIR "招式中的虚实，"
      #                        "不由手忙脚乱。\n" NOR;
      #         target->start_busy((int)me->query_skill("cuff") / 25 + 2);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "的虚招，轻轻一闪，"
      #                        "避开了这骤雨般的拳影。\n" NOR;
      #         me->start_busy(2);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end

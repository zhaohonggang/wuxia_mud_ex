defmodule Kantele.Combat.Skills.Performs.WaiBagua.Zhen do
  @moduledoc """
  perform「八卦震」（source wai-bagua/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "wai-bagua"}], "level_gates": [{"force", "100"}, {"wai-bagua", "60"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功火候不足，难以施展", "你的外八卦不够娴熟，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "深吸一口气，双掌交错，一招「八卦震」平平拍出，企"
      #                 "图以内力震伤$n" WHT "。\n" NOR", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，并没有上当。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "结果$n" HIR "微微一楞，没有看破招"
      #                                              "中奥妙，$N" HIR "双掌正好拍在胸前。\n"
      #                                              NOR ":内伤@?")"]}, "damage_formula": %{"formula": "(int)me->query_skill("wai-bagua", 1)"}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - target->start_busy(random(3));
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define ZHEN "「" WHT "八卦震" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/wai-bagua/zhen"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHEN "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail(ZHEN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("force") < 100)
      #                 return notify_fail("你的内功火候不足，难以施展" ZHEN  "。\n");
      # 
      #         if ((int)me->query_skill("wai-bagua", 1) < 60)
      #                 return notify_fail("你的外八卦不够娴熟，难以施展" ZHEN  "。\n");
      #                                 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在真气不足，难以施展" ZHEN  "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "深吸一口气，双掌交错，一招「八卦震」平平拍出，企"
      #               "图以内力震伤$n" WHT "。\n" NOR;
      #         me->add("neili", -50);
      # 
      #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
      #         {
      #                 me->start_busy(3);
      #                 target->start_busy(random(3));
      # 
      #                 damage = (int)me->query_skill("wai-bagua", 1);
      #                 damage = damage / 2 + random(damage / 2);
      #                 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                            HIR "结果$n" HIR "微微一楞，没有看破招"
      #                                            "中奥妙，$N" HIR "双掌正好拍在胸前。\n"
      #                                            NOR ":内伤@?");
      #         } else 
      #         {
      #                 me->start_busy(3);
      #                 msg += CYN "可是$p" CYN "看破了$P"
      #                        CYN "的企图，并没有上当。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end

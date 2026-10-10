defmodule Kantele.Combat.Skills.Performs.WoshiZhang.Po do
  @moduledoc """
  perform「po」（source woshi-zhang/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "woshi-zhang"}], "level_gates": [{"force", "140"}, {"woshi-zhang", "120"}], "map_gates": [{"strike", "woshi-zhang"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「碎石破玉」只能在战斗中对对手使用。\n", "你所使用的外功中没有这种功能。\n", "你必须空手才能使用「碎石破玉」！\n", "你的内功的修为不够，不能使用这一绝技！\n", "你的握石掌修为不够，目前不能使用「碎石破玉」！\n", "你没有激发握石掌，难以施展「碎石破玉」。\n", "你现在真气不够，难以施展「碎石破玉」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "聚力于掌，猛然间怒喝一声，一掌破空而至，正是" 
      #                 "握石掌的一招「开碑碎石」，破空劈向$n" HIW "而去！\n" NOR", "= CYN "可是$p" CYN "看破了$N" CYN 
      #                          "的企图，躲开了这招杀着。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35, 
      #                   msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                              HIR "结果只听$n" HIR "一声惨嚎，胸口" 
      #                                              HIR "已被$N掌劲结结实实的轰中，“哇”的喷出一大" 
      #                                              "口鲜血。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("woshi-zhang", 1)"}, "resource_adds": [{"neili", "-120"}, {"neili", "-250"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}, {"neili", "-250"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
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
      # inherit F_SSERVER;  
      # 
      # int perform(object me, object target)  
      # {
      #         string msg;  
      #         int damage;  
      # 
      #         if (! target) target = offensive_target(me);  
      # 
      #         if (! target || ! me->is_fighting(target))  
      #                 return notify_fail("「碎石破玉」只能在战斗中对对手使用。\n");  
      # 
      #         //if (userp(me) && ! me->query("can_perform/woshi-zhang/po"))  
      #         //        return notify_fail("你所使用的外功中没有这种功能。\n");  
      # 
      #         if (me->query_temp("weapon") ||  
      #             me->query_temp("secondary_weapon"))  
      #                 return notify_fail("你必须空手才能使用「碎石破玉」！\n");  
      # 
      #         if (me->query_skill("force") < 140)  
      #                 return notify_fail("你的内功的修为不够，不能使用这一绝技！\n");  
      # 
      #         if (me->query_skill("woshi-zhang", 1) < 120)  
      #                 return notify_fail("你的握石掌修为不够，目前不能使用「碎石破玉」！\n");  
      # 
      #         if (me->query_skill_mapped("strike") != "woshi-zhang") 
      #                 return notify_fail("你没有激发握石掌，难以施展「碎石破玉」。\n"); 
      # 
      #         if (me->query("neili") < 400) 
      #                 return notify_fail("你现在真气不够，难以施展「碎石破玉」。\n"); 
      # 
      #         if (! living(target)) 
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n"); 
      # 
      #         msg = HIW "只见$N" HIW "聚力于掌，猛然间怒喝一声，一掌破空而至，正是" 
      #               "握石掌的一招「开碑碎石」，破空劈向$n" HIW "而去！\n" NOR; 
      # 
      #         if (random(me->query_skill("strike")) > target->query_skill("parry") / 2) 
      #         { 
      #                 me->start_busy(2); 
      # 
      #                 damage = me->query_skill("woshi-zhang", 1); 
      #                 //damage = damage * 2 + random(damage * 5); 
      #                 damage = damage * 2 + random(damage * 2);
      #                 //msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35, 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                            HIR "结果只听$n" HIR "一声惨嚎，胸口" 
      #                                            HIR "已被$N掌劲结结实实的轰中，“哇”的喷出一大" 
      #                                            "口鲜血。\n" NOR); 
      #                 me->add("neili", -250); 
      #         } else 
      #         {
      #                 me->start_busy(2); 
      #                 me->add("neili", -120); 
      #                 msg += CYN "可是$p" CYN "看破了$N" CYN 
      #                        "的企图，躲开了这招杀着。\n" NOR; 
      #         }
      #         message_combatd(msg, me, target); 
      # 
      #         return 1; 
      # }
end

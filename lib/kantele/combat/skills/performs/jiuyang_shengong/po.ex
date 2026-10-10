defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Po do
  @moduledoc """
  perform「金阳破岭」（source jiuyang-shengong/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "240"}, {"jiuyang-shengong", "220"}, {"sword", "240"}], "map_gates": [{"sword", "jiuyang-shengong"}], "prepared_gates": [], "resource_gates": [{"max_neili", "5500"}, {"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的九阳神功不够娴熟，难以施展", "你的内功根基不够，难以施展", "你的基本剑法火候不够，难以施展", "你的内力修为不足，难以施展", "你现在真气不够，难以施展", "你没有激发九阳神功为剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword") + me->query_skill("force", 1)", "dp_formula": "target->query_skill("parry") + target->query_skill("force", 1)"}, "callback_functions": [%{"body": "target->add("neili", -(damage / 4));
      #           target->add("neili", -(damage / 8));
      #           return  HIY "$n" HIY "见此招快速无比，已无从躲闪，只得奋力招架，但是无奈$N" HIY 
      #                   "内力惊人，一股剑气已经穿透$n" HIY "胸口，鲜血狂泻而出。$n" H", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["HIC", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n$N" HIY "一声长吟，内力瀑涨，全身真气贯与剑柄。手中" + weapon->name() + HIY 
      #                 "光芒四射，刹那间一股强劲的剑气已涌向$n" HIY "！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85 + random(5),
      #                                              (: final, me, target, damage :))", "= HIC "可是$n" HIC "看透$P" HIC "此招之中的破绽，镇"
      #                          "定逾恒，全神应对自如。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap / 3)"}, "hit_formula": %{"left_side": "ap * 11 / 20 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-(damage / 4)"}, {"neili", "-(damage / 8)"}, {"neili", "-150"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define PO "「" HIY "金阳破岭" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/jiuyang-shengong/po"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (userp(me) && ! me->query("can_learn/jiuyang-shengong/enable_weapon"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");    
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" PO "。\n");
      # 
      #         if ((int)me->query_skill("jiuyang-shengong", 1) < 220)
      #                 return notify_fail("你的九阳神功不够娴熟，难以施展" PO "。\n");
      # 
      #         if ((int)me->query_skill("force", 1) < 240)
      #                 return notify_fail("你的内功根基不够，难以施展" PO "。\n");
      # 
      #         if ((int)me->query_skill("sword", 1) < 240)
      #                 return notify_fail("你的基本剑法火候不够，难以施展" PO "。\n");
      # 
      #         if ((int)me->query("max_neili") < 5500)
      #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
      # 
      #         if (me->query("neili") < 400)
      #                 return notify_fail("你现在真气不够，难以施展" PO "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "jiuyang-shengong") 
      #                 return notify_fail("你没有激发九阳神功为剑法，难以施展" PO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "\n$N" HIY "一声长吟，内力瀑涨，全身真气贯与剑柄。手中" + weapon->name() + HIY 
      #               "光芒四射，刹那间一股强劲的剑气已涌向$n" HIY "！\n" NOR;
      # 
      #         me->add("neili", -150);
      #         ap = me->query_skill("sword") + me->query_skill("force", 1);
      #         dp = target->query_skill("parry") + target->query_skill("force", 1);
      # 
      #         me->start_busy(2 + random(2));
      #         if (ap * 11 / 20 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 3);
      #                 me->add("neili", -200);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85 + random(5),
      #                                            (: final, me, target, damage :));
      #         } else
      #         {
      #                 msg += HIC "可是$n" HIC "看透$P" HIC "此招之中的破绽，镇"
      #                        "定逾恒，全神应对自如。\n" NOR;
      #         }
      #         message_sort(msg, me, target);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         target->add("neili", -(damage / 4));
      #         target->add("neili", -(damage / 8));
      #         return  HIY "$n" HIY "见此招快速无比，已无从躲闪，只得奋力招架，但是无奈$N" HIY 
      #                 "内力惊人，一股剑气已经穿透$n" HIY "胸口，鲜血狂泻而出。$n" HIY "顿觉"
      #                 "内息散乱。\n" NOR;
      # }
end

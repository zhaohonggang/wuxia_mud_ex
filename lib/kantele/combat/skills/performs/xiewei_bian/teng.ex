defmodule Kantele.Combat.Skills.Performs.XieweiBian.Teng do
  @moduledoc """
  perform「腾蛇诀」（source xiewei-bian/teng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "force"}], "level_gates": [{"xiewei-bian", "100"}], "map_gates": [{"whip", "xiewei-bian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对。\n", "你使用的武器不对，无法施展", "你的真气不够，无法施展", "你没有激发蝎尾鞭，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip") + me->query_skill("force")", "dp_formula": "target->query_skill("force") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "陡然施展出「腾蛇」诀，手腕轻轻一抖，" + weapon->name() +
      #                 WHT "顿时拔地弹起，如同活物一般悄然袭向$n" + WHT "！\n" NOR", "= CYN "可是$p" CYN "运足内力，奋力挡住了"
      #                          CYN "$P" CYN "这神鬼莫测的一击！\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "然而$n" HIR "未能看破企图，一声惨嚎，"
      #                                              + weapon->name() + HIR "鞭端已没入体内半寸"
      #                                              "，登时连退数步！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 5 + random(ap / 4)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // tengshe.c 腾蛇
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define TENGSHE "「" WHT "腾蛇诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage;
      #  
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/xiewei-bian/tengshe"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(TENGSHE "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "whip")
      #                 return notify_fail("你使用的武器不对。\n");
      # 
      #         if ((int)me->query_skill("xiewei-bian", 1) < 100)
      #                 return notify_fail("你使用的武器不对，无法施展" TENGSHE "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，无法施展" TENGSHE "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "xiewei-bian")
      #                 return notify_fail("你没有激发蝎尾鞭，无法施展" TENGSHE "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "陡然施展出「腾蛇」诀，手腕轻轻一抖，" + weapon->name() +
      #               WHT "顿时拔地弹起，如同活物一般悄然袭向$n" + WHT "！\n" NOR;
      # 
      #         ap = me->query_skill("whip") + me->query_skill("force");
      #         dp = target->query_skill("force") + target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 5 + random(ap / 4);
      #                 me->add("neili", -150);
      #                 me->start_busy(1);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                            HIR "然而$n" HIR "未能看破企图，一声惨嚎，"
      #                                            + weapon->name() + HIR "鞭端已没入体内半寸"
      #                                            "，登时连退数步！\n" NOR);
      #         } else
      #         {
      #                 me->add("neili", -100);
      #                 me->start_busy(3);
      #                 msg += CYN "可是$p" CYN "运足内力，奋力挡住了"
      #                        CYN "$P" CYN "这神鬼莫测的一击！\n"NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.LiuyueJian.Liu do
  @moduledoc """
  perform「流月剑诀」（source liuyue-jian/liu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "level_gates": [{"force", "180"}, {"liuyue-jian", "120"}], "map_gates": [{"sword", "liuyue-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "250"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的流月剑舞修为不够，难以施展", "你的真气不够，难以施展", "你没有激发流月剑舞，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "一声清啸，剑法忽变，手中" + weapon->name() + HIY
      #                 "轻轻划出，带出一条无比绚丽的剑芒，遥指$n" HIY "而去。\n" NOR", "= CYN "可是$p" CYN "并不慌乱，收敛心神，轻轻格挡开了$P"
      #                          CYN "的剑招。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
      #                                              HIR "$n" HIR "顿时目瞪口呆，一个不慎，被$N"
      #                                              HIR "精妙的剑招刺中，鲜血飞溅！\n" NOR)"]}, "damage_formula": %{"formula": "ap * 2 / 3 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
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
      # #define LIU "「" HIY "流月剑诀" NOR "」"
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
      #         if (userp(me) && ! me->query("can_perform/liuyue-jian/liu"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LIU "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的武器不对，难以施展" LIU "。\n");
      # 
      #         if (me->query_skill("force") < 180)
      #                 return notify_fail("你的内功的修为不够，难以施展" LIU "。\n");
      # 
      #         if (me->query_skill("liuyue-jian", 1) < 120)
      #                 return notify_fail("你的流月剑舞修为不够，难以施展" LIU "。\n");
      # 
      #         if (me->query("neili") < 250)
      #                 return notify_fail("你的真气不够，难以施展" LIU "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "liuyue-jian")
      #                 return notify_fail("你没有激发流月剑舞，难以施展" LIU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "一声清啸，剑法忽变，手中" + weapon->name() + HIY
      #               "轻轻划出，带出一条无比绚丽的剑芒，遥指$n" HIY "而去。\n" NOR;
      #         ap = me->query_skill("sword");
      #         dp = target->query_skill("parry");
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap * 2 / 3 + random(ap);
      #                 me->add("neili", -150);
      #                 me->start_busy(2);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
      #                                            HIR "$n" HIR "顿时目瞪口呆，一个不慎，被$N"
      #                                            HIR "精妙的剑招刺中，鲜血飞溅！\n" NOR);
      #         } else
      #         {
      #                 me->add("neili", -60);
      #                 me->start_busy(3);
      #                 msg += CYN "可是$p" CYN "并不慌乱，收敛心神，轻轻格挡开了$P"
      #                        CYN "的剑招。\n"NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

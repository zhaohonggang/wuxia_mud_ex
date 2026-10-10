defmodule Kantele.Combat.Skills.Performs.RuanhongZhusuo.Bohu do
  @moduledoc """
  perform「搏虎诀」（source ruanhong-zhusuo/bohu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "whip"}, {"dp", "force"}], "level_gates": [{"ruanhong-zhusuo", "150"}], "map_gates": [{"whip", "ruanhong-zhusuo"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，无法施展", "你的软红蛛索不够娴熟，无法施展", "你的真气不够，无法施展", "你没有激发软红蛛索，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("whip") + me->query_skill("force")", "dp_formula": "target->query_skill("force") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "一声暴喝，使出「搏虎」诀，手中" + weapon->name() +
      #                 HIY "狂舞，漫天鞭影幻作无数小圈，铺天盖地罩向$n" + HIY "！\n" NOR", "= CYN "可是$p" CYN "运足内力，奋力挡住了"
      #                          CYN "$P" CYN "这神鬼莫测的一击！\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
      #                                              HIR "只听$n" HIR "一声惨叫，" + weapon->name() + HIR
      #                                              "已在$p" + HIR "身上划出数道深可见骨的伤口，皮肉"
      #                                              "分离，鲜血飞溅，苦不堪言！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 4 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-300"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // bohu.c 搏虎诀
      # 
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define BOHU "「" HIY "搏虎诀" NOR "」"
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
      #         float improve;
      #         int lvl, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "whip";
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/ruanhong-zhusuo/bohu"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(BOHU "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "whip")
      #                 return notify_fail("你使用的武器不对，无法施展" BOHU "。\n");
      # 
      #         if ((int)me->query_skill("ruanhong-zhusuo", 1) < 150)
      #                 return notify_fail("你的软红蛛索不够娴熟，无法施展" BOHU "。\n");
      # 
      #         if (me->query("neili") < 300)
      #                 return notify_fail("你的真气不够，无法施展" BOHU "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "ruanhong-zhusuo")
      #                 return notify_fail("你没有激发软红蛛索，无法施展" BOHU "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "一声暴喝，使出「搏虎」诀，手中" + weapon->name() +
      #               HIY "狂舞，漫天鞭影幻作无数小圈，铺天盖地罩向$n" + HIY "！\n" NOR;
      # 
      #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
      #         lvl = lvl * 4 / 5;
      #         ks = keys(me->query_skills(martial));
      #         improve = 0;
      #         n = 0;
      #         //最多给予5个技能的加成
      #         for (m = 0; m < sizeof(ks); m++)
      #         {
      #             if (SKILL_D(ks[m])->valid_enable(martial))
      #             {
      #                 n += 1;
      #                 improve += (int)me->query_skill(ks[m], 1);
      #                 if (n > 4 )
      #                     break;
      #             }
      #         }
      # 
      #         improve = improve * 4 / 100 / lvl;
      # 
      #         ap = me->query_skill("whip") + me->query_skill("force");
      #         dp = target->query_skill("force") + target->query_skill("parry");
      # 
      #         ap += ap * improve;
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap / 4 + random(ap / 3);
      #                 me->add("neili", -300);
      #                 me->start_busy(1);
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
      #                                            HIR "只听$n" HIR "一声惨叫，" + weapon->name() + HIR
      #                                            "已在$p" + HIR "身上划出数道深可见骨的伤口，皮肉"
      #                                            "分离，鲜血飞溅，苦不堪言！\n" NOR);
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

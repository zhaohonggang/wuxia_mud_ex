defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Shi do
  @moduledoc """
  perform「shi」（source chousui-zhang/shi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"lvl", "chousui-zhang"}, {"lvp", "poison"}], "level_gates": [{"throwing", "180"}], "map_gates": [{"strike", "chousui-zhang"}], "prepared_gates": [{"strike", "chousui-zhang"}], "resource_gates": [{"max_neili", "1200"}, {"neili", "500"}], "var_gates": [{"lvl", "140"}, {"lvl", "200"}, {"lvl", "250"}, {"lvp", "200"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "corpse_poison", "duration_formula": "5 + random(lvp / 20)", "id_formula": "me->query("id")", "level_formula": "lvp + random(lvp)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的抽髓掌不够娴熟，难以施展", "你对毒技的了解不够，难以施展", "你暗器手法火候不够，难以施展", "你没有激发抽髓掌，难以施展", "你没有准备抽髓掌，难以施展", "你的内力修为不足，难以施展", "你现在的内息不足，难以施展", "你附近没有合适的尸体，难以施展", "你附近没有合适的尸体，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") +
      #                //me->query_skill("poison")", "dp_formula": "target->query_skill("dodge") +
      #                        //target->query_skill("parry")"}, "callback_functions": [%{"body": "//int lvp = me->query_skill("poison") * 2 / 3;
      #           int lvp = me->query_skill("poison",1);
      #   
      #           target->affect_by("corpse_poison",
      #                   ([ "level"    : lvp + random(lvp),
      #              ", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 75,
      #                                             (: final, me, target, damage :))", "= CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
      #                          "于避开了$N" CYN "掷来的尸体。\n" NOR"], "success": ["WHT "$N" WHT "随手抓起" + name + WHT "，将「"
      #                 HIR "腐尸毒" NOR + WHT"」毒质运于其上，朝$n"
      #                 WHT "猛掷而去。\n" NOR"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "do_damage_calls": [%{"attack_type": "REMOTE_ATTACK", "callback": "final", "damage_factor": 75, "damage_var": "damage"}], "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "receive_damage_calls": [%{"formula": "damage / 4", "kind": "damage", "part": "jing", "source": "me"}, %{"formula": "damage / 8", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-200"}, {"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-300"}], "affect_by": ["corpse_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define SHI "「" NOR + WHT "腐尸毒" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # string final(object me, object target, int damage);
      # 
      # int perform(object me, object target)
      # {
      #         object *corpse;
      #         int lvl, lvp, damage;
      #         int ap, dp;
      #         string name, msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/chousui-zhang/shi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SHI "只能对战斗中的对手使用。\n");
      # 
      #         if (userp(me) && (me->query_temp("weapon")
      #            || me->query_temp("secondary_weapon")))
      #                 return notify_fail(SHI "只能空手施展。\n");
      # 
      #         lvl = me->query_skill("chousui-zhang", 1);
      #         //lvp = me->query_skill("poison");
      #         lvp = me->query_skill("poison",1);
      # 
      #         if (lvl < 140)
      #                 return notify_fail("你的抽髓掌不够娴熟，难以施展" SHI "。\n");
      # 
      #         if (lvp < 200)
      #                 return notify_fail("你对毒技的了解不够，难以施展" SHI "。\n");
      # 
      #         if ((int)me->query_skill("throwing") < 180)
      #                 return notify_fail("你暗器手法火候不够，难以施展" SHI "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "chousui-zhang")
      #                 return notify_fail("你没有激发抽髓掌，难以施展" SHI "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "chousui-zhang")
      #                 return notify_fail("你没有准备抽髓掌，难以施展" SHI "。\n");
      # 
      #         if ((int)me->query("max_neili") < 1200)
      #                 return notify_fail("你的内力修为不足，难以施展" SHI "。\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #                 return notify_fail("你现在的内息不足，难以施展" SHI "。\n");
      # 
      #         corpse = filter_array(all_inventory(environment(me)),
      #                              (: base_name($1) == CORPSE_OB
      #                              && ($1->query("defeated_by") == this_player()
      #                              || ! $1->query("defeated_by")) :));
      # 
      #         //if (userp(me) && sizeof(corpse) < 1)
      #         if (userp(me) && sizeof(corpse) < 1 && lvl < 200)
      #                 return notify_fail("你附近没有合适的尸体，难以施展" SHI "。\n");
      # 
      #         // 允许等级 250 以上的任务 NPC 施展此招
      #         //if (! userp(me) && lvl < 250 && sizeof(corpse) < 1)
      #                 //return notify_fail("你附近没有合适的尸体，难以施展" SHI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         if (sizeof(corpse) >= 1)
      #                 name = corpse[0]->name();
      #         else
      #                 name = "路边的行人";
      # 
      #         msg = WHT "$N" WHT "随手抓起" + name + WHT "，将「"
      #               HIR "腐尸毒" NOR + WHT"」毒质运于其上，朝$n"
      #               WHT "猛掷而去。\n" NOR;
      # 
      #         ap = me->query_skill("strike") +
      #              //me->query_skill("poison");
      #              me->query_skill("poison",1);
      # 
      #         // 将任务NPC和玩家区分，再计算防御状况
      #         if (userp(me))
      #                 dp = target->query_skill("dodge") +
      #                      target->query_skill("martial-cognize",1);
      #         else
      #                 dp = target->query_skill("dodge") +
      #                      //target->query_skill("parry");
      #                      target->query_skill("parry",1);
      # 
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 damage = ap + random(ap / 2);
      #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 75,
      #                                           (: final, me, target, damage :));
      #                 me->start_busy(3);
      #                 me->add("neili", -300);
      #         } else
      #         {
      #                 msg += CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
      #                        "于避开了$N" CYN "掷来的尸体。\n" NOR;
      #                 me->start_busy(4);
      #                 me->add("neili", -200);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         if (sizeof(corpse) >= 1)
      #                 destruct(corpse[0]);
      # 
      #         return 1;
      # }
      # 
      # string final(object me, object target, int damage)
      # {
      #         //int lvp = me->query_skill("poison") * 2 / 3;
      #         int lvp = me->query_skill("poison",1);
      # 
      #         target->affect_by("corpse_poison",
      #                 ([ "level"    : lvp + random(lvp),
      #                    "id"       : me->query("id"),
      #                    "duration" : 5 + random(lvp / 20) ]));
      # 
      #         target->receive_damage("jing", damage / 4, me);
      #         target->receive_wound("jing", damage / 8, me);
      # 
      #         return  HIR "$n" HIR "只闻一股恶臭传来，大惊之下难以招"
      #                 "架，顿被尸体击个正中。\n" NOR;
      # }
end

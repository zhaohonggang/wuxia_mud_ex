defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Tao do
  @moduledoc """
  perform「碧焰滔天」（source chousui-zhang/tao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "poison"}, {"lvl", "chousui-zhang"}], "level_gates": [{"chousui-zhang", "220"}, {"huagong-dafa", "220"}, {"poison", "250"}], "map_gates": [], "prepared_gates": [{"strike", "chousui-zhang"}], "resource_gates": [{"max_neili", "3000"}, {"neili", "3000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "fire_poison", "duration_formula": "lvl / 20 + random(lvl)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") * 3 + random(me->query("jiali") * 2)"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你只能对战斗中的对手施展", "你的抽髓掌火候不够。\n", "你的基本毒技火候不够。\n", "你的化功大法火候不够。\n", "你的内力修为不足，无法用内力施展", "你现在内息不足，无法用内力施展", "你还没有准备抽髓掌，无法施展", "你必须将全身功力尽数提起才能施展", "你首先要拿着(hand)一些毒药作为引子。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("poison", 1) / 2 +
      #                        me->query_skill("force, 1")"}, "callback_functions": [%{"body": "if (! objectp(me))
      #                 return 1;
      #   
      #           if (living(me))
      #                 me->unconcious();
      #   
      #           return 1;", "name": "unconcious_me", "params": "object me", "return_type": "int"}], "color_codes": ["CYN", "HIG", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= WHT "$n" WHT "见状连忙提运内力，双臂猛"
      #                          "的推出，掌风澎湃，强大的气流顿时将火浪"
      #                          "刮得倒转，竟然掉头向$N" WHT "扑去。\n\n" NOR", "= CYN "$n" CYN "见势不妙，急忙腾挪身形，避开了$N" CYN "的攻击。\n" NOR"], "success": ["HIR "只见$N" HIR "双目血红，头发散乱，猛地仰天发出一声悲啸。\n\n"
      #                 "$N" HIR "把心一横，在自己舌尖狠命一咬，将毕生功力尽"
      #                 "数喷出，顿时只见空气中血雾弥漫，腥臭无比，随即又\n"
      #                 "听$N" HIR "骨骼“噼里啪啦”一阵爆响，双臂顺着喷出的"
      #                 "血柱一推，刹那间一座丈来高的奇毒火墙拔地而起，带\n"
      #                 "着排山倒海之势向$n" HIR "涌去！\n" NOR", "= HIR "$N" HIR "一声惨笑，长叹一声，眼前一黑，倒在了地上。\n\n" NOR", "= HIR "$n" HIR "见滔天热浪扑面涌来，只觉眼前一片通红，"
      #                                  "已被卷入火浪，毒焰席卷全身，连骨头都要烤焦一般。\n" NOR"]}, "damage_formula": %{"formula": "1500 + random(lvl * 3)"}, "receive_damage_calls": [%{"formula": "damage * 2", "kind": "damage", "part": "qi", "source": None}, %{"formula": "damage / 2", "kind": "damage", "part": "jing", "source": None}], "resource_adds": [{"max_neili", "-50"}, {"max_neili", "-random(50)"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"max_neili", "-50"}], "affect_by": ["fire_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(4 + random(4));", "if (! target->is_busy())", "target->start_busy(5);", "if (! target->is_busy())", "target->start_busy(10);"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - me->start_busy(4 + random(4));
      #   - if (! target->is_busy())
      #   - target->start_busy(5);
      #   - if (! target->is_busy())
      #   - target->start_busy(10);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # #define TAO "「" HIG "碧焰滔天" NOR "」"
      # 
      # int unconcious_me(object me);
      # 
      # int perform(object me, object target)
      # {
      #         object du;
      #         int damage;
      #         int ap;
      #         string msg;
      #         int lvl;
      # 
      #         if (userp(me) && ! me->query("can_perform/chousui-zhang/tao"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail("你只能对战斗中的对手施展" TAO "。\n");
      # 
      #         if ((int)me->query_skill("chousui-zhang", 1) < 220)
      #                 return notify_fail("你的抽髓掌火候不够。\n");
      # 
      #         if ((int)me->query_skill("poison", 1) < 250)
      #                 return notify_fail("你的基本毒技火候不够。\n");
      # 
      #         if ((int)me->query_skill("huagong-dafa", 1) < 220)
      #                 return notify_fail("你的化功大法火候不够。\n");
      # 
      #         if ((int)me->query("max_neili") < 3000)
      #                 return notify_fail("你的内力修为不足，无法用内力施展" TAO "。\n");
      # 
      #         if ((int)me->query("neili") < 3000)
      #                 return notify_fail("你现在内息不足，无法用内力施展" TAO "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "chousui-zhang")
      #                 return notify_fail("你还没有准备抽髓掌，无法施展" TAO "。\n");
      # 
      #         if (! me->query_temp("powerup"))
      #                 return notify_fail("你必须将全身功力尽数提起才能施展" TAO "。\n");
      # 
      #         if (! objectp(du = me->query_temp("handing")) && userp(me))
      #                 return notify_fail("你首先要拿着(hand)一些毒药作为引子。\n");
      # 
      #         if (objectp(du) && ! mapp(du->query("poison")))
      #                 return notify_fail(du->name() + "又不是毒药，无法运射出毒焰？\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "只见$N" HIR "双目血红，头发散乱，猛地仰天发出一声悲啸。\n\n"
      #               "$N" HIR "把心一横，在自己舌尖狠命一咬，将毕生功力尽"
      #               "数喷出，顿时只见空气中血雾弥漫，腥臭无比，随即又\n"
      #               "听$N" HIR "骨骼“噼里啪啦”一阵爆响，双臂顺着喷出的"
      #               "血柱一推，刹那间一座丈来高的奇毒火墙拔地而起，带\n"
      #               "着排山倒海之势向$n" HIR "涌去！\n" NOR;
      #         me->start_busy(4 + random(4));
      #         me->set("neili", 0);
      #         me->add("max_neili", -50);
      # 
      #         lvl = me->query_skill("chousui-zhang", 1);
      #         damage = 1500 + random(lvl * 3);
      # 
      #         if (me->query("max_neili") + random(me->query("max_neili")) <
      #             target->query("max_neili") * 18 / 10)
      #         {
      #                 msg += WHT "$n" WHT "见状连忙提运内力，双臂猛"
      #                        "的推出，掌风澎湃，强大的气流顿时将火浪"
      #                        "刮得倒转，竟然掉头向$N" WHT "扑去。\n\n" NOR;
      #                 msg += HIR "$N" HIR "一声惨笑，长叹一声，眼前一黑，倒在了地上。\n\n" NOR;
      #                 me->add("max_neili", -random(50));
      # 
      #                 remove_call_out("unconcious_me");
      #                 call_out("unconcious_me", 1, me);
      # 
      #         } else
      #         {
      #                 ap = me->query_skill("poison", 1) / 2 +
      #                      me->query_skill("force, 1");
      #                      //me->query_skill("force");
      #                 if (ap + random(ap) < target->query_skill("dodge"))
      #                 {
      #                         msg += CYN "$n" CYN "见势不妙，急忙腾挪身形，避开了$N" CYN "的攻击。\n" NOR;
      #                         me->add("max_neili", -random(50));
      #                         if (! target->is_busy())
      #                                 target->start_busy(5);
      #                 } else
      #                 {
      #                         msg += HIR "$n" HIR "见滔天热浪扑面涌来，只觉眼前一片通红，"
      #                                "已被卷入火浪，毒焰席卷全身，连骨头都要烤焦一般。\n" NOR;
      #                         me->add("max_neili", -random(50));
      #                         target->affect_by("fire_poison",
      #                                        ([ "level" : me->query("jiali") * 3 + random(me->query("jiali") * 2),
      #                                           "id"    : me->query("id"),
      #                                           "duration" : lvl / 20 + random(lvl) ]));
      #                         target->receive_damage("qi", damage * 2);
      #                         target->receive_damage("jing", damage / 2);
      #                         if (! target->is_busy())
      #                                 target->start_busy(10);
      #                 }
      #         }
      # 
      #         if (objectp(du)) destruct(du);
      #         message_vision(msg, me, target);
      #         me->want_kill(target);
      #         if (! target->is_killing(me)) target->kill_ob(me);
      # 
      #         return 1;
      # }
      # 
      # int unconcious_me(object me)
      # {
      #         if (! objectp(me))
      #               return 1;
      # 
      #         if (living(me))
      #               me->unconcious();
      # 
      #         return 1;
      # }
end

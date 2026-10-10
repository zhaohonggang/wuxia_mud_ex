defmodule Kantele.Combat.Skills.Performs.ShenghuoLing.Can do
  @moduledoc """
  perform「残血令」（source shenghuo-ling/can.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "shenghuo-ling"}, {"skill", "shenghuo-ling"}], "level_gates": [{"force", "350"}], "map_gates": [{"sword", "shenghuo-ling"}], "prepared_gates": [], "resource_gates": [{"max_neili", "5000"}, {"neili", "400"}], "var_gates": [{"i", "7"}, {"skill", "220"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的兵器不对，不能使用圣火令法之", "你的圣火令法等级不够, 不能使用圣火令", "你的内功火候不够，不能使用圣火令法之", "你的内力修为不足，不能使用圣火令法之", "你的内力不够，不能使用圣火令法之", "你没有激发圣火令法，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= HIY "$n" HIY "见$N" HIY "来势汹涌，心底一惊，打起精"
      #                          "神小心接招。\n" NOR"], "success": ["HIR "$N" HIR "一声长啸，手中" + weapon->name() +
      #                 HIR "一转，招数顿时变得诡异无比，从意想不到的方"
      #                 "位攻向$n" HIR "！\n" NOR", "= HIR "$n" HIR "完全无法看透$N" HIR "招中虚实，不由得心"
      #                          "生惧意，招式一滞，登时破绽百出。\n" NOR"]}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(4));
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
      # #define CANXUE "「" HIR "残血令" NOR "」"
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int count;
      #         int skill;
      #         int i;
      # 
      #         float improve;
      #         int lvl, m, n;
      #         string martial;
      #         string *ks;
      #         martial = "sword";
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/shenghuo-ling/can"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         skill = me->query_skill("shenghuo-ling", 1);
      # 
      #         if (! (me->is_fighting()))
      #                 return notify_fail(CANXUE "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你使用的兵器不对，不能使用圣火令法之"
      #                                    CANXUE "。\n");
      # 
      #         if (skill < 220)
      #                 return notify_fail("你的圣火令法等级不够, 不能使用圣火令"
      #                                    "法之" CANXUE "。\n");
      # 
      #         if (me->query_skill("force") < 350)
      #                 return notify_fail("你的内功火候不够，不能使用圣火令法之"
      #                                    CANXUE "。\n");
      # 
      #         if (me->query("max_neili") < 5000)
      #                 return notify_fail("你的内力修为不足，不能使用圣火令法之"
      #                                    CANXUE "。\n");
      # 
      #         if (me->query("neili") < 400)
      #                 return notify_fail("你的内力不够，不能使用圣火令法之" CANXUE "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "shenghuo-ling")
      #                 return notify_fail("你没有激发圣火令法，无法使用" CANXUE "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "一声长啸，手中" + weapon->name() +
      #               HIR "一转，招数顿时变得诡异无比，从意想不到的方"
      #               "位攻向$n" HIR "！\n" NOR;
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
      #         improve = improve * 5 / 100 / lvl;
      # 
      #         // 配合圣火令法本身具备的 max_hit带来额外的伤害。
      #         // 原著中该令法乃很难看透的招数，所以出现增加攻
      #         // 击的效率非常大。
      #         if (random(me->query_skill("sword")) > target->query_skill("parry") / 3)
      #         {
      #                 msg += HIR "$n" HIR "完全无法看透$N" HIR "招中虚实，不由得心"
      #                        "生惧意，招式一滞，登时破绽百出。\n" NOR;
      #                 count = me->query_skill("shenghuo-ling", 1) / 6;
      #                 me->add_temp("shenghuo-ling/max_hit", 1);
      #         } else
      #         {
      #                 msg += HIY "$n" HIY "见$N" HIY "来势汹涌，心底一惊，打起精"
      #                        "神小心接招。\n" NOR;
      #                 count = 0;
      #         }
      # 
      #         message_combatd(msg, me, target);
      #         me->add("neili", -300);
      #         me->add_temp("apply/attack", count);
      # 
      #         for (i = 0; i < 7; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(3) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->add_temp("apply/attack", -count);
      #         me->delete_temp("shenghuo-ling/max_hit");
      #         me->start_busy(1 + random(4));
      #         return 1;
      # }
end

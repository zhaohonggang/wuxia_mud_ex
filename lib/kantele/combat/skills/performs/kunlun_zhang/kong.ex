defmodule Kantele.Combat.Skills.Performs.KunlunZhang.Kong do
  @moduledoc """
  perform「日入空山」（source kunlun-zhang/kong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}, {"skill", "kunlun-zhang"}], "level_gates": [], "map_gates": [{"strike", "kunlun-zhang"}], "prepared_gates": [{"strike", "kunlun-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你两只手都拿着武器，怎么施展", "你昆仑掌法等级不够，难以施展", "你没有激发昆仑掌法，难以施展", "你没有准备昆仑掌法，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$p" CYN "的看破了$P" CYN
      #                          "的企图，巧妙的拆招，没露半点破绽"
      #                          "。\n" NOR"], "success": ["HIW "$N" HIW "陡然施出昆仑掌法绝技「" NOR + HIR "日入空山"
      #                 NOR + HIW "」，一掌猛然拍出，掌影重重叠叠，笼罩$n" HIW "四"
      #                 "面八方。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                              HIR "$n" HIR "只见$P" HIR "的无数掌影"
      #                                              "向自己压来，一时不知该如何抵挡，顿时"
      #                                              "连中数招，无暇反击。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "target->start_busy(ap / 30 + 2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1);
      #   - target->start_busy(ap / 30 + 2);
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
      # #define KONG "「" HIR "日入空山" NOR "」"
      # 
      # inherit F_SSERVER;
      #  
      # int perform(object me)
      # {
      #         string msg;
      #         object /*weapon,*/ target;
      #         int skill, ap, dp, damage;
      # 
      #         if (userp(me) && ! me->query("can_perform/kunlun-zhang/kong"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(KONG "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") && me->query_temp("secondary_weapon"))
      #                 return notify_fail("你两只手都拿着武器，怎么施展" KONG "？\n");
      # 
      #         skill = me->query_skill("kunlun-zhang", 1);
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if (skill < 120)
      #                 return notify_fail("你昆仑掌法等级不够，难以施展" KONG "。\n");
      #  
      #         if (me->query_skill_mapped("strike") != "kunlun-zhang")
      #                 return notify_fail("你没有激发昆仑掌法，难以施展" KONG "。\n");
      # 
      #         if (me->query_skill_prepared("strike") != "kunlun-zhang")
      #                 return notify_fail("你没有准备昆仑掌法，难以施展" KONG "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" KONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "陡然施出昆仑掌法绝技「" NOR + HIR "日入空山"
      #               NOR + HIW "」，一掌猛然拍出，掌影重重叠叠，笼罩$n" HIW "四"
      #               "面八方。\n" NOR;
      # 
      #         ap = me->query_skill("strike");
      #         dp = target->query_skill("parry");
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 me->add("neili", -150);
      #                 damage = ap / 3 + random(ap / 3);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                            HIR "$n" HIR "只见$P" HIR "的无数掌影"
      #                                            "向自己压来，一时不知该如何抵挡，顿时"
      #                                            "连中数招，无暇反击。\n" NOR);
      #                 me->start_busy(1);
      #                 target->start_busy(ap / 30 + 2);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
      #                        "的企图，巧妙的拆招，没露半点破绽"
      #                        "。\n" NOR;
      #                 me->add("neili", -80);
      #                 me->start_busy(3);
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

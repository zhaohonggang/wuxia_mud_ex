defmodule Kantele.Combat.Skills.Performs.LeitingFu.Sanda do
  @moduledoc """
  perform「sanda」（source leiting-fu/sanda.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hammer"}, {"damage", "leiting-fu"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "level_gates": [{"force", "200"}, {"hammer", "180"}], "map_gates": [{"hammer", "leiting-fu"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「三板斧」只能在战斗中使用。\n", "你使用的武器不对。\n", "你没有激发雷霆斧法，不能使用「三板斧」。\n", "你现在的臂力不够，目前不能使用「三板斧」！\n", "你的内功火候不够，难以施展「三板斧」！\n", "你的棍法修为不够，不会使用「三板斧」！\n", "你的真气不足！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hammer") + me->query("str") * 2", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIM", "HIR", "HIW", "NOR", "YEL"], "combat_messages": %{"fail": [], "other": [""\n" HIW "$N" HIW "喝道：劈脑袋！\n" NOR", "= CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
      #                          "所动，凝神抵挡，不漏半点破绽！\n" NOR", "= "\n" YEL "$N" YEL "喝道：鬼剔牙！\n" NOR", "= CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
      #                          "所动，凝神抵挡，不漏半点破绽！\n" NOR", "= "\n" HIM "$N" HIM "喝道：掏耳朵！\n" NOR", "= CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
      #                          "所动，凝神抵挡，不漏半点破绽！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
      #                                              HIR "$p" HIR "一楞，只见$P" HIR "身形"
      #                                              "一闪，已晃至自己跟前，躲闪不及，被这"
      #                                              "招击个正中。\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
      #                                              HIR "$p" HIR "一楞，只见$P" HIR "身形"
      #                                              "一闪，已晃至自己跟前，躲闪不及，被这"
      #                                              "招击个正中。\n" NOR)", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
      #                                              HIR "$p" HIR "一楞，只见$P" HIR "身形"
      #                                              "一闪，已晃至自己跟前，躲闪不及，被这"
      #                                              "招击个正中。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("leiting-fu", 1)"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-110"}, {"neili", "-140"}, {"neili", "-40"}, {"neili", "-55"}, {"neili", "-70"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "hammer"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-110"}, {"neili", "-140"}, {"neili", "-40"}, {"neili", "-55"}, {"neili", "-70"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // sanda.c 三板斧
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int ap, dp;
      #         int damage, count;
      #         int zhuan;
      # 
      #         zhuan = me->query("reborn/count");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! me->is_fighting())
      #             return notify_fail("「三板斧」只能在战斗中使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #                 (string)weapon->query("skill_type") != "hammer")
      #             return notify_fail("你使用的武器不对。\n");
      # 
      #         if (me->query_skill_mapped("hammer") != "leiting-fu")
      #             return notify_fail("你没有激发雷霆斧法，不能使用「三板斧」。\n");
      # 
      #         if ((int)me->query_str() < 40)
      #             return notify_fail("你现在的臂力不够，目前不能使用「三板斧」！\n");
      # 
      #         if ((int)me->query_skill("force") < 200)
      #             return notify_fail("你的内功火候不够，难以施展「三板斧」！\n");
      # 
      #         if ((int)me->query_skill("hammer", 1) < 180)
      #             return notify_fail("你的棍法修为不够，不会使用「三板斧」！\n");
      # 
      #         if ((int)me->query("neili") < 500)
      #             return notify_fail("你的真气不足！\n");
      # 
      #         if (! living(target))
      #             return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         // 第一斧劈脑袋
      #         ap = me->query_skill("hammer") + me->query("str") * 2;
      #         dp = target->query_skill("force");
      #         damage = me->query_skill("leiting-fu", 1);
      #         damage += (me->query_str() - zhuan * 20) * 2;
      #         count = me->query_str() - zhuan * 20;
      # 
      #         msg = "\n" HIW "$N" HIW "喝道：劈脑袋！\n" NOR;
      #         if (ap * 2 / 3 + random(ap) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
      #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
      #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
      #                                            "招击个正中。\n" NOR);
      #                 me->add("neili", -80);
      #         } else
      #         {
      #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
      #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
      #                 me->add("neili", -40);
      #         }
      # 
      #         // 第二斧鬼剔牙
      #         ap += me->query("dex") * 3;
      #         dp = target->query_skill("parry");
      #         damage += (me->query_dex() - zhuan * 20) * 3;
      #         count += me->query("dex") - zhuan * 20;
      #         msg += "\n" YEL "$N" YEL "喝道：鬼剔牙！\n" NOR;
      #         if (ap / 2 + random(ap * 4 / 5) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
      #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
      #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
      #                                            "招击个正中。\n" NOR);
      #                 me->add("neili", -110);
      #         } else
      #         {
      #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
      #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
      #                 me->add("neili", -55);
      #         }
      # 
      #         // 第三斧掏耳朵
      #         ap += me->query("con") * 5;
      #         dp = target->query_skill("dodge");
      #         damage += (me->query_con() - zhuan * 20) * 5;
      #         count += me->query("con") - zhuan * 20;
      #         msg += "\n" HIM "$N" HIM "喝道：掏耳朵！\n" NOR;
      #         if (ap / 3 + random(ap * 3 / 5) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, count,
      #                                            HIR "$p" HIR "一楞，只见$P" HIR "身形"
      #                                            "一闪，已晃至自己跟前，躲闪不及，被这"
      #                                            "招击个正中。\n" NOR);
      #                 me->add("neili", -140);
      #         } else
      #         {
      #                 msg += CYN "$p" CYN "冷静非凡，丝毫不为这奇幻的招数"
      #                        "所动，凝神抵挡，不漏半点破绽！\n" NOR;
      #                 me->add("neili", -70);
      #         }
      # 
      #         me->start_busy(3 + random(3));
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end

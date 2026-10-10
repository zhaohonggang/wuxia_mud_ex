defmodule Kantele.Combat.Skills.Performs.LingxiaoQuan.San do
  @moduledoc """
  perform「神倒鬼跌三连环」（source lingxiao-quan/san.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "cuff"}, {"damage", "lingxiao-quan"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "level_gates": [{"force", "250"}, {"lingxiao-quan", "180"}], "map_gates": [{"cuff", "lingxiao-quan"}], "prepared_gates": [{"cuff", "lingxiao-quan"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "只有空手才能施展", "你的内功修为不够，难以施展", "你的凌霄拳法不够娴熟，难以施展", "你现在真气不够，难以施展", "你没有激发凌霄拳法，难以施展", "你现在没有准备使用凌霄拳法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("cuff")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$p" CYN "见势不妙，急忙凝力稳住，右臂挥出，格开$P"
      #                          CYN "手臂。\n" NOR", "= CYN "可是$p" CYN "丝毫不为$P"
      #                          CYN "所动，奋力格挡，稳稳将这一招架开。\n" NOR", "= CYN "然而$p" CYN "沉身聚气，稳住下盘，身子一幌，没给$P"
      #                          CYN "绊倒。\n" NOR"], "success": ["HIR "$N" HIR "微微一笑，施出「神倒鬼跌三连环」，右手探出，直揪$n"
      #                 HIR "后颈。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                              HIR "$P" HIR "出手既快，方位又奇，$p"
      #                                              HIR "如何避得，当即被$N" HIR "揪住，"
      #                                              "重重的摔在地上！\n" NOR)", "= "\n" HIR "紧接着$N" HIR "“噫”的一声，左手猛然探出，如闪电般抓向$n"
      #                  HIR "的前胸。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
      #                                              HIR "$p" HIR "只觉胸口一麻，已被$P"
      #                                              HIR "抓住胸口，用力顺势一甩，顿时平"
      #                                              "平飞了出去！\n" NOR)", "= "\n" HIR "又见$N" HIR "身子一矮，将力道聚于腿部，右脚猛扫$n"
      #                  HIR "下盘，左脚随着绊去。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "结果$p" HIR "稍不留神，顿时给$P"
      #                                              HIR "绊倒在地，呕出一大口鲜血！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("lingxiao-quan", 1) / 2"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define SAN "「" HIR "神倒鬼跌三连环" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      #         object weapon;
      # //      string wname;
      #         int ap, dp;
      # 
      #         if (userp(me) && ! me->query("can_perform/lingxiao-quan/san"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(SAN "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(weapon = me->query_temp("weapon")))
      #                 return notify_fail("只有空手才能施展" SAN "。\n");
      # 
      #         if (me->query_skill("force") < 250)
      #                 return notify_fail("你的内功修为不够，难以施展" SAN "。\n");
      # 
      #         if ((int)me->query_skill("lingxiao-quan", 1) < 180)
      #                 return notify_fail("你的凌霄拳法不够娴熟，难以施展" SAN "。\n");
      # 
      #         if ((int)me->query("neili") < 300)
      #                 return notify_fail("你现在真气不够，难以施展" SAN "。\n");
      # 
      #         if (me->query_skill_mapped("cuff") != "lingxiao-quan")
      #                 return notify_fail("你没有激发凌霄拳法，难以施展" SAN "。\n");
      # 
      #         if (me->query_skill_prepared("cuff") != "lingxiao-quan")
      #                 return notify_fail("你现在没有准备使用凌霄拳法，难以施展" SAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         damage = (int)me->query_skill("lingxiao-quan", 1) / 2;
      #         damage += random(damage);
      # 
      #         ap = me->query_skill("cuff");
      #         dp = target->query_skill("parry");
      #         msg = HIR "$N" HIR "微微一笑，施出「神倒鬼跌三连环」，右手探出，直揪$n"
      #               HIR "后颈。\n" NOR;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
      #                                            HIR "$P" HIR "出手既快，方位又奇，$p"
      #                                            HIR "如何避得，当即被$N" HIR "揪住，"
      #                                            "重重的摔在地上！\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "$p" CYN "见势不妙，急忙凝力稳住，右臂挥出，格开$P"
      #                        CYN "手臂。\n" NOR;
      #         }
      # 
      #         ap = me->query_skill("cuff");
      #         dp = target->query_skill("dodge");
      #         msg += "\n" HIR "紧接着$N" HIR "“噫”的一声，左手猛然探出，如闪电般抓向$n"
      #                HIR "的前胸。\n" NOR;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
      #                                            HIR "$p" HIR "只觉胸口一麻，已被$P"
      #                                            HIR "抓住胸口，用力顺势一甩，顿时平"
      #                                            "平飞了出去！\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "可是$p" CYN "丝毫不为$P"
      #                        CYN "所动，奋力格挡，稳稳将这一招架开。\n" NOR;
      #         }
      # 
      #         ap = me->query_skill("cuff");
      #         dp = target->query_skill("force");
      #         msg += "\n" HIR "又见$N" HIR "身子一矮，将力道聚于腿部，右脚猛扫$n"
      #                HIR "下盘，左脚随着绊去。\n" NOR;
      #         if (ap / 2 + random(ap) > dp)
      #         {
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                            HIR "结果$p" HIR "稍不留神，顿时给$P"
      #                                            HIR "绊倒在地，呕出一大口鲜血！\n" NOR);
      #         } else
      #         {
      #                 msg += CYN "然而$p" CYN "沉身聚气，稳住下盘，身子一幌，没给$P"
      #                        CYN "绊倒。\n" NOR;
      #         }
      #         me->start_busy(2 + random(3));
      #         me->add("neili", -200);
      #         message_combatd(msg, me, target);
      #         return 1;
      # }
end

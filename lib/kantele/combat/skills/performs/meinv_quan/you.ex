defmodule Kantele.Combat.Skills.Performs.MeinvQuan.You do
  @moduledoc """
  perform「古墓幽居」（source meinv-quan/you.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "unarmed"}], "level_gates": [{"force", "120"}, {"meinv-quan", "80"}], "map_gates": [{"unarmed", "meinv-quan"}], "prepared_gates": [{"unarmed", "meinv-quan"}], "resource_gates": [{"neili", "180"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能施展", "你的美女拳法别不够，不会使用", "你的内功还未娴熟，不能使用", "你现在真气不够，不能使用", "你没有激发美女拳法，不能施展", "你没有准备美女拳法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "右手支颐，左袖轻轻挥出，长叹一声，使"
      #                 "出古墓派绝学「古墓幽居」，一脸尽现寂寥之意。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN
      #                          "的企图，稳如泰山，抬手一架格开了$P"
      #                          CYN "这一拳。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                              HIR "但见$N" HIR "双拳袭来，柔中带刚，迅"
      #                                              "猛无比，其间仿佛蕴藏着无穷的威力，$n" HIR
      #                                              "正迟疑间， $N" HIR "却已中拳，闷哼一声，倒"
      #                                              "退几步，一口鲜血喷出。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("unarmed")"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["//me->start_busy(2 + random(2));", "me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - //me->start_busy(2 + random(2));
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
      # #define YOU "「" HIG "古墓幽居" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int damage;
      #         string msg;
      # //      string pmsg;
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (userp(me) && ! me->query("can_perform/meinv-quan/you"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(YOU "只能对战斗中的对手使用。\n");
      # 
      #     if (me->query_temp("weapon"))
      #         return notify_fail("你必须空手才能施展" YOU "。\n");
      # 
      #         if ((int)me->query_skill("meinv-quan", 1) < 80)
      #                 return notify_fail("你的美女拳法别不够，不会使用" YOU "。\n");
      # 
      #         if ((int)me->query_skill("force") < 120)
      #                 return notify_fail("你的内功还未娴熟，不能使用" YOU "。\n");
      # 
      #         if ((int)me->query("neili") < 180)
      #                 return notify_fail("你现在真气不够，不能使用" YOU "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "meinv-quan")
      #                 return notify_fail("你没有激发美女拳法，不能施展" YOU "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "meinv-quan")
      #                 return notify_fail("你没有准备美女拳法，难以施展" YOU "。\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "\n$N" HIW "右手支颐，左袖轻轻挥出，长叹一声，使"
      #               "出古墓派绝学「古墓幽居」，一脸尽现寂寥之意。\n" NOR;
      # 
      #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
      #         {
      #                 //me->start_busy(2 + random(2));
      #                 me->start_busy(2);
      # 
      #                 damage = (int)me->query_skill("unarmed");
      #                 damage = damage / 2 + random(damage / 2);
      # 
      #                 me->add("neili", -100);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
      #                                            HIR "但见$N" HIR "双拳袭来，柔中带刚，迅"
      #                                            "猛无比，其间仿佛蕴藏着无穷的威力，$n" HIR
      #                                            "正迟疑间， $N" HIR "却已中拳，闷哼一声，倒"
      #                                            "退几步，一口鲜血喷出。\n" NOR);
      #         } else
      #         {
      #                 me->start_busy(3);
      #                 msg += CYN "可是$p" CYN "看破了$P" CYN
      #                        "的企图，稳如泰山，抬手一架格开了$P"
      #                        CYN "这一拳。\n"NOR;
      #         }
      #         message_sort(msg, me, target);
      # 
      #         return 1;
      # }
end

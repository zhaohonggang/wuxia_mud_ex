defmodule Kantele.Combat.Skills.Performs.XuangongQuan.Xuan do
  @moduledoc """
  perform「玄功无极劲」（source xuangong-quan/xuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "xuangong-quan"}, {"skill", "xuangong-quan"}], "level_gates": [], "map_gates": [{"unarmed", "xuangong-quan"}], "prepared_gates": [{"unarmed", "xuangong-quan"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的无极玄功拳等级不够，难以施展", "你的真气不够，难以施展", "你没有激发无极玄功拳，难以施展", "你现在没有准备使用无极玄功拳，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "双手回圈，慢慢的引动气流，正当$n"
      #                 HIW "吃惊间，$P" HIW "双拳已陡然破空贯出。\n" NOR", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，并没有上当。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "$n" HIR "急忙抽身躲避，可已然不及，被$N"
      #                                              HIR "双拳捶个正中。\n:内伤@?")"]}, "damage_formula": %{"formula": "(int)me->query_skill("xuangong-quan", 1)"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - target->start_busy(random(3));
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
      # #define XUAN "「" HIW "玄功无极劲" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         int skill/*, ap, dp*/, damage;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/xuangong-quan/xuan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(XUAN "只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
      #                 return notify_fail(XUAN "只能空手施展。\n");
      # 
      #         skill = me->query_skill("xuangong-quan", 1);
      # 
      #         if (skill < 120)
      #                 return notify_fail("你的无极玄功拳等级不够，难以施展" XUAN "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你的真气不够，难以施展" XUAN "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "xuangong-quan")
      #                 return notify_fail("你没有激发无极玄功拳，难以施展" XUAN "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "xuangong-quan")
      #                 return notify_fail("你现在没有准备使用无极玄功拳，无法使用" XUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "只见$N" HIW "双手回圈，慢慢的引动气流，正当$n"
      #               HIW "吃惊间，$P" HIW "双拳已陡然破空贯出。\n" NOR;
      #     me->add("neili", -100);
      # 
      #     if (random(me->query_skill("force")) > target->query_skill("force") / 2)
      #     {
      #         me->start_busy(3);
      #         target->start_busy(random(3));
      # 
      #         damage = (int)me->query_skill("xuangong-quan", 1);
      #                 damage = damage + random(damage);
      # 
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                            HIR "$n" HIR "急忙抽身躲避，可已然不及，被$N"
      #                                            HIR "双拳捶个正中。\n:内伤@?");
      #     } else
      #     {
      #         me->start_busy(3);
      #         msg += CYN "可是$p" CYN "看破了$P"
      #                        CYN "的企图，并没有上当。\n" NOR;
      #     }
      #     message_combatd(msg, me, target);
      #     return 1;
      # }
end

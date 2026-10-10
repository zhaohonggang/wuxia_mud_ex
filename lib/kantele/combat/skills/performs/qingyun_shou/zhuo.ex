defmodule Kantele.Combat.Skills.Performs.QingyunShou.Zhuo do
  @moduledoc """
  perform「捕风捉影」（source qingyun-shou/zhuo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "hand"}], "level_gates": [{"force", "100"}, {"qingyun-shou", "50"}], "map_gates": [{"hand", "qingyun-shou"}], "prepared_gates": [{"hand", "qingyun-shou"}], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的青云手不够娴熟，难以施展", "你的内功修为不够，难以施展", "你现在真气不够，难以施展", "你没有激发青云手，难以施展", "你现在没有准备使用青云手，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "划身错步，单手拂过，手影虚虚实实，难辨真伪，完"
      #                 "全笼罩$n" WHT "。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "这一招，斜斜一跃避开。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                              HIR "$p" HIR "一时辨别不清虚实，被$P"
      #                                              HIR "手影划过气门，气血翻滚，几乎窒息。\n" NOR)"]}, "damage_formula": %{"formula": "me->query_skill("hand")"}, "resource_adds": [{"neili", "-30"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
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
      # #define ZHUO "「" WHT "捕风捉影" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //      object weapon;
      #         int damage;
      #         string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/qingyun-shou/zhuo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(ZHUO "只能对战斗中的对手使用。\n");
      # 
      #         if ((int)me->query_skill("qingyun-shou", 1) < 50)
      #                 return notify_fail("你的青云手不够娴熟，难以施展" ZHUO "。\n");
      # 
      #         if ((int)me->query_skill("force") < 100)
      #                 return notify_fail("你的内功修为不够，难以施展" ZHUO "。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在真气不够，难以施展" ZHUO "。\n");
      # 
      #         if (me->query_skill_mapped("hand") != "qingyun-shou")
      #                 return notify_fail("你没有激发青云手，难以施展" ZHUO "。\n");
      # 
      #         if (me->query_skill_prepared("hand") != "qingyun-shou")
      #                 return notify_fail("你现在没有准备使用青云手，难以施展" ZHUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = WHT "$N" WHT "划身错步，单手拂过，手影虚虚实实，难辨真伪，完"
      #               "全笼罩$n" WHT "。\n" NOR;
      # 
      #         if (random(me->query_skill("hand")) > target->query_skill("dodge") / 2)
      #         {
      #                 me->start_busy(2);
      #                 damage = me->query_skill("hand");
      #                 damage = damage / 3 + random(damage / 3);
      #                 me->add("neili", -50);
      #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                            HIR "$p" HIR "一时辨别不清虚实，被$P"
      #                                            HIR "手影划过气门，气血翻滚，几乎窒息。\n" NOR);
      #         } else
      #         {
      #                 me->start_busy(3);
      #                 me->add("neili", -30);
      #                 msg += CYN "可是$p" CYN "识破了$P"
      #                        CYN "这一招，斜斜一跃避开。\n" NOR;
      #         }
      #         message_combatd(msg, me, target);
      # 
      #         return 1;
      # }
end

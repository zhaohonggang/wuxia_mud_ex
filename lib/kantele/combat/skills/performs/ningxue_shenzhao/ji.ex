defmodule Kantele.Combat.Skills.Performs.NingxueShenzhao.Ji do
  @moduledoc """
  perform「ji」（source ningxue-shenzhao/ji.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "ningxue-shenzhao"}], "level_gates": [{"force", "350"}], "map_gates": [], "prepared_gates": [{"claw", "ningxue-shenzhao"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "500"}], "var_gates": [{"i", "7"}, {"skill", "250"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你还不会使用这一招！\n", "「疾电」只能对战斗中的对手使用。\n", "你没有准备使用凝血神爪，无法施展「疾电」。\n", "你的凝血神爪修为有限，无法使用「疾电」！\n", "你的内功火候不够，难以施展「疾电」！\n", "你的内力修为没有达到那个境界，无法运转内力形成「疾电」！\n", "你的真气不够，现在无法施展「疾电」！\n", "你必须是空手才能施展「疾电」！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "$N" HIR "仰天一声长啸，飞身跃起，双爪幻出漫天爪影，气势恢弘，宛如疾电一般笼罩$n" HIR "各处要穴！\n" NOR"]}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["dodge", "parry"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // ji.c 疾电
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         // mapping prepare;
      #         string msg;
      #         int skill;
      #         int delta;
      #         int i;
      # 
      #         if (! target)
      #         {
      #                 me->clean_up_enemy();
      #                 target = me->select_opponent();
      #         }
      # 
      #         if (userp(me) && ! me->query("can_perform/ningxue-shenzhao/ji"))
      #                 return notify_fail("你还不会使用这一招！\n");
      # 
      #         if (! me->is_fighting(target))
      #                 return notify_fail("「疾电」只能对战斗中的对手使用。\n");
      # 
      #         if (me->query_skill_prepared("claw") != "ningxue-shenzhao")
      #                 return notify_fail("你没有准备使用凝血神爪，无法施展「疾电」。\n");
      # 
      #         skill = me->query_skill("ningxue-shenzhao", 1);
      # 
      #         if (skill < 250)
      #                 return notify_fail("你的凝血神爪修为有限，无法使用「疾电」！\n");
      # 
      #         if (me->query_skill("force") < 350)
      #                 return notify_fail("你的内功火候不够，难以施展「疾电」！\n");
      # 
      #         if (me->query("max_neili") < 5000)
      #                 return notify_fail("你的内力修为没有达到那个境界，无法运转内力形成「疾电」！\n");
      # 
      #         if (me->query("neili") < 500)
      #                 return notify_fail("你的真气不够，现在无法施展「疾电」！\n");
      # 
      #         if (me->query_temp("weapon"))
      #                 return notify_fail("你必须是空手才能施展「疾电」！\n");
      # 
      #        if (! living(target))
      #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIR "$N" HIR "仰天一声长啸，飞身跃起，双爪幻出漫天爪影，气势恢弘，宛如疾电一般笼罩$n" HIR "各处要穴！\n" NOR;
      # 
      #         message_combatd(msg, me, target);
      # 
      #         me->add("neili", -300);
      #         target->add_temp("apply/parry", delta);
      #         target->add_temp("apply/dodge", delta);
      #         for (i = 0; i < 7; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(3) == 1 && ! target->is_busy())
      #                         target->start_busy(1);
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      #         target->add_temp("apply/parry", -delta);
      #         target->add_temp("apply/dodge", -delta);
      #         me->start_busy(1 + random(5));
      # 
      #         return 1;
      # }
end

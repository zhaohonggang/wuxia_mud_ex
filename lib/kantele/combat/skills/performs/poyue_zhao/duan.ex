defmodule Kantele.Combat.Skills.Performs.PoyueZhao.Duan do
  @moduledoc """
  perform「断脉破岳」（source poyue-zhao/duan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"poyue-zhao", "80"}], "map_gates": [{"claw", "poyue-zhao"}], "prepared_gates": [{"claw", "poyue-zhao"}], "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你破岳神爪不够娴熟，难以施展", "你没有激发破岳神爪，难以施展", "你没有准备破岳神爪，难以施展", "施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "霎时间只见$N" HIY "身形一展，双爪疾攻而上，爪影笼罩$n"
      #                 HIY "全身各处要穴。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
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
      # #define DUAN "「" HIY "断脉破岳" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/poyue-zhao/duan"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(DUAN "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail(DUAN "只能空手施展。\n");
      # 
      #         if ((int)me->query_skill("poyue-zhao", 1) < 80)
      #                 return notify_fail("你破岳神爪不够娴熟，难以施展" DUAN "。\n");
      # 
      #         if (me->query_skill_mapped("claw") != "poyue-zhao")
      #                 return notify_fail("你没有激发破岳神爪，难以施展" DUAN "。\n");
      # 
      #         if (me->query_skill_prepared("claw") != "poyue-zhao")
      #                 return notify_fail("你没有准备破岳神爪，难以施展" DUAN "。\n");
      # 
      #         // 至于NPC么…这个…还是用互背的好，互背时把CLAW提前就行了。
      #         if (userp(me) && me->query_skill_prepared("cuff") == "zhenyu-quan")
      #                 return notify_fail("施展" DUAN "时破岳神爪不谊和镇狱拳法互背。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在真气不足，难以施展" DUAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "霎时间只见$N" HIY "身形一展，双爪疾攻而上，爪影笼罩$n"
      #               HIY "全身各处要穴。\n" NOR;
      #         message_combatd(msg, me, target);
      #         me->add("neili", -50);
      # 
      #         for (i = 0; i < 4; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      #         me->start_busy(1 + random(4));
      #         return 1;
      # }
end

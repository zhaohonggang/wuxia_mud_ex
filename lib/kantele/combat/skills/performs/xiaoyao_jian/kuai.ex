defmodule Kantele.Combat.Skills.Performs.XiaoyaoJian.Kuai do
  @moduledoc """
  perform「快剑诀」（source xiaoyao-jian/kuai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"xiaoyao-jian", "120"}], "map_gates": [{"sword", "xiaoyao-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的逍遥剑法不够娴熟，难以施展", "你没有激发逍遥剑法，难以施展", "你目前的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["HIM", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "蓦的一声清啸，施出绝学「" HIM "快剑诀"
      #                 HIW "」，手中" + weapon->name() + HIW "呼呼作响。霎时间"
      #                 "奇妙的剑招连绵涌出。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-attack_time * 30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (! target->is_busy() && random(3) == 1)", "target->start_busy(1);", "me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (! target->is_busy() && random(3) == 1)
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(attack_time));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define LIAN "「" HIM "快剑诀" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     object weapon;
      #     string msg;
      #     int ap, dp;
      #         int i, attack_time;
      # 
      #         if (userp(me) && ! me->query("can_perform/xiaoyao-jian/kuai"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #     if (! target) target = offensive_target(me);
      # 
      #     if (! target || ! me->is_fighting(target))
      #                 return notify_fail(LIAN "只能对战斗中的对手使用。\n");
      # 
      #     if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" LIAN "。\n");
      # 
      #     if ((int)me->query_skill("xiaoyao-jian", 1) < 120)
      #         return notify_fail("你的逍遥剑法不够娴熟，难以施展" LIAN "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "xiaoyao-jian")
      #                 return notify_fail("你没有激发逍遥剑法，难以施展" LIAN "。\n");
      # 
      #     if (me->query("neili") < 300)
      #         return notify_fail("你目前的真气不够，难以施展" LIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIW "\n$N" HIW "蓦的一声清啸，施出绝学「" HIM "快剑诀"
      #               HIW "」，手中" + weapon->name() + HIW "呼呼作响。霎时间"
      #               "奇妙的剑招连绵涌出。\n" NOR;
      # 
      #         attack_time = 4;
      # 
      #     ap = me->query_skill("sword");
      #     dp = target->query_skill("dodge");
      # 
      #         attack_time += random(ap / 40);
      # 
      #         if (attack_time > 9)
      #                 attack_time = 9;
      # 
      #     me->add("neili", -attack_time * 30);
      #         me->add_temp("apply/attack", 20);
      # 
      #         message_combatd(msg, me, target);
      # 
      #         for (i = 0; i < attack_time; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 if (! target->is_busy() && random(3) == 1)
      #                         target->start_busy(1);
      # 
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #     me->start_busy(1 + random(attack_time));
      #         me->add_temp("apply/attack", -20);
      # 
      #         return 1;
      # }
end

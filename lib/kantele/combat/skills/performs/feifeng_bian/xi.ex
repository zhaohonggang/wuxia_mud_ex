defmodule Kantele.Combat.Skills.Performs.FeifengBian.Xi do
  @moduledoc """
  perform「凤栖于梧」（source feifeng-bian/xi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"feifeng-bian", "120"}, {"force", "150"}], "map_gates": [{"whip", "feifeng-bian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的飞凤鞭法法不够娴熟，难以施展", "你现在没有激发飞凤鞭法，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "力贯鞭梢，手中" + weapon->name() + HIW "急舞，画"
      #                 "出一个又一个的圈子缠向$n" HIW "！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(5) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(5) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define XI "「" HIW "凤栖于梧" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/feifeng-bian/xi"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(XI "只能对战斗中的对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #             (string)weapon->query("skill_type") != "whip")
      #                 return notify_fail("你使用的武器不对，难以施展" XI "。\n");
      # 
      #     if ((int)me->query_skill("feifeng-bian", 1) < 120)
      #         return notify_fail("你的飞凤鞭法法不够娴熟，难以施展" XI "。\n");
      # 
      #         if (me->query_skill_mapped("whip") != "feifeng-bian")
      #                 return notify_fail("你现在没有激发飞凤鞭法，难以施展" XI "。\n");
      # 
      #     if ((int)me->query_skill("force") < 150)
      #         return notify_fail("你的内功修为不够，难以施展" XI "。\n");
      # 
      #     if ((int)me->query("neili") < 300)
      #         return notify_fail("你现在的真气不够，难以施展" XI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIW "$N" HIW "力贯鞭梢，手中" + weapon->name() + HIW "急舞，画"
      #               "出一个又一个的圈子缠向$n" HIW "！\n" NOR;
      #         message_combatd(msg, me, target);
      # 
      #         me->add("neili", -100);
      # 
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 if (random(5) == 0 && ! target->is_busy())
      #                         target->start_busy(1);
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->start_busy(1 + random(6));
      #         return 1;
      # }
end

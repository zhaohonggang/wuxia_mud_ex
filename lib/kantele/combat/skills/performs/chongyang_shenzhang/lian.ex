defmodule Kantele.Combat.Skills.Performs.ChongyangShenzhang.Lian do
  @moduledoc """
  perform「重阳连环掌」（source chongyang-shenzhang/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"chongyang-shenzhang", "100"}, {"force", "120"}], "map_gates": [{"strike", "chongyang-shenzhang"}], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你重阳神掌不够娴熟，难以施展", "你没有激发重阳神掌，难以施展", "你没有准备重阳神掌，难以施展", "你的内功火候不够，难以施展", "你目前的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIY "$N" HIY "大喝一声，施出「" HIR "重阳连环掌" HIY "」，顿"
      #                 "时双掌纷飞，向$n" HIY "猛攻而去。\n" NOR"]}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": ["action_flag"]}
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
      # #define LIAN "「" HIR "重阳连环掌" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      # //    object weapon;
      #         string msg;
      #         mapping p;
      #         int i, af;
      # 
      #         if (userp(me) && ! me->query("can_perform/chongyang-shenzhang/lian"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target)
      #         {
      #             me->clean_up_enemy();
      #             target = me->select_opponent();
      #         }
      # 
      #     if (! target || ! me->is_fighting(target))
      #         return notify_fail(LIAN "只能对战斗中的对手使用。\n");
      # 
      #     if (objectp(me->query_temp("weapon")))
      #                 return notify_fail(LIAN "只能空手施展。\n");
      # 
      #     if ((int)me->query_skill("chongyang-shenzhang", 1) < 100)
      #         return notify_fail("你重阳神掌不够娴熟，难以施展" LIAN "。\n");
      # 
      #         if (me->query_skill_mapped("strike") != "chongyang-shenzhang")
      #                 return notify_fail("你没有激发重阳神掌，难以施展" LIAN "。\n");
      # 
      #         if (! mapp(p = me->query_skill_prepare())
      #            || p["strike"] != "chongyang-shenzhang")
      #                 return notify_fail("你没有准备重阳神掌，难以施展" LIAN "。\n");
      # 
      #     if ((int)me->query_skill("force") < 120)
      #         return notify_fail("你的内功火候不够，难以施展" LIAN "。\n");
      # 
      #     if ((int)me->query("neili") < 100)
      #         return notify_fail("你目前的真气不足，难以施展" LIAN "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = HIY "$N" HIY "大喝一声，施出「" HIR "重阳连环掌" HIY "」，顿"
      #               "时双掌纷飞，向$n" HIY "猛攻而去。\n" NOR;
      #     message_combatd(msg, me, target);
      #     me->add("neili", -80);
      # 
      #         af = member_array("strike", keys(p));
      # 
      #         for (i = 0; i < 4; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      # 
      #                 me->set_temp("action_flag", af);
      #             COMBAT_D->do_attack(me, target, 0, 0);
      #         }
      # 
      #     me->start_busy(1 + random(4));
      #     return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.QishiJi.Chong do
  @moduledoc """
  perform「冲刺攻击」（source qishi-ji/chong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "150"}, {"qishi-ji", "100"}], "map_gates": [{"club", "qishi-ji"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你圣骑士戟修为不够，难以施展", "你没有激发圣骑士戟，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "狂哮一声，手中" + weapon->name() + HIY "接连六"
      #                 "刺，竟似幻作六道电光，尽数刺向$n" HIY "！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
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
      # #define CHONG "「" HIY "冲刺攻击" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int i;
      # 
      #         if (userp(me) && ! me->query("can_perform/qishi-ji/chong"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(CHONG "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon")) ||
      #               (string)weapon->query("skill_type") != "club")
      #                 return notify_fail("你所使用的武器不对，难以施展" CHONG "。\n");
      # 
      #         if (me->query_skill("qishi-ji", 1) < 100)
      #                 return notify_fail("你圣骑士戟修为不够，难以施展" CHONG "。\n");
      # 
      #         if (me->query_skill_mapped("club") != "qishi-ji")
      #                 return notify_fail("你没有激发圣骑士戟，难以施展" CHONG "。\n");
      # 
      #         if (me->query_skill("force") < 150)
      #                 return notify_fail("你的内功修为不够，难以施展" CHONG "。\n");
      # 
      #         if (me->query("neili") < 200)
      #                 return notify_fail("你现在的真气不够，难以施展" CHONG "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         msg = HIY "$N" HIY "狂哮一声，手中" + weapon->name() + HIY "接连六"
      #               "刺，竟似幻作六道电光，尽数刺向$n" HIY "！\n" NOR;
      # 
      #         message_combatd(msg, me, target);
      #         me->add("neili", -100);
      # 
      #         for (i = 0; i < 6; i++)
      #         {
      #                 if (! me->is_fighting(target))
      #                         break;
      #                 COMBAT_D->do_attack(me, target, weapon, 0);
      #         }
      # 
      #         me->start_busy(1 + random(6));
      # 
      #         return 1;
      # }
end

defmodule Kantele.Combat.Skills.Performs.YunvJian.Mei do
  @moduledoc """
  perform「千姿百媚」（source yunv-jian/mei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "yunv-jian"}], "level_gates": [{"dodge", "60"}, {"yunv-jian", "40"}], "map_gates": [{"sword", "yunv-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "60"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你玉女剑法不够娴熟，难以施展", "你没有激发玉女剑法，难以施展", "你的轻功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIM", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "陡然间姿态万千，身法飘逸，犹如一个婀娜"
      #                 "多姿的女子在随歌漫舞一样。但是$N手中" + wn + HIC "却"
      #                 "跟随着身体轻盈地晃动，看似毫无章法，却又像是隐藏着厉"
      #                 "害的招式。" NOR", "HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
      #                         "护住自己全身，一时竟无以应对！\n" NOR", "CYN "可是$N" CYN "看出了$n" CYN "这招乃虚招，顿"
      #                         "时一丝不乱，镇定自若。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["target->start_busy(2 + random(level / 24));", "me->start_busy(random(2));", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - target->start_busy(2 + random(level / 24));
      #   - me->start_busy(random(2));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <combat.h>
      # 
      # #define MEI "「" HIM "千姿百媚" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #         string msg, wn;
      #         object weapon;
      #         int level;
      # 
      #         me = this_player();
      # 
      #         if (userp(me) && ! me->query("can_perform/yunv-jian/mei"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(MEI "只能在战斗中对对手使用。\n");
      # 
      #         if (! objectp(weapon = me->query_temp("weapon"))
      #            || (string)weapon->query("skill_type") != "sword")
      #                 return notify_fail("你所使用的武器不对，难以施展" MEI "。\n");
      # 
      #         if ((int)me->query_skill("yunv-jian", 1) < 40)
      #                 return notify_fail("你玉女剑法不够娴熟，难以施展" MEI "。\n");
      # 
      #         if (me->query_skill_mapped("sword") != "yunv-jian")
      #                 return notify_fail("你没有激发玉女剑法，难以施展" MEI "。\n");
      # 
      #         if ((int)me->query_skill("dodge") < 60)
      #                 return notify_fail("你的轻功修为不够，难以施展" MEI "。\n");
      # 
      #         if ((int)me->query("neili") < 60)
      #                 return notify_fail("你现在的真气不够，难以施展" MEI "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #         wn = weapon->name();
      # 
      #         msg = HIC "\n$N" HIC "陡然间姿态万千，身法飘逸，犹如一个婀娜"
      #               "多姿的女子在随歌漫舞一样。但是$N手中" + wn + HIC "却"
      #               "跟随着身体轻盈地晃动，看似毫无章法，却又像是隐藏着厉"
      #               "害的招式。" NOR;
      # 
      #         message_sort(msg, me, target);
      # 
      #         level = me->query_skill("yunv-jian", 1);
      #         me->add("neili", -50);
      #         if (level / 2 + random(level) > target->query_skill("dodge", 1))
      #         {
      #         msg = HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
      #                       "护住自己全身，一时竟无以应对！\n" NOR;
      #                 target->start_busy(2 + random(level / 24));
      #                 me->start_busy(random(2));
      #     } else
      #         {
      #         msg = CYN "可是$N" CYN "看出了$n" CYN "这招乃虚招，顿"
      #                       "时一丝不乱，镇定自若。\n" NOR;
      # 
      #                 me->start_busy(2);
      #     }
      #     message_combatd(msg, target, me);
      # 
      #     return 1;
      # }
end

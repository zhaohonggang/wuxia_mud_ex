defmodule Kantele.Combat.Skills.Performs.KongmingQuan.Ruo do
  @moduledoc """
  perform「空明若玄」（source kongming-quan/ruo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "kongming-quan"}], "level_gates": [{"kongming-quan", "100"}], "map_gates": [{"unarmed", "kongming-quan"}], "prepared_gates": [{"unarmed", "kongming-quan"}], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的空明拳不够娴熟，难以施展", "你没有激发空明拳，难以施展", "你没有准备空明拳，难以施展", "你现在的真气太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "使出空明拳「" HIG "空明若玄" NOR + WHT "」，双手"
      #                 "吞吐不定，运转如意，试图扰乱$n" WHT "的攻势。\n" NOR", "= CYN "可是$p" CYN "看破了$P" CYN "的企图，镇定逾"
      #                          "恒，全神应对自如。\n" NOR"], "success": ["= HIR "结果$n" HIR "被$N" HIR "的拳招所牵制，招架"
      #                          "不迭，全然无法反击！\n" NOR"]}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(level / 16 + 2);", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(level / 16 + 2);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # 
      # #define RUO "「" HIG "空明若玄" NOR "」"
      # 
      # inherit F_SSERVER;
      # 
      # int perform(object me, object target)
      # {
      #     int level;
      #     string msg;
      # 
      #         if (userp(me) && ! me->query("can_perform/kongming-quan/ruo"))
      #                 return notify_fail("你所使用的外功中没有这种功能。\n");
      # 
      #         if (! target) target = offensive_target(me);
      # 
      #         if (! target || ! me->is_fighting(target))
      #                 return notify_fail(RUO "只能对战斗中的对手使用。\n");
      # 
      #         if (objectp(me->query_temp("weapon")))
      #                 return notify_fail(RUO "只能空手施展。\n");
      # 
      #         if (target->is_busy())
      #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
      # 
      #         if ((level = me->query_skill("kongming-quan", 1)) < 100)
      #                 return notify_fail("你的空明拳不够娴熟，难以施展" RUO "。\n");
      # 
      #         if (me->query_skill_mapped("unarmed") != "kongming-quan")
      #                 return notify_fail("你没有激发空明拳，难以施展" RUO "。\n");
      # 
      #         if (me->query_skill_prepared("unarmed") != "kongming-quan")
      #                 return notify_fail("你没有准备空明拳，难以施展" RUO "。\n");
      # 
      #         if ((int)me->query("neili", 1) < 100)
      #                 return notify_fail("你现在的真气太弱，难以施展" RUO "。\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      # 
      #     msg = WHT "$N" WHT "使出空明拳「" HIG "空明若玄" NOR + WHT "」，双手"
      #               "吞吐不定，运转如意，试图扰乱$n" WHT "的攻势。\n" NOR;
      # 
      #         me->add("neili", -50);
      #         if (random(level) > (int)target->query_skill("parry", 1) / 2)
      #         {
      #         msg += HIR "结果$n" HIR "被$N" HIR "的拳招所牵制，招架"
      #                        "不迭，全然无法反击！\n" NOR;
      #         target->start_busy(level / 16 + 2);
      #     } else
      #         {
      #         msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，镇定逾"
      #                        "恒，全神应对自如。\n" NOR;
      #         me->start_busy(2);
      #     }
      #     message_combatd(msg, me, target);
      # 
      #     return 1;
      # }
end

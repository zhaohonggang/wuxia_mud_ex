defmodule Kantele.Combat.Skills.Performs.HuagongDafa.Hua do
  @moduledoc """
  exert「hua」（source huagong-dafa/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"dp", "force"}, {"sp", "force"}], "level_gates": [{"huagong-dafa", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1"}, {"max_neili", "10"}, {"neili", "10"}, {"neili", "120"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["在这里不能攻击他人。\n", "你要化谁的内力？\n", "搞错了！只有人才能有内力！\n", "你现在正忙，无法化他人内力。\n", "你必须空手才能施用化功大法！\n", "你的化功大法功力不够，不能施展！\n", "你的内力不够，不能施展化功大法。\n"], "ap_dp_formulas": %{"dp_formula": "target->query_skill("force") + target->query_skill("dodge")"}, "color_codes": ["HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"max_neili", "-1 * (random(4) + (me->query_skill("huagong-dafa", 1) - 90) / 8)"}, {"neili", "-100"}], "resource_queries": ["max_neili", "neili"], "resource_sets": [{"max_neili", "0"}], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (me->is_busy())", "me->start_busy(2 + random(2));", "if (! target->is_busy())target->start_busy(2);", "me->start_busy(2 + random(3));"], "remote_damage": false, "set_flags": [{"max_neili", "0"}], "temp_set": []}
      #   - if (me->is_busy())
      #   - me->start_busy(2 + random(2));
      #   - if (! target->is_busy())target->start_busy(2);
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # // hua.c
      # 
      # #include <ansi.h>
      # 
      # inherit F_SSERVER;
      # 
      # int exert(object me, object target)
      # {
      #     int sp, dp;
      #     int my_max, tg_max;
      # 
      #     if (target == me) target = offensive_target(me);
      # 
      #     if (environment(me)->query("no_fight"))
      #         return notify_fail("在这里不能攻击他人。\n");
      # 
      #     if (! objectp(target))
      #         return notify_fail("你要化谁的内力？\n");
      # 
      #     if (target->query("race") != "人类")
      #         return notify_fail("搞错了！只有人才能有内力！\n");
      # 
      #         if (me->is_busy())
      #                 return notify_fail("你现在正忙，无法化他人内力。\n");
      # 
      #         my_max = me->query("max_neili");
      #         tg_max = target->query("max_neili");
      # 
      #     if (objectp(me->query_temp("weapon")))
      #         return notify_fail("你必须空手才能施用化功大法！\n");
      # 
      #     if ((int)me->query_skill("huagong-dafa", 1) < 100)
      #         return notify_fail("你的化功大法功力不够，不能施展！\n");
      # 
      #     if ((int)me->query("neili") < 120)
      #         return notify_fail("你的内力不够，不能施展化功大法。\n");
      # 
      #     if ((int)target->query("neili") < 10 ||
      #             (int)target->query("max_neili") < 10)
      #         return notify_fail(target->name() +
      #                    "已然内力涣散，不必再化了。\n");
      # 
      #         if ((int)target->query("max_neili") > (int)me->query("max_neili") * 4 / 3 )
      #         return notify_fail( target->name() +
      #             "的内功修为远胜于你，你无法化他的内力！\n");
      # 
      #     message_combatd(HIR "$N" HIR "全身骨节爆响，双臂暴长数尺，手掌"
      #                 "刷的一抖，粘向$n！\n" NOR, me, target);
      # 
      #         if (target->query_skill("taixuan-gong", 1))
      #         {
      #                 message_sort(HIG "\n$N" HIG "刚将手掌接触到$n" HIG "肌肤，猛然觉得一股无比强大的"
      #                              "内劲反压回来，化功大法的内力却犹如石沉大海。$N" HIG "大吃一惊，连"
      #                              "忙将手缩回，再也不敢接近。\n" NOR);
      #                 return 1;
      # 
      #         }
      # 
      #         me->want_kill(target);
      # 
      #     if (living(target))
      #         if (! target->is_killing(me)) target->kill_ob(me);
      # 
      #         sp = me->query_skill("force") + me->query_skill("dodge");
      #         dp = target->query_skill("force") + target->query_skill("dodge");
      # 
      #         if ((sp / 2 + random(sp) > random(dp)) || ! living(target))
      #     {
      #         tell_object(target, HIR "你只觉天顶骨裂，全身功力"
      #                 "贯脑而出，如融雪般消失得无影无踪！\n" NOR);
      # 
      #                 target->add("max_neili", -1 * (random(4) + (me->query_skill("huagong-dafa", 1) - 90) / 8) );
      #                 if (target->query("max_neili") < 1)
      #             target->set("max_neili", 0);
      # 
      #                 me->start_busy(2 + random(2));
      #                 me->add("neili", -100);
      #                 if (! target->is_busy())target->start_busy(2);
      #     } else
      #     {
      #         message_combatd(HIY "可是$p" HIY "看破了$P"
      #                     HIY "的企图，内力猛地一震，借势溜"
      #                 "了开去。\n" NOR, me, target);
      #                 me->start_busy(2 + random(3));
      #                 me->add("neili", -100);
      #     }
      # 
      #     return 1;
      # }
end

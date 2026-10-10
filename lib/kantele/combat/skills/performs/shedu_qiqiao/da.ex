defmodule Kantele.Combat.Skills.Performs.SheduQiqiao.Da do
  @moduledoc """
  perform「da」（source shedu-qiqiao/da.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "force"}, {"lvl", "shedu-qiqiao"}], "level_gates": [{"force", "30"}, {"shedu-qiqiao", "20"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "100"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你要打哪条蛇？\n", "看清楚些，那不是蛇，你瞎打什么？\n", "那条蛇暂时不会动弹了，你不必再打了。\n", "你的蛇毒奇巧还不够娴熟，不能打蛇。\n", "你的内功的修为不够，不能打蛇。\n", "你现在的内力不够了。\n"], "color_codes": ["HIC", "HIM", "HIR", "HIY", "NOR", "WHT"], "combat_exp_inline": ["lvl"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "舞动手中的" + weapon->name() +
      #                         HIC "，朝着" + target->name() + HIC "的七寸打"
      #                         "了过去。\n" NOR", "HIC "\n$N" HIC "伸出双指，出指如风，迅疾无比的"
      #                         "朝着" + target->name() + HIC "的七寸点了过去"
      #                         "。\n" NOR", "= HIY "结果只听“啪”的一声，正打在" + target->name() +
      #                          HIY "的七寸上。\n" NOR", "= HIM "只见" + target->name() + HIM
      #                                  "身子轻轻晃动几下，就不再动弹了。\n" NOR", "= WHT "然而" + target->name() + WHT "身子一闪，躲了过去。\n\n" NOR"], "success": ["= HIR + "哪里想到" + target->name() +
      #                                  HIR "挨了这一击，竟然若无其事，顿时一个翻"
      #                                  "身，直扑向$N" HIR "！\n\n" NOR"]}, "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # #include <ansi.h>
      # #include <skill.h>
      # #include <weapon.h>
      # #include <combat.h>
      # 
      # inherit F_SSERVER;
      #  
      # int perform(object me, object target)
      # {
      #         object weapon;
      #         string msg;
      #         int lvl;
      #  
      #         weapon = me->query_temp("weapon");
      # 
      #         if (! target)
      #                 return notify_fail("你要打哪条蛇？\n");
      # 
      #         if (! target->is_snake())
      #                 return notify_fail("看清楚些，那不是蛇，你瞎打什么？\n");
      # 
      #         if (! living(target))
      #                 return notify_fail("那条蛇暂时不会动弹了，你不必再打了。\n");
      # 
      #         if ((int)me->query_skill("shedu-qiqiao", 1) < 20)
      #                 return notify_fail("你的蛇毒奇巧还不够娴熟，不能打蛇。\n");
      # 
      #         if ((int)me->query_skill("force") < 30)
      #                 return notify_fail("你的内功的修为不够，不能打蛇。\n");
      # 
      #         if ((int)me->query("neili") < 100)
      #                 return notify_fail("你现在的内力不够了。\n");
      # 
      #         if (weapon)
      #                 msg = HIC "\n$N" HIC "舞动手中的" + weapon->name() +
      #                       HIC "，朝着" + target->name() + HIC "的七寸打"
      #                       "了过去。\n" NOR;
      #         else
      #                 msg = HIC "\n$N" HIC "伸出双指，出指如风，迅疾无比的"
      #                       "朝着" + target->name() + HIC "的七寸点了过去"
      #                       "。\n" NOR;
      # 
      #         lvl = (int) me->query_skill("shedu-qiqiao", 1) +
      #               (int) me->query_skill("dodge");
      #         lvl = lvl * lvl / 10 * lvl;
      # 
      #         if( lvl / 2 + random(lvl) > (int) target->query("combat_exp") )
      #         {
      #                 msg += HIY "结果只听“啪”的一声，正打在" + target->name() +
      #                        HIY "的七寸上。\n" NOR;
      #                 lvl = (int) me->query_skill("force");
      #                 lvl = lvl * 13 / 10;
      #                 lvl = lvl * lvl / 10 * lvl;
      #                 if ( lvl / 2 + random(lvl) > (int) target->query("combat_exp") )
      #                 {
      #                         msg += HIM "只见" + target->name() + HIM
      #                                "身子轻轻晃动几下，就不再动弹了。\n" NOR;
      #                         message_vision(msg, me);
      #                         target->unconcious();
      #                 } else
      #                 {
      #                         msg += HIR + "哪里想到" + target->name() +
      #                                HIR "挨了这一击，竟然若无其事，顿时一个翻"
      #                                "身，直扑向$N" HIR "！\n\n" NOR;
      #                         message_vision(msg, me);
      #                         target->kill_ob(me);
      #                 }
      #         } else
      #         {
      #                 msg += WHT "然而" + target->name() + WHT "身子一闪，躲了过去。\n\n" NOR;
      #                 message_vision(msg, me);
      #                 target->kill_ob(me);
      #         }
      #         me->add("neili", -50);
      #         me->start_busy(2);
      # 
      #         return 1;
      # }
end

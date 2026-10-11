defmodule Kantele.Combat.Skills.Performs.SheduQiqiao.Da do
  @moduledoc """
  perform「da」（source shedu-qiqiao/da.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "shedu-qiqiao/da"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 30 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "shedu-qiqiao") < 20 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"lvl", "force"}, {"lvl", "shedu-qiqiao"}], "busy_lines": ["me->start_busy(2);"], "level_gates": [{"force", "30"}, {"shedu-qiqiao", "20"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

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

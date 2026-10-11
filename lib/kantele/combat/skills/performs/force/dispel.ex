defmodule Kantele.Combat.Skills.Performs.Force.Dispel do
  @moduledoc """
  exert「dispel」（source force/dispel.c，由 translate_perform.py 生成，inherit ?）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  @impl true
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 250}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-250"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1 + random(2));", "me->start_busy(2 + random(3));", "target->start_busy(1 + random(2));", "me->start_busy(3 + random(3));", "me->start_busy(6 + random(6));", "target->start_busy(4 + random(4));", "me->start_busy(1);", "me->start_busy(2);", "target->start_busy(1);"], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // dispel.c
  # 
  # #include <ansi.h>
  # 
  # int exert(object me, object target)
  # {
  #         int i;
  #         int still_ill;
  #         string force_name;
  #         string *cnds;
  #         mapping conditions;
  # 
  #         if (me->query("neili") < 300)
  #         {
  #                 write("你的内力不足，无法运满一个周天。\n");
  #                 return 1;
  #         }
  # 
  #         force_name = to_chinese(me->query_skill_mapped("force"));
  # 
  #         if (me == target)
  #         {
  #                 message_vision(HIW "$N" HIW "深吸一口气，又缓缓的吐了出来。\n" NOR, me);
  #                 tell_object(me, YEL "你默运" + force_name + YEL "，开始排除身"
  #                                 "体中的异常症状。\n" NOR);
  #                 me->add("neili", -100);
  #         } else
  #         {
  #             if (me->is_fighting(target))
  #             {
  #                 write("你们正打得热闹呢，还有心思干这个？\n");
  #                         return 1;
  #                 }
  # 
  #                 if (target->is_fighting())
  #                 {
  #                     write("对方正在打架，还是等他打完了再说吧。\n");
  #                         return 1;
  #                 }
  # 
  #                 if (target->is_busy())
  #                 {
  #                     write("对方现在正忙着呢，等他空了些再说吧。\n");
  #                         return 1;
  #                 }
  # 
  #                 message_vision(HIW "$N" HIW "深吸一口气，将手掌粘到$n"
  #                                HIW "的背后。\n" NOR, me, target);
  #                 tell_object(me, YEL "你默运" + force_name + YEL "，开"
  #                                 "始帮助" + target->name() + YEL "排除"
  #                                 "身体中的异常症状。\n" NOR);
  #                 tell_object(target, YEL + me->name() + YEL "正在运功帮"
  #                                     "助你排除身体中的异常症状。\n" NOR);
  #                 me->add("neili", -250);
  #         }
  # 
  #         still_ill = 0;
  #         conditions = target->query_condition();
  #         if (conditions)
  #         {
  #                 cnds = keys(conditions);
  #                 for (i = 0; i < sizeof(cnds); i++)
  #                 {
  #                         switch(target->dispel_condition(me, cnds[i]))
  #                         {
  #                         case 0:
  #                                 continue;
  #                         case -1:
  #                                 still_ill = 1;
  #                                 continue;
  #                         }
  # 
  #                         if (me == target)
  #                         {
  #                                 tell_object(me, WHT "你调息完毕，将内力收回丹"
  #                         "田。\n" NOR);
  #                                 me->start_busy(1 + random(2));
  #                         } else
  #                         {
  #                                 tell_object(me, WHT "你调息完毕，将内力收回"
  #                         "丹田。\n" NOR);
  #                                 tell_object(target, WHT "你觉得内息一畅，看来是" +
  #                                             me->name() + "收功了。\n");
  #                                 me->start_busy(2 + random(3));
  #                                 target->start_busy(1 + random(2));
  #                                 message_vision(WHT "$N" WHT "将手掌从$n" WHT "背后"
  #                                                "收了回来。\n" NOR, me, target);
  #                         }
  #                         return 1;
  #                 }
  #         }
  # 
  #         if (still_ill)
  #         {
  #                 if (me == target)
  #                 {
  #                         tell_object(me, MAG "你调息良久，没有一点效果。\n" NOR);
  #                         message_vision(HIG "$N" HIG "脸色变了变，有些不"
  #                        "太自然。\n" NOR, me);
  #                         me->start_busy(3 + random(3));
  #                 } else
  #                 {
  #                         tell_object(me, MAG "你运功良久，没能发挥半点作用。\n" NOR);
  #                         tell_object(target, MAG "你觉得内息一阵紊乱，说不出"
  #                             "的难受。\n看来" + me->name() +
  #                         "是不能给予你帮助了。\n" NOR);
  # 
  #                         message_vision(HIG "$N将手掌从$n背后收了回来，脸色"
  #                        "说不出的难看。\n" NOR, me, target);
  # 
  #                         me->start_busy(6 + random(6));
  #                         target->start_busy(4 + random(4));
  #                 }
  #         } else
  #         {
  #                 if (me == target)
  #                 {
  #                         tell_object(me, "结果你没发现自己有任何异常。\n");
  #                         message_vision(WHT "$N" WHT "眉角微微一动，随即恢"
  #                        "复正常。\n" NOR, me);
  #                         me->start_busy(1);
  #                 } else
  #                 {
  #                         tell_object(me, "结果你没发现" + target->name() +
  #                                    "有任何异常。\n");
  #                         tell_object(target, "你觉得内息一畅，看来是" +
  #                                     me->name() + "收功了，大概你本来没有什"
  #                     "么异常吧。\n");
  #                         message_vision(WHT "$N" WHT "将手掌从$n" WHT "背后收了"
  #                        "回来。\n" NOR, me, target);
  #                         me->start_busy(2);
  #                         target->start_busy(1);
  #                 }
  #         }
  # 
  #     return 1;
  # }
end

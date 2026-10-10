defmodule Kantele.Combat.Skills.Performs.SankuShengong.Dispel do
  @moduledoc """
  exert「dispel」（source sanku-shengong/dispel.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"color_codes": ["HIW", "NOR", "WHT", "YEL"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-100"}, {"neili", "-250"}], "target_logic": %{"requires_fighting": false, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy( 1 + random( 2 ) );", "me->start_busy( 2 + random( 3 ) );", "if ( !target->is_busy() )", "target->start_busy( 1 + random( 2 ) );"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy( 1 + random( 2 ) );
      #   - me->start_busy( 2 + random( 3 ) );
      #   - if ( !target->is_busy() )
      #   - target->start_busy( 1 + random( 2 ) );
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
      # /* dispel.c */
      # 
      # #include <ansi.h>
      # 
      # int exert( object me, object target )
      # {
      #     // int    i;
      #     string    force_name;
      #     mapping conditions;
      # 
      #     if ( me->query( "neili" ) < 300 )
      #     {
      #         write( "你的内力不足，无法运满一个周天。\n" );
      #         return(1);
      #     }
      # 
      #     force_name = to_chinese( me->query_skill_mapped( "force" ) );
      # 
      #     if ( me == target )
      #     {
      #         message_vision( HIW "$N" HIW "深吸一口气，又缓缓的吐了出来。\n" NOR, me );
      #         tell_object( me, YEL "你默运" + force_name +
      #                  "，开始排除身体中的异常症状。\n" NOR );
      #         me->add( "neili", -100 );
      #     } else{
      #         message_vision( HIW "$N" HIW "深吸一口气，将手掌粘到$n"
      #                 HIW "的背后。\n" NOR,
      #                 me, target );
      #         tell_object( me, YEL "你默运" + force_name + "，开始帮助" +
      #                  target->name() + "排除身体中的异常症状。\n" NOR );
      #         tell_object( target, YEL + me->name() +
      #                  "正在运功帮助你排除身体中的异常症状。\n" NOR );
      #         me->add( "neili", -250 );
      #     }
      # 
      #     conditions = target->query_condition();
      #     if ( conditions )
      #     {
      #         target->clear_condition();
      # 
      #         tell_object( target, YEL + me->name() + "正在运功将你身体中的异常症状尽数排除。\n" NOR );
      #         if ( me == target )
      #         {
      #             tell_object( me, WHT "你调息完毕，将内力收回丹"
      #                      "田。\n" NOR );
      #             me->start_busy( 1 + random( 2 ) );
      #         } else{
      #             tell_object( me, WHT "你调息完毕，将内力收回"
      #                      "丹田。\n" NOR );
      #             tell_object( target, WHT "你觉得内息一畅，看来是" +
      #                      me->name() + "收功了。\n" );
      #             me->start_busy( 2 + random( 3 ) );
      #             if ( !target->is_busy() )
      #                 target->start_busy( 1 + random( 2 ) );
      #             message_vision( WHT "$N将手掌从$n背后收了回"
      #                     "来。\n" NOR, me, target );
      #         }
      #     }
      # 
      #     return(1);
      # }
end

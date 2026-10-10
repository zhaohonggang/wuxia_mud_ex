defmodule Kantele.Combat.Skills.Performs.TangmenThrowing.Hua do
  @moduledoc """
  perform「hua」（source tangmen-throwing/hua.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"all_fail_messages": ["你现在手中没有拿着暗器唐花，难以施展", "你的唐门暗器不够娴熟，难以施展", "你的眼力太差了，目标不精确，无法施展", "你的拨云锁雾不够娴熟，无法施展", "你的内功修为不足，难以施展", "你的内力修为不足，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill( "throwing" ) * 2", "dp_formula": "target->query_skill( "parry" ) + target->query_skill( "dodge" ) +
      #             target->query_skill( "dugu-jiujian", 1 ) * 10"}, "callback_functions": [%{"body": "return(HIR "唐花" NOR);", "name": "name", "params": "", "return_type": "string"}], "color_codes": ["HIC", "HIG", "HIR", "NOR"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["COMBAT_D->query_ahinfo() ) )
      #                   msg += pmsg", "= "( $n" + eff_status_msg( p ) + " )\n""], "success": ["HIR "\n$N" HIR "手中突然多了一支花，美得妖艳，$n" HIR "觉得有点痴了，\n$N" HIR "向$n" HIR "一笑，一扬手向$n"HIR "抛去。\n" +
      #             HIG "只见那花开了，五瓣齐舒，中央花心吐蕊，煞是好看。\n" NOR", "HIR "结果$p" HIR "一声惨嚎，连中了$P" HIR "发出的一" +
      #                     weapon->query( "base_unit" ) + weapon->name() + HIR "。\n"NOR", "HIR "那花越开越艳，$n" HIR "不知不觉中已痴迷了，身形一慢,微笑着倒下了，那花也谢了。\n" NOR", "HIR "$n " HIR "身形飘忽，那花划空而过。只听当的一声轻响，那花谢了，轻轻地砸在地面上。\n" NOR"]}, "damage_formula": %{"formula": "me->query_skill( "throwing" ) * 2 / 3"}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap * 3 / 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-1000"}], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy( 2 );", "me->start_busy( 2 );", "me->start_busy( 3 );"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy( 2 );
      #   - me->start_busy( 2 );
      #   - me->start_busy( 3 );
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

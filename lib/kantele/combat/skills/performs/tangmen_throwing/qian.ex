defmodule Kantele.Combat.Skills.Performs.TangmenThrowing.Qian do
  @moduledoc """
  perform「qian」（source tangmen-throwing/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"all_fail_messages": ["你现在手中没有拿着暗器心有千千结，难以施展", "你的唐门暗器不够娴熟，难以施展", "你的眼力太差了，目标不精确，无法施展", "你的拨云锁雾不够娴熟，无法施展", "你的内功修为不足，难以施展", "你的内力修为不足，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill( "throwing" )", "dp_formula": "target->query_skill( "dodge" ) +
      #             target->query_skill( "dugu-jiujian", 1 )"}, "callback_functions": [%{"body": "return(HIR "心有千千结" NOR);", "name": "name", "params": "", "return_type": "string"}], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "\n$N" HIR "突然身行一止，从怀中摸出一条" + weapon->name() + HIR "，有无数个结，一扬手向$n " HIR "掷去。\n"
      #             "只见$n" HIR "的周身飞舞着无数的光影，一条天网从空罩下。\n"NOR", "HIR "忽然那无数的光影一闪而没，$n身行一顿，给这" + weapon->name() + HIR "缠上，仰天而倒。\n" NOR", "HIR "$n" HIR "急忙向旁边一纵，躲开着致命的" + weapon->name() + HIR "，但已显得狼狈不堪。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random( ap )", "operator": ">", "right_side": "dp"}, "hit_ob_calls": [{"me", "target", "me->query("jiali") + 200"}], "resource_adds": [{"neili", "-100"}, {"neili", "-1000"}], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if ( !living( target ) || target->is_busy() )", "target->start_busy( ap / 80 + 2 );", "me->start_busy( 3 );"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if ( !living( target ) || target->is_busy() )
      #   - target->start_busy( ap / 80 + 2 );
      #   - me->start_busy( 3 );
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

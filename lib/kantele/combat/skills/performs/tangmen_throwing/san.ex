defmodule Kantele.Combat.Skills.Performs.TangmenThrowing.San do
  @moduledoc """
  perform「san」（source tangmen-throwing/san.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"all_fail_messages": ["你现在手中没有拿着暗器散花天女，难以施展", "你现在手中没有足够的暗器，难以施展", "你的唐门暗器不够娴熟，难以施展", "你的眼力太差了，目标不精确，无法施展", "你的拨云锁雾不够娴熟，无法施展", "你的内功修为不足，难以施展", "你的内力修为不足，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "amount_calls": [{"query_amount", ""}], "amount_gates": ["10"], "ap_dp_formulas": %{"ap_formula": "me->query_skill( "throwing" ) +
      #            me->query_skill( "force" )", "dp_formula": "target->query_skill( "parry" ) +
      #            target->query_skill( "dodge" ) +
      #            target->query_skill( "dugu-jiujian", 1 )"}, "callback_functions": [%{"body": "return(HIM "散花天女" NOR);", "name": "name", "params": "", "return_type": "string"}], "color_codes": ["HIC", "HIG", "HIM", "HIR", "NOR"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "手中扣住一枚" + weapon->name() + HIG "，不理敌人的攻击，身体急速旋转起来，犹如一道呼啸的旋风！\n" NOR
      #             HIG "突然从旋风中飞出无数点" HIC "寒星" NOR + HIG "，划出一道道长虹闪电般的飞向$n" HIG "的身体！\n" NOR", "COMBAT_D->query_ahinfo() ) )
      #                   msg += pmsg", "= "( $n" + eff_status_msg( p ) + " )\n""], "success": ["HIR "结果$p" HIR "一声惨嚎，连中了$P" HIR "发出的十" +
      #                     weapon->query( "base_unit" ) + weapon->name() + HIR "。\n"NOR", "HIR "忽然那无数的光影一闪而没，$n身行一顿，喷出一口鲜血，仰天而倒。\n" NOR", "HIR "$n" HIR "双臂急舞，衣袖带起破风之声。只听当的一声轻响，竟将那无数枚暗器磕飞开去。\n" NOR"]}, "damage_formula": %{"formula": "me->query_skill( "throwing" ) * 3 / 5"}, "hit_formula": %{"left_side": "ap * 11 / 20 + random(ap / 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-1000"}], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
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

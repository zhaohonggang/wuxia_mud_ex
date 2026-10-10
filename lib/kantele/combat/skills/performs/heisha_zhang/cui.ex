defmodule Kantele.Combat.Skills.Performs.HeishaZhang.Cui do
  @moduledoc """
  perform「催魂掌」（source heisha-zhang/cui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "force"}, {"lvl", "heisha-zhang"}], "level_gates": [{"force", "150"}, {"heisha-zhang", "100"}], "map_gates": [{"strike", "heisha-zhang"}], "prepared_gates": [{"strike", "heisha-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "sha_poison", "duration_formula": "lvl / 50 + random(lvl / 20)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali"))"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你没有激发黑砂掌，难以施展", "你现在没有准备使用黑砂掌，难以施展", "你的黑砂掌不够熟练，难以施展", "你的内力修为不足，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("force")"}, "color_codes": ["CYN", "HIB", "HIR", "NOR"], "combat_messages": %{"fail": ["= CYN "$n" CYN "见$N"
      #                          CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR"], "other": ["HIB "$N" HIB "冷笑数声，单掌陡然一振，催魂般悄然拍至$n"
      #                 HIB "前胸，不着半点力道。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
      #                                            damage, 20, HIR "$n" HIR "只觉$N" HIR "掌劲穿"
      #                                            "胸而过，一时说不出的难受，呕出一大口黑血。\n"
      #                                            NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": ["sha_poison"], "apply_adds": [], "busy_lines": ["me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

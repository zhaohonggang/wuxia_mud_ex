defmodule Kantele.Combat.Skills.Performs.HanbingMianzhang.Jue do
  @moduledoc """
  perform「连绵不绝」（source hanbing-mianzhang/jue.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"hanbing-mianzhang", "100"}], "map_gates": [{"strike", "hanbing-mianzhang"}], "prepared_gates": [{"strike", "hanbing-mianzhang"}], "resource_gates": [{"neili", "250"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你寒冰绵掌不够娴熟，难以施展", "你没有激发寒冰绵掌，难以施展", "你没有准备寒冰绵掌，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIG", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "双掌陡然连续拍出，掌风阴寒无比，一招"
      #                 "「" HIG "连绵不绝" HIC "」，已连连罩向$n" HIC "。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-attack_time * 30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["if (! target->is_busy() && random(3) == 1)", "target->start_busy(1);", "me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (! target->is_busy() && random(3) == 1)
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(attack_time));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

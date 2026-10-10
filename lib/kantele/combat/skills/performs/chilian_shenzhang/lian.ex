defmodule Kantele.Combat.Skills.Performs.ChilianShenzhang.Lian do
  @moduledoc """
  perform「赤心连环决」（source chilian-shenzhang/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "parry"}], "level_gates": [{"chilian-shenzhang", "100"}, {"force", "100"}], "map_gates": [], "prepared_gates": [{"strike", "chilian-shenzhang"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你赤练神掌不够娴熟，难以施展", "你没有准备赤练神掌，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["HIC", "HIM", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "暗运内功，但见$N" HIC "双掌微微呈显"
      #                 "赤色，陡然连续反转，使出一招「" HIM "赤心连环决" HIC
      #                 "」，掌风凌厉，将$n" HIC "笼罩在双掌之中。\n" NOR", "HIY "$n" HIY "看清$N" HIY "这几招的来路，但"
      #                         "内劲所至，掌风犀利，也只得小心抵挡。\n" NOR"], "success": ["HIR "$n" HIR "心中一惊，却被$N" HIR "掌"
      #                         "风所困，顿时阵脚大乱。\n" NOR"]}, "resource_adds": [{"neili", "-attack_time * 20"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(attack_time));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(attack_time));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

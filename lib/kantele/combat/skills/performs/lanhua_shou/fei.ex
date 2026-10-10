defmodule Kantele.Combat.Skills.Performs.LanhuaShou.Fei do
  @moduledoc """
  perform「影落飞花」（source lanhua-shou/fei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "lanhua-shou"}], "level_gates": [{"lanhua-shou", "140"}], "map_gates": [{"hand", "lanhua-shou"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你兰花拂穴手不够娴熟，难以施展", "你没有激发兰花拂穴手，难以施展", "你没有准备兰花拂穴手，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "微一凝神，双手作兰花状疾拂而出，一环环的劲气登时直逼$n"
      #                 HIC "全身各大要穴。\n" NOR", "= HIY "可是$n" HIY "凝神顿气，奋力抵挡，丝"
      #                          "毫不受手影的干扰，。\n" NOR"], "success": ["= HIR "$n" HIR "顿时觉得眼花缭乱，全然分辨"
      #                          "不清真伪，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(random(3));"], "remote_damage": false, "set_flags": [], "temp_set": ["action_flag"]}
      #   - me->start_busy(random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

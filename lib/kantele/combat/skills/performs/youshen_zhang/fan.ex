defmodule Kantele.Combat.Skills.Performs.YoushenZhang.Fan do
  @moduledoc """
  perform「翻卦连环掌」（source youshen-zhang/fan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "youshen-zhang"}], "level_gates": [{"force", "160"}, {"youshen-zhang", "120"}], "map_gates": [{"unarmed", "youshen-zhang"}], "prepared_gates": [{"unarmed", "youshen-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功修为不够，难以施展", "你的游身八卦掌不够娴熟，难以施展", "你没有激发游身八卦掌，难以施展", "你没有准备游身八卦掌，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "脚踏八卦四方之位，身形在全场游走不定，双掌随后紧"
      #                 "拍而出，紧紧缠绕着$n" HIW "。\n" NOR", "= HIC "$n" HIC "深吸一口气，凝神抵挡，但见"
      #                          "周围$N" HIC "掌影重重，$p" HIC "却是临危"
      #                          "不乱，镇定拆招。\n" NOR"], "success": ["= HIR "$n" HIR "顿时觉得呼吸不畅，全然被$N"
      #                          HIR "这股奇怪的力道所制，只得拼命运动抵挡"
      #                          "。\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

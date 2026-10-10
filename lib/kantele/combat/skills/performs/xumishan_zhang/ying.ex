defmodule Kantele.Combat.Skills.Performs.XumishanZhang.Ying do
  @moduledoc """
  perform「ying」（source xumishan-zhang/ying.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "xumishan-zhang"}], "level_gates": [{"xumishan-zhang", "150"}], "map_gates": [], "prepared_gates": [{"strike", "xumishan-zhang"}], "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「群山叠影」只能对战斗中的对手使用。\n", "你必须空手才能使用「群山叠影」！\n", "你的须弥山掌掌不够娴熟，不会使用「群山叠影」。\n", "你现在真气太弱，不能使用「群山叠影」。\n", "你现在没有准备使用须弥山掌，不能使用「群山叠影」。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "稳稳使出须弥山掌掌的绝招「群山叠影」，双掌"
      #                 "平平向$n" HIY "推去，$n" HIY "顿时觉得一股排山倒海的"
      #                 "内力向自己涌来。\n" NOR", "= HIC "$n" HIC "深吸一口气，凝神抵挡，犹如轻舟立"
      #                          "于惊涛骇浪之中，左右颠簸，却是不倒。\n" NOR"], "success": ["= HIR "$n" HIR "顿时觉得呼吸不畅，全然被这"
      #                          "股力道所制，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

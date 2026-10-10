defmodule Kantele.Combat.Skills.Performs.YitianZhang.Zheng do
  @moduledoc """
  perform「谁与争锋」（source yitian-zhang/zheng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "yitian-zhang"}], "level_gates": [{"yitian-zhang", "120"}], "map_gates": [{"strike", "yitian-zhang"}], "prepared_gates": [{"strike", "yitian-zhang"}], "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的倚天屠龙掌不够娴熟，难以施展", "你现在真气太弱，难以施展", "你没有激发倚天屠龙掌，难以施展", "你没有准备使用倚天屠龙掌，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "神气贯通，将倚天屠龙掌二十四字一气呵成，双掌"
      #                 "携带着排山倒海之劲贯向$n" HIY "。\n\n" NOR", "= HIC "$n" HIC "深吸一口气，凝神抵挡，犹如轻舟立"
      #                          "于惊涛骇浪之中，左右颠簸，却是不倒。\n" NOR"], "success": ["= HIR "$n" HIR "顿时觉得呼吸不畅，全然被这"
      #                          "股力道所制，只得拼命运动抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["me->start_busy(1 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

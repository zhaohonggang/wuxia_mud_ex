defmodule Kantele.Combat.Skills.Performs.XiuluoYinshagong.Suck do
  @moduledoc """
  exert「suck」（source xiuluo-yinshagong/suck.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"lvl", "poison"}], "level_gates": [{"wudu-qishu", "100"}, {"xiuluo-yinshagong", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你要取哪只虫的毒液练药？\n", "看清楚些，那可不是毒虫。\n", "那只虫还精神着呢，你找死啊。\n", "你的五毒奇术不够娴熟，不能炼制毒药。\n", "你修罗阴煞功修为不够，不能炼制毒药。\n", "你现在内力不足，难以炼制毒药。\n", "看来你是弄不出什么毒液来了。\n"], "color_codes": ["HIC", "HIR", "HIW", "HIY", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["= WHT "$N" WHT "挤了半天，结果啥也没有挤出来，算是"
      #                          "白忙活了。\n\n" NOR", "= WHT "$N" WHT "挤了一点毒液出来。\n" NOR", "= HIW "$N" HIW "将" + target->name() + HIW "的毒液逼出，在"
      #                  "内力的作用下化成了一颗晶莹剔透的药丸。\n" NOR"], "success": ["HIR "\n$N" HIR "伸出食指，点在" + target->name() +
      #                 HIR "腹部，默运内力迫出毒液练药。\n" NOR"]}, "improve_skill": ["improve_skill("], "resource_adds": [{"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": false, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(random(3));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

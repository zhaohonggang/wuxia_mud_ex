defmodule Kantele.Combat.Skills.Performs.ChuncanZhang.Jian do
  @moduledoc """
  perform「作茧自缚」（source chuncan-zhang/jian.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"skill", "chuncan-zhang"}], "level_gates": [{"chuncan-zhang", "80"}, {"force", "120"}], "map_gates": [{"strike", "chuncan-zhang"}], "prepared_gates": [{"strike", "chuncan-zhang"}], "resource_gates": [{"max_neili", "800"}, {"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你已经运起", "你的春蚕掌法不够娴熟，难以施展", "你的内功火候不够，难以施展", "你的内力修为不够，难以施展", "你没有激发春蚕掌法，难以施展", "你没有准备春蚕掌法，难以施展", "你的真气不够，难以施展"], "buff_delete": ["ccz_jian"], "call_outs": [%{"args": "me, skill / 4, skill / 3", "delay": "skill / 2", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("ccz_jian"))
      #           {
      #                   me->add_temp("apply/attack", a_amount);
      #                   me->add_temp("apply/dodge", -d_amount);
      #                   me->delete_temp("ccz_jian");
      #    ", "name": "remove_effect", "params": "object me, int a_amount, int d_amount", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "凝聚内力，掌劲吞吐，顿时双掌掀起一层气劲，护住周身经脉。\n\n" NOR"], "success": []}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack", "dodge"], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["ccz_jian"]}
      #   - if (me->is_fighting()) me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

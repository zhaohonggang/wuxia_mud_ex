defmodule Kantele.Combat.Skills.Performs.YijinDuangu.Shield do
  @moduledoc """
  exert「shield」（source yijin-duangu/shield.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"lvlb", "yinlong-bian"}, {"lvlc", "cuixin-zhang"}, {"lvld", "shexing-lifan"}, {"lvlf", "yijin-duangu"}, {"lvlp", "dafumo-quan"}, {"lvlz", "jiuyin-baiguzhao"}], "level_gates": [], "map_gates": [{"dodge", "shexing-lifan"}, {"unarmed", "dafumo-quan"}, {"whip", "yinlong-bian"}], "prepared_gates": [{"claw", "jiuyin-baiguzhao"}, {"strike", "cuixin-zhang"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"lvlb", "200"}, {"lvlc", "200"}, {"lvld", "200"}, {"lvlf", "200"}, {"lvlp", "200"}, {"lvlz", "200"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用易筋锻骨来提升自己的防御力。\n", "你的内力不够。\n", "你的小九阴神功修为不够。\n", "你还没有准备好小九阴神功，无法提升自己的防御力。\n", "你已经在运功中了。\n"], "buff_delete": ["shield"], "call_outs": [%{"args": "me, skill / 4", "delay": "skill", "fn": "remove_effect"}], "callback_functions": [%{"body": "if (me->query_temp("shield"))
      #           {
      #               me->add_temp("apply/armor", -amount);
      #               me->add_temp("apply/force", -amount);
      #               me->add_temp("apply/dodge", -amount);
      #             ", "name": "remove_effect", "params": "object me, int amount", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "receive_damage_calls": [%{"formula": "0", "kind": "damage", "part": "qi", "source": None}], "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["armor", "claw", "damage", "dodge", "force", "parry", "strike", "unarmed_damage", "whip"], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["shield"]}
      #   - if (me->is_fighting()) me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

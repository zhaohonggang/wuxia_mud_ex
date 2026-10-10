defmodule Kantele.Combat.Skills.Performs.WuzhanMei.Liu do
  @moduledoc """
  perform「liu」（source wuzhan-mei/liu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["『流花掠影』只能对战斗中的对手使用。\n", "你必须在使用剑时才能使出『流花掠影』。\n", "你目前的内力不足，无法施展『流花掠影』。\n", "你的五展梅剑法不够纯熟，无法使用『流花掠影』。\n", "你没有激发五展梅，难以施展『流花掠影』。\n"], "callback_functions": [%{"body": "return(HIR "流花掠影" NOR);", "name": "name", "params": "", "return_type": "string"}], "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-300"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy( 2 );"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy( 2 );
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

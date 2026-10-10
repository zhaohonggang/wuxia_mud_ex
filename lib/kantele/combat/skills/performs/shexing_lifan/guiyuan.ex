defmodule Kantele.Combat.Skills.Performs.ShexingLifan.Guiyuan do
  @moduledoc """
  perform「guiyuan」（source shexing-lifan/guiyuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "shexing-lifan"}], "level_gates": [{"dodge", "150"}, {"force", "150"}, {"shexing-lifan", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"max_neili", "1000"}, {"neili", "250"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你已经运起「九阴归元」了。\n", "你的蛇行狸翻等级不够，难以施展此项绝技！\n", "你的身法不够使用「九阴归元」绝技！\n", "你的内功火候不够，难以施展此项绝技！\n", "你的轻功修为不够，不会使用此项绝技！\n", "你的内力修为不够使用「九阴归元」！\n", "你此时的内力不足！\n"], "buff_delete": ["gui_yuan"], "call_outs": [%{"args": "me, count", "delay": "skill / 2", "fn": "remove_effect"}], "callback_functions": [%{"body": "if ((int)me->query_temp("gui_yuan"))
      #           {
      #                   me->add_temp("str", -amount);
      #                   me->add_temp("dex", -amount);
      #                   me->delete_temp("gui_yuan");
      #                   ", "name": "remove_effect", "params": "object me, int amount, int amount1", "return_type": "void"}], "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "运起九阴真气，双臂骨骼一阵爆响，身形一展，整"
      #                     "个人顿时凌空飘起，速度变得异常敏捷。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["gui_yuan"]}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

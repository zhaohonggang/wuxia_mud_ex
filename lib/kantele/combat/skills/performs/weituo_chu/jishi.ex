defmodule Kantele.Combat.Skills.Performs.WeituoChu.Jishi do
  @moduledoc """
  perform「jishi」（source weituo-chu/jishi.c，由 translate_perform.py 骨架生成，inherit F_DBASE）

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
      #   %{"assign_refs": [{"club", "staff"}, {"damage", "weituo-chu"}], "level_gates": [{"force", "120"}, {"weituo-chu", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你还不会使用「即世即空」!\n", "「即世即空」只能对战斗中的对手使用。\n", "你手中无杵，怎能运用「即世即空」？！\n", "你刚使完「即世即空」，目前气血翻涌，无法再次运用！\n", "你韦陀杵修为还不够，还未能使用「即世即空」！\n", "你的内功修为火候未到，施展只会伤及自身！\n", "你的内力修为不足，劲力不足以施展「即世即空」！\n", "你的内力不够，劲力不足以施展「即世即空」！\n"], "buff_delete": ["sl_leidong"], "callback_functions": [%{"body": "if (!me) return;
      #           me->add_temp("apply/attack", -damage);  
      #   
      #           if (!weapon) {
      #                   me->set_temp("apply/damage", 0);
      #                   return;", "name": "remove_effect1", "params": "object me, object weapon, int damage", "return_type": "void"}, %{"body": "if (!me) return;
      #           me->delete_temp("sl_leidong");
      #           tell_object(me, HIG "\n 你经过一段时间调气养息，又可以使用「即世即空」了。\n"NOR);", "name": "remove_effect2", "params": "object me", "return_type": "void"}], "color_codes": ["BLU", "HIG", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "damage_formula": %{"formula": "me->query_skill("weituo-chu", 1) + me->query_skill("buddhism",1)"}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": true}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}, {"rigidity", "1"}], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": ["sl_leidong"]}
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

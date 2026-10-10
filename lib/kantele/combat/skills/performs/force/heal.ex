defmodule Kantele.Combat.Skills.Performs.Force.Heal do
  @moduledoc """
  exert「heal」（source force/heal.c，由 translate_perform.py 骨架生成，inherit ?）

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
      #   %{"assign_refs": [{"recover_points", "force"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "50"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["战斗中运功疗伤？找死吗？\n", "等你忙完了手头的事情再说！\n", "天魔解体状态不能运功疗伤！\n", "先激发你的特殊内功。\n", "你现在气血充盈，不需要疗伤。\n", "你的", "你的真气不够。\n", "你已经受伤过重，只怕一运真气便有生命危险！\n"], "callback_functions": [%{"body": "string force;
      #           int recover_points;
      #   
      #           force = me->query_skill_mapped("force");
      #           if (! stringp(force))
      #           {
      #                   // 没有特殊内功了？
      #                   tell_object(me, "你一时难以定夺", "name": "healing", "params": "object me", "return_type": "int"}, %{"body": "tell_object(me, "你将真气收回丹田，微微喘息，站了起来。\n");
      #           tell_room(environment(me), me->name() + "猛的吸一口气，突然站了起来。\n", me);
      #           me->set_temp("pending/healing", 0);
      #           me->set_short_desc(0);
      #           if", "name": "halt_healing", "params": "object me", "return_type": "int"}], "color_codes": ["HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-100"}, {"neili", "-50"}], "resource_queries": ["max_qi", "neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (me->is_busy())", "me->start_busy((:call_other, __FILE__, "healing" :),"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - if (me->is_busy())
      #   - me->start_busy((:call_other, __FILE__, "healing" :),
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

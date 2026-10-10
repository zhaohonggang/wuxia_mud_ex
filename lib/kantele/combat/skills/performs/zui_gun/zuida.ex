defmodule Kantele.Combat.Skills.Performs.ZuiGun.Zuida do
  @moduledoc """
  perform「zuida」（source zui-gun/zuida.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "zui-gun"}], "level_gates": [{"club", "100"}, {"force", "150"}], "map_gates": [{"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「八仙醉打」只能在战斗中使用。\n", "你现在没有激发少林内功为内功，难以施展「八仙醉打」。\n", "你使用的武器不对。\n", "你已经在运功中了。\n", "你已经运起内功提升战力了，不能再使用「八仙醉打」。\n", "你现在的臂力不够，目前不能使用「八仙醉打」！\n", "你的内功火候不够，难以施展「八仙醉打」！\n", "你的棍法修为不够，不会使用「八仙醉打」！\n", "你的真气不足！\n"], "buff_delete": ["zg_zuida"], "call_outs": [%{"args": "me, count, count1", "delay": "skill / 3", "fn": "remove_effect"}], "callback_functions": [%{"body": "if ((int)me->query_temp("zg_zuida"))
      #       {
      #           me->add_temp("str", -amount);
      #           me->add_temp("dex", -amount1);
      #           me->delete_temp("zg_zuida");
      #           tell_object(me, "你的「八仙醉打」运功完毕，将内力收回", "name": "remove_effect", "params": "object me, int amount, int amount1", "return_type": "void"}], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "使出少林醉棍的绝技「八仙醉打」，臂"
      #                 "力陡然增加, 身法陡然加快！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}, "weapon_type": "club"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": ["zg_zuida"]}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Suck do
  @moduledoc """
  perform「suck」（source qianzhu-wandushou/suck.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"my_force", "xiuluo-yinshagong"}, {"my_skill", "qianzhu-wandushou"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [{"age", "99"}, {"neili", "200"}, {"qi", "200"}, {"qi", "50"}], "var_gates": [{"my_skill", "100"}, {"tg_age", "200"}, {"tg_age", "300"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "这里太嘈杂，你不能静下心来修炼。\n", "你要吸取什么毒虫的毒素？\n", "你看清楚点，那东西像是毒虫吗？\n", "你看清楚点，那东西像是毒虫吗？\n", "你的千蛛万毒手火候太浅，不能用来吸取毒素！\n", "你必须空手才能修炼千蛛万毒手！\n", "战斗中无法修炼千蛛万毒手！\n", "你正忙着呢！\n", "毒虫正忙着呢，不能和你配合！\n", "你正在修炼中！\n", "你的实战经验不够，无法继续修炼千蛛万毒手！\n", "你的内力不够，不足以对抗毒气，别把小命送掉。\n", "你快不行了，再练会送命的！\n"], "buff_delete": ["wudu_suck"], "callback_functions": [%{"body": "if( me->query_temp("wudu_suck") )
      #           {
      #                   me->delete_temp("wudu_suck");
      #                   tell_object(me, RED "\n只见它的肚子越涨越大，“吧嗒”一声，松"
      #                                   "开口掉在了地上。" + targe", "name": "del_wudusuck", "params": "object me,object target", "return_type": "void"}], "color_codes": ["HIC", "NOR", "RED"], "combat_messages": %{"fail": [], "other": [], "success": []}, "improve_skill": ["improve_skill("], "misc_gates": ["age"], "receive_damage_calls": [%{"formula": "5", "kind": "wound", "part": "qi", "source": None}, %{"formula": "20", "kind": "damage", "part": "qi", "source": None}], "resource_queries": ["neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["if( me->is_busy() )", "if( target->is_fighting() || target->is_busy() )"], "remote_damage": false, "set_flags": [], "temp_set": ["nopoison", "wudu_suck"]}
      #   - if( me->is_busy() )
      #   - if( target->is_fighting() || target->is_busy() )
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

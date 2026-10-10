defmodule Kantele.Combat.Skills.Performs.BingxinJue.Freeze do
  @moduledoc """
  exert「freeze」（source bingxin-jue/freeze.c，由 translate_perform.py 骨架生成，inherit F_CLEAN_UP）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "level_gates": [{"bingxin-jue", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "1000"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能用寒气攻击战斗中的对手。\n", "你的冰心决火候不够，无法运用寒气。\n", "你的内力不够!", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force")", "dp_formula": "me->query_skill("force")"}, "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "默运冰心决，一股寒气迎面扑向$n"
      #                 HIW "，四周登时雪花飘飘。\n" NOR", "= HIY "$n" HIY "感到一阵寒意自心底泛起，连忙"
      #                          "运动抵抗，堪勘无事。\n" NOR"], "success": ["= HIR "$n" HIR "忽然觉得一阵透骨寒意，霎时间"
      #                          "浑身的血液几乎都要凝固了。\n" NOR"]}, "damage_formula": %{"formula": "ap / 3 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "random(dp)"}, "receive_damage_calls": [%{"formula": "damage", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage", "kind": "wound", "part": "qi", "source": "me"}], "resource_adds": [{"neili", "damage"}], "resource_queries": ["neili"], "resource_sets": [{"neili", "0"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "target->start_busy(1);"], "remote_damage": false, "set_flags": [{"neili", "0"}], "temp_set": []}
      #   - me->start_busy(2);
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

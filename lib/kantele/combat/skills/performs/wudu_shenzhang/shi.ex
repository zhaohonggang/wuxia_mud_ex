defmodule Kantele.Combat.Skills.Performs.WuduShenzhang.Shi do
  @moduledoc """
  perform「万毒噬体」（source wudu-shenzhang/shi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "force"}], "level_gates": [{"force", "200"}, {"wudu-shenzhang", "150"}], "map_gates": [], "prepared_gates": [{"strike", "wudu-shenzhang"}], "resource_gates": [{"neili", "120"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"affect_by_callbacks": [%{"buff_name": "wudu_shenzhang", "duration_formula": "ap / 70 + random(ap / 30)", "id_formula": "me->query("id")", "level_formula": "me->query("jiali") + random(me->query("jiali")) + count"}], "all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功不够火候，难以施展", "你的五毒神掌不够娴熟，难以施展", "你现在没有准备五毒神掌，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("force")"}, "callback_functions": [%{"body": "int ap;
      #           int count = 0;
      #           ap = me->query_skill("strike");
      #   
      #           if (target->query("shen") > 0)
      #           {
      #               count += 20;
      #               ap += ap * 10 / 100;", "name": "final", "params": "object me, object target, int damage", "return_type": "string"}], "color_codes": ["CYN", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "将体内真气运于双掌之间，只见双掌微微泛出紫光，猛"
      #                 "地拍向$n。\n" NOR", "= COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70 + count,
      #                                             (: final, me, target, damage :))", "= CYN "可是$p" CYN "眼明手快，侧身一跳$P"
      #                          CYN "已躲过$N这招。\n" NOR"], "success": []}, "damage_formula": %{"formula": "ap + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "misc_gates": ["gender"], "receive_damage_calls": [%{"formula": "8 + random(4)", "kind": "wound", "part": "jing", "source": "me"}], "resource_adds": [{"neili", "-count"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": ["wudu_shenzhang"], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(3));", "me->start_busy(2);", "target->start_busy(1);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(3));
      #   - me->start_busy(2);
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

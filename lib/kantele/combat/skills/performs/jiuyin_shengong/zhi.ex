defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhi do
  @moduledoc """
  perform「九阴神指」（source jiuyin-shengong/zhi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"ap", "unarmed"}, {"dp", "parry"}, {"skill", "jiuyin-shengong"}], "level_gates": [], "map_gates": [], "prepared_gates": [{"finger", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "resource_gates": [{"neili", "250"}], "var_gates": [{"skill", "250"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的九阴神功等级不够，无法施展", "你现在真气不够，难以施展", "你没有准备使用九阴神功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("parry") + target->query_skill("martial-cognize", 1)"}, "color_codes": ["HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "出手成指，随意点戳，似乎看尽了$n" HIY + "招式中的破绽。\n" NOR", "= HIY "$n" HIY "见来指玄幻无比，全然无法抵挡，慌乱之下破绽迭出，$N" HIY "随手连出" + chinese_number(n) + "指！\n" NOR", "HIW "$n" HIW "觉得眼前眼花缭乱，手中的" + weapon->name() +
      #                         HIW "一时竟然拿捏不住，脱手而出！\n" NOR", "HIY "$n勉力抵挡，一时间再也无力反击。\n" NOR", "= HIY "$n" HIY "不及多想，连忙抵挡，全然无法反击。\n" NOR", "= HIC "不过$n" HIC "紧守门户，不露半点破绽。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(2) && !target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(n));", "if (!target->is_busy())", "target->start_busy(4 + random(skill / 30));", "me->start_busy(3 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) && !target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(n));
      #   - if (!target->is_busy())
      #   - target->start_busy(4 + random(skill / 30));
      #   - me->start_busy(3 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

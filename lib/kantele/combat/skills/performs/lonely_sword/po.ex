defmodule Kantele.Combat.Skills.Performs.LonelySword.Po do
  @moduledoc """
  perform「po」（source lonely-sword/po.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"skill", "lonely-sword"}, {"ss", "lonely-sword"}, {"ss", "never-defeated"}, {"ss", "pixie-jian"}], "level_gates": [], "map_gates": [], "prepared_gates": [], "resource_gates": [], "var_gates": [{"skill", "50"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["独孤九剑只能对战斗中的对手使用。\n", "你的独孤九剑等级不够，练好了再来！\n", "你使用的武器不对。\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "skill + me->query_skill("sword", 1) / 2", "dp_formula": "target->query_skill(type, 1) * 2 + ss * 2"}, "color_codes": ["HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "随意挥洒手中的" + weapon->name() + HIC
      #                         "，招招从出其不意的方位直指$n" HIC +
      #                         to_chinese(type)[4..<1] + "中的破绽。\n" NOR", "= HIY "$n" HIY "大吃一惊，慌乱之下破绽迭出，$N" HIY "唰唰连攻" +
      #                                  chinese_number(n) + "剑！\n" NOR", "HIW "\n$n" HIW "觉得眼前眼花缭乱，手中的" + weapon2->name() +
      #                                         HIW "一时竟然拿捏不住，脱手而出！\n" NOR", "HIY "\n$n略得空隙喘息，一时间却也无力反击。\n" NOR", "= HIY "$n" HIY "连忙抵挡，一时间不禁手忙脚乱，无暇反击。\n" NOR", "HIC "$N" HIC "拿着手中的" + weapon->name() + HIC "，东戳西指，"
      #                         "不过$n" HIC "防守的异常严密，$N" HIC "一时竟然无法找到破绽。\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(n));", "if (! target->is_busy() && random(2))", "target->start_busy(1);", "me->start_busy(1);", "target->start_busy(1 + random(skill / 20));", "me->start_busy(3 + random(2));", "target->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(n));
      #   - if (! target->is_busy() && random(2))
      #   - target->start_busy(1);
      #   - me->start_busy(1);
      #   - target->start_busy(1 + random(skill / 20));
      #   - me->start_busy(3 + random(2));
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

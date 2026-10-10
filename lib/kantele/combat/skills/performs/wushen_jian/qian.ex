defmodule Kantele.Combat.Skills.Performs.WushenJian.Qian do
  @moduledoc """
  perform「千剑纵横势」（source wushen-jian/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "level_gates": [{"wushen-jian", "200"}], "map_gates": [{"sword", "wushen-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的衡山五神剑不够娴熟，难以施展", "你的真气不够，难以施展", "你没有激发衡山五神剑，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("dodge")"}, "buff_delete": ["perform_wushenjian/qian"], "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "\n$N" HIW "运转衡山五神剑，手中" + weapon->name() +
      #                 HIW "迸出无数剑光，宛若飞虹擎天，席卷$n" HIW "而去。" NOR", "HIC "$n" HIC "见$N" HIC "这几剑招式凌厉，凶猛异"
      #                         "常，只得苦苦招架。\n" NOR"], "success": ["HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
      #                         HIR "慌忙招架，心中叫苦。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 2)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-attack_time * 30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack", "damage"], "busy_lines": ["me->start_busy(1 + random(attack_time / 2));", "if (! target->is_busy() && random(3) == 1)", "target->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(attack_time / 2));
      #   - if (! target->is_busy() && random(3) == 1)
      #   - target->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

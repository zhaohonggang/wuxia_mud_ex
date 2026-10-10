defmodule Kantele.Combat.Skills.Performs.CanheZhi.Zhi do
  @moduledoc """
  perform「七星指穴」（source canhe-zhi/zhi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "parry"}, {"skill", "canhe-zhi"}], "level_gates": [], "map_gates": [{"finger", "canhe-zhi"}], "prepared_gates": [{"finger", "canhe-zhi"}], "resource_gates": [{"neili", "150"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的参合指修为有限，难以施展", "你的真气不够，难以施展", "你没有激发参合指, 难以施展", "你现在没有准备使用参合指, 难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIG", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIG "$N" HIG "一声冷哼，右手中食两指并拢，斜斜指出，朝$n"
      #                 HIG "凌空虚点七下。\n" NOR", "= CYN "可是$p" CYN "看破了$P"
      #                          CYN "的企图，轻轻一跃，躲开了这一招。\n" NOR"], "success": ["= HIR "结果只听“噗噗噗”数声，$p" HIR "竟被$P"
      #                          HIR "以指力封住穴道，动弹不得。\n" NOR"]}, "hit_formula": %{"left_side": "ap * 2 / 3 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "target->start_busy(ap / 20 + random(4));", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1);
      #   - target->start_busy(ap / 20 + random(4));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

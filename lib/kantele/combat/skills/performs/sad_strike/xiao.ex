defmodule Kantele.Combat.Skills.Performs.SadStrike.Xiao do
  @moduledoc """
  perform「黯然销魂」（source sad-strike/xiao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"lvl", "sad-strike"}], "level_gates": [{"force", "320"}, {"sad-strike", "150"}], "map_gates": [], "prepared_gates": [{"unarmed", "sad-strike"}], "resource_gates": [{"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的真气不够！\n", "你的黯然销魂掌火候不够，无法施展", "你的内功修为不够，无法施展", "你现在没有准备使用黯然销魂掌，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("force")"}, "color_codes": ["HIC", "HIM", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIY "$n" HIY "见$P" HIY "这一招变化莫测，奇幻无"
      #                          "方，不由大吃一惊，慌乱中破绽迭出。\n" NOR", "= HIC "$n" HIC "不敢小觑$P" HIC
      #                          "的来招，腾挪躲闪，小心招架。\n" NOR"], "success": ["HIM "\n$N" HIM "一声长吟：“黯然销魂者，唯别而已矣！”，顿时心如"
      #                 "止水，黯然神伤，于不经意中随手使出了" HIR "『黯然销魂』" HIM "！\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-70 * n"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(2) && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

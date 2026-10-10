defmodule Kantele.Combat.Skills.Performs.QixianWuxingjian.Zhu do
  @moduledoc """
  perform「七弦连环诛」（source qixian-wuxingjian/zhu.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"skill", "qixian-wuxingjian"}], "level_gates": [{"force", "300"}], "map_gates": [{"sword", "qixian-wuxingjian"}], "prepared_gates": [{"unarmed", "qixian-wuxingjian"}], "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "6"}, {"skill", "180"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的内功的修为不够，现在无法使用", "你的七弦无形剑修为有限，现在无法使用", "你的真气不够，无法运用", "你不能使用这种兵器施展", "你现在没有准备使用七弦无形剑，无法施展", "你现在没有准备使用七弦无形剑，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force")"}, "color_codes": ["HIC", "HIR", "HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "只见$N" HIW "双目微闭，单手在" + weapon->name() +
      #                         HIW "上轻轻拨动，顿时只听“啵啵啵”破空之声连续不断"
      #                         "，数股破\n体无形剑气激射而出，直奔$n" HIW "而去。\n" NOR", "HIW "只见$N" HIW "双目微闭，双手轻轻舞弄，陡然间十指一"
      #                         "并箕张，顿时只听“啵啵啵”破空之声连续不\n断，数股破"
      #                         "体无形剑气激射而出，直奔$n" HIW "而去。\n" NOR", "= HIC "$n" HIC "只感到$P" HIC "内力澎湃，汹涌而至，急"
      #                          "忙凝神聚气，小心应付。\n" NOR"], "success": ["= HIR "$p" HIR "只感到$P" HIR "内力澎湃，汹涌而至，霎"
      #                          "时心神惧碎，呆立当场！\n" NOR"]}, "resource_adds": [{"neili", "-250"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-250"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

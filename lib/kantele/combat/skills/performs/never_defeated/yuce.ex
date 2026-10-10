defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Yuce do
  @moduledoc """
  perform「yuce」（source never-defeated/yuce.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "never-defeated"}], "level_gates": [{"never-defeated", "100"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["御策诀只能在战斗中对对手使用。\n", "你现在手中并没有拿着暗器，怎么施展御策诀？\n", "你的不败神功火候不够，不会施展御策诀。\n", "你内力不够了。\n", "对方都已经这样了，用不着这么费力吧？\n"], "amount_calls": [{"query_amount", ""}], "amount_gates": ["1"], "color_codes": ["CYN", "HIC", "HIG", "HIR", "NOR"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "手指一合一弹，只听呼啸破空声起，有若龙吟，一" +
      #                weapon->query("base_unit") + weapon->name() + HIC "如蛟龙般" +
      #                "打向$n" HIC "。\n" NOR", "COMBAT_D->query_ahinfo()))
      #                           msg += pmsg", "= CYN "可是$p" CYN "急忙一闪，躲过了$P" HIG "发出的" +
      #                          weapon->name() + CYN "。\n" NOR"], "success": ["= HIR + "只见那" + weapon->name() + HIR "去势恰如神光闪电！$n"
      #                          HIR + "不及闪避，被打了个正中，惨叫一"
      #                          "声，退了几步。\n" NOR"]}, "hit_ob_calls": [{"me", "target", "me->query("jiali") + 150"}], "receive_damage_calls": [%{"formula": "skill / 2 + random(skill / 2)", "kind": "wound", "part": "qi", "source": "me"}], "reset_action": true, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Lei do
  @moduledoc """
  perform「lei」（source never-defeated/lei.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "never-defeated"}], "level_gates": [{"never-defeated", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["天打雷劈只能在战斗中对对手使用。\n", "你的不败神功还不够娴熟，不能使用天打雷劈！\n", "你必须手持兵刃才能施展天打雷劈！\n", "你的真气不够！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("never-defeated", 1)", "dp_formula": "target->query("combat_exp") / 10000"}, "color_codes": ["HIC", "HIM", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "大喝一声，手中的" + weapon->name() +
      #                 HIC "长劈而下，看似简单，竟然封住了$n"
      #                 HIC "所有的退路！\n" NOR", "= HIY "$n" HIY "使出平生所学，奋力化解，没出一点差错。\n" NOR", "= HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
      #                         "然没有一点伤害，侥幸得脱！\n" NOR"], "success": ["= HIR "$n" HIR "平生何曾见过这样的招数，全然无法化解，"
      #                          HIR "顿时被击中数处要害，颓然倒地！\n" NOR"]}, "exp_compare": [{"ap", "dp"}], "resource_adds": [{"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(2));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(2));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

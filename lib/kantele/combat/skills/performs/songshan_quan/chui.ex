defmodule Kantele.Combat.Skills.Performs.SongshanQuan.Chui do
  @moduledoc """
  perform「千斤锤」（source songshan-quan/chui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "cuff"}, {"damage", "songshan-quan"}, {"dp", "parry"}], "level_gates": [{"force", "40"}, {"songshan-quan", "30"}], "map_gates": [], "prepared_gates": [{"cuff", "songshan-quan"}], "resource_gates": [{"neili", "120"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你嵩山拳法不够娴熟，难以施展", "你没有准备嵩山拳法，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("cuff")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "双拳挥出，施一招「" HIG "千斤锤"
      #                 HIC "」，拳速极快，部位极准，" HIC "分袭$n" HIC "面"
      #                 "门和胸口。\n" NOR", "CYN "$n" CYN "不慌不忙，以快打快，将$N"
      #                         CYN "这招化去。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
      #                                             HIR "$N" HIR "出手既快，方位又奇，$n"
      #                                             HIR "闪避不及，闷哼一声，已然中拳。\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("songshan-quan", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-30"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-30"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(2));
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.ShiyingLianhuan.Sha do
  @moduledoc """
  perform「无痕杀」（source shiying-lianhuan/sha.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "blade"}, {"dp", "dodge"}], "level_gates": [{"force", "200"}, {"shiying-lianhuan", "150"}], "map_gates": [{"blade", "shiying-lianhuan"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功修为不够，难以施展", "你弑鹰九连环修为不够，难以施展", "你没有激发弑鹰九连环，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("blade")", "dp_formula": "target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "NOR", "RED"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "见$P" CYN "来势汹涌，连忙飞"
      #                          "身向后挪移数尺，躲闪开来。\n" NOR"], "success": ["HIR "$N" HIR "回转手中" + weapon->name() + HIR "施出「" NOR +
      #                 RED "无痕杀" HIR "」绝技，刀身顿时漾起一道血色刀芒，直斩$n"
      #                 HIR "而去！\n" NOR", "= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
      #                                              HIR "只听“嗤啦”一声，$n" HIR "被$N"
      #                                              HIR "的刀芒划中气门，登时痛声长呼，几"
      #                                              "欲晕倒。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-250"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-250"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

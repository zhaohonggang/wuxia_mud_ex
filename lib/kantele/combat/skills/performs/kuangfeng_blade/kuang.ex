defmodule Kantele.Combat.Skills.Performs.KuangfengBlade.Kuang do
  @moduledoc """
  perform「kuang」（source kuangfeng-blade/kuang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"damage", "blade"}], "level_gates": [{"kuangfeng-blade", "70"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你只能对战斗中的对手使用「狂风二十一式」。\n", "你目前功力还使不出「狂风二十一式」。\n", "你的内力不够。\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "淡然一笑，本就快捷绝伦的刀法骤然变"
      #                 "得更加凌厉！就在这一瞬之间，$N" HIC "已劈出二十"
      #                 "一刀！\n刀夹杂着风，风里含着刀影！$n"
      #                 HIC "只觉得心跳都停止了！\n" NOR", "= HIC "可是$p" HIC "急忙抽身躲开，使$P"
      #                          HIC "这招没有得逞。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40, 
      #                                              HIR "只见$n" HIR "已被$N" HIR
      #                                              "切得体无完肤，血如箭般由全身喷射而出！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("blade")"}, "resource_adds": [{"neili", "-60"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "target->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - target->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

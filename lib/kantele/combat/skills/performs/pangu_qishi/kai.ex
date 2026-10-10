defmodule Kantele.Combat.Skills.Performs.PanguQishi.Kai do
  @moduledoc """
  perform「开天辟地」（source pangu-qishi/kai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hammer"}, {"dp", "force"}], "level_gates": [{"force", "300"}, {"pangu-qishi", "180"}], "map_gates": [{"hammer", "pangu-qishi"}], "prepared_gates": [], "resource_gates": [{"neili", "400"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功的修为不够，难以施展", "你的盘古七势修为不够，难以施展", "你的真气不够，难以施展", "你没有激发盘古七势，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hammer") + me->query("str") * 10", "dp_formula": "target->query_skill("force") + target->query("con") * 10"}, "color_codes": ["HIC", "HIR", "HIY", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "一声断喝，手中" + weapon->name() +
      #                 WHT "如山岳巍峙，携着开天辟地之势向$n" WHT "猛劈而下！\n" NOR", "= HIC "可是$n" HIC "真气鼓荡，$N" HIC "雷霆般"
      #                          "的劲力竟如中败絮，登时被解于无形。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
      #                                              HIR "$n" HIR "躲避不及，被$N" HIR "这"
      #                                              "锤正中胸口，顿时一声闷响，稻草般向后"
      #                                              "横飞出去。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-300"}, {"neili", "-500"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "hammer"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}, {"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

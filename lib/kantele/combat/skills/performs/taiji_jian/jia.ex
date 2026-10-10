defmodule Kantele.Combat.Skills.Performs.TaijiJian.Jia do
  @moduledoc """
  perform「驾字诀」（source taiji-jian/jia.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "sword"}, {"dp", "parry"}, {"skill", "taiji-jian"}], "level_gates": [], "map_gates": [{"sword", "taiji-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "150"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的太极剑法等级不够，难以施展", "你的真气不够，难以施展", "你没有激发太极剑法，难以施展", "对方没有使用兵器，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("sword")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "只见$N" HIC "收摄心神，以剑意运剑，手中" + wn1 + HIC "每剑均以弧形"
      #                 "刺出，弧形收回，每发一招都似放\n出一条细丝，要去缠在$n" HIC "的" + wn2 +
      #                 HIC "之上。\n" NOR", "= CYN "$n" CYN "不禁大惊失色，急忙跃开数步，方才摆脱$N"
      #                          CYN "的力道。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 10,
      #                                              HIR "却见$n" HIR "手中" + wn2 + HIR "被" +
      #                                              wn1 + HIR "缠住后不断增加重量，招数顿见涩"
      #                                              "滞，真力不由狂泻而出。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 8 + random(ap / 8)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap * 4 / 3)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-10"}, {"neili", "-30"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-10"}, {"neili", "-30"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1);
      #   - if (ap / 2 + random(ap) > dp && ! target->is_busy())
      #   - target->start_busy(ap / 30 + 2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

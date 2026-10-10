defmodule Kantele.Combat.Skills.Performs.ShenghuoLing.Can do
  @moduledoc """
  perform「残血令」（source shenghuo-ling/can.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "shenghuo-ling"}, {"skill", "shenghuo-ling"}], "level_gates": [{"force", "350"}], "map_gates": [{"sword", "shenghuo-ling"}], "prepared_gates": [], "resource_gates": [{"max_neili", "5000"}, {"neili", "400"}], "var_gates": [{"i", "7"}, {"skill", "220"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的兵器不对，不能使用圣火令法之", "你的圣火令法等级不够, 不能使用圣火令", "你的内功火候不够，不能使用圣火令法之", "你的内力修为不足，不能使用圣火令法之", "你的内力不够，不能使用圣火令法之", "你没有激发圣火令法，无法使用", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIY", "NOR"], "combat_exp_formulas": [{"lvl", "to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3))"}], "combat_messages": %{"fail": [], "other": ["= HIY "$n" HIY "见$N" HIY "来势汹涌，心底一惊，打起精"
      #                          "神小心接招。\n" NOR"], "success": ["HIR "$N" HIR "一声长啸，手中" + weapon->name() +
      #                 HIR "一转，招数顿时变得诡异无比，从意想不到的方"
      #                 "位攻向$n" HIR "！\n" NOR", "= HIR "$n" HIR "完全无法看透$N" HIR "招中虚实，不由得心"
      #                          "生惧意，招式一滞，登时破绽百出。\n" NOR"]}, "resource_adds": [{"neili", "-300"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-300"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

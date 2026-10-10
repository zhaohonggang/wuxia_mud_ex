defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhang do
  @moduledoc """
  perform「九阴神掌」（source jiuyin-shengong/zhang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "jiujin-shengong"}, {"dp", "parry"}], "level_gates": [{"jiuyin-shengong", "260"}, {"strike", "220"}], "map_gates": [], "prepared_gates": [{"strike", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "resource_gates": [], "var_gates": [{"i", "9"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "此招只能空手施展！\n", "你的九阴神功不够深厚，不会使用", "你的基本掌法修为不够，不会使用", "你没有准备使用九阴神功，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("jiujin-shengong", 1)", "dp_formula": "target->query_skill("parry", 1)"}, "color_codes": ["HIM", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "双掌一错，幻化出无数掌影，层层叠荡向$n" HIY "逼去！\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-320"}], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-320"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(2) == 1 && !target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) == 1 && !target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

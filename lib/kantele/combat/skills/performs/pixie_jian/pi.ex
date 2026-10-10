defmodule Kantele.Combat.Skills.Performs.PixieJian.Pi do
  @moduledoc """
  perform「群邪辟易」（source pixie-jian/pi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "dodge"}, {"dp", "dodge"}, {"skill", "pixie-jian"}], "level_gates": [], "map_gates": [{"sword", "pixie-jian"}], "prepared_gates": [{"unarmed", "pixie-jian"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "9"}, {"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的辟邪剑法不够娴熟，难以施展", "你现在的真气不足，难以施展", "你没有准备使用辟邪剑法，难以施展", "你没有准备使用辟邪剑法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("dodge", 1)", "dp_formula": "target->query_skill("dodge", 1)"}, "color_codes": ["HIW", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "$N" HIW "身形忽然变快，蓦的冲向$n" HIW "，" + name +
      #                 HIW "幻作数道虚影，顿时无数星光一齐射向$n" HIW "！\n" NOR"], "success": []}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": ["attack", "damage", "unarmed_damage"], "busy_lines": ["if (random(3) == 0 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(7));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 0 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(7));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

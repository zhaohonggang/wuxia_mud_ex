defmodule Kantele.Combat.Skills.Performs.BaguaDao.Tian do
  @moduledoc """
  perform「天刀八势」（source bagua-dao/tian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "bagua-dao"}], "level_gates": [{"bagua-dao", "200"}, {"nei-bagua", "200"}, {"wai-bagua", "200"}], "map_gates": [{"blade", "bagua-dao"}], "prepared_gates": [], "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "8"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的八卦刀法不够娴熟，难以施展", "你的外八卦神功不够娴熟，难以施展", "你的内八卦神功不够娴熟，难以施展", "你的内功修为不足，难以施展", "你现在真气不够，难以施展", "你没有激发八卦刀法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "buff_delete": ["pfm_tiandao"], "color_codes": ["HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": []}, "resource_adds": [{"neili", "-250"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-250"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(8));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(8));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

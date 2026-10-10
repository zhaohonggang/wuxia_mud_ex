defmodule Kantele.Combat.Skills.Performs.FengmoZhang.Luan do
  @moduledoc """
  perform「群魔乱舞」（source fengmo-zhang/luan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"fengmo-zhang", "120"}, {"force", "150"}], "map_gates": [{"staff", "fengmo-zhang"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你疯魔杖法火候不够，难以施展", "你没有激发疯魔杖法，难以施展", "你的内功火候不够，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIY "$N" HIY "眼中杀气大盛，施出疯魔杖「" HIR "群魔乱舞"
      #                 HIY "」绝技，手中" + weapon->name() + HIY "接二连三朝$n"
      #                 HIY "挥去。\n" NOR"]}, "resource_adds": [{"neili", "-100"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(2) && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(5));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(2) && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(5));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.JingzhongBafa.Bafa do
  @moduledoc """
  perform「bafa」（source jingzhong-bafa/bafa.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "300"}, {"jingzhong-bafa", "200"}], "map_gates": [{"blade", "jingzhong-bafa"}], "prepared_gates": [], "resource_gates": [{"neili", "500"}], "var_gates": [{"i", "8"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["井中八法只能对战斗中的对手使用。\n", "手中没刀还使什么井中八法。\n", "你的真气不够！\n", "你的内功火候不够！\n", "你的井中八法还不到家，无法施展绝招。\n", "你没有激发井中八法，无法施展绝招。\n"], "color_codes": ["HIC", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "一声清啸，手中的" + weapon->name() +
      #                 HIY "将「井中八法」一齐施出，刀法变化莫测，笼罩了$n" HIY "周身要害！\n" NOR", "= HIC "$n" HIC "心底微微一惊，打起精神小心接招。\n" NOR"], "success": ["= HIR "$n" HIR "见来招实在是变幻莫测，不由得心"
      #                          "生惧意，招式登时出了破绽！\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": false, "uses_offensive_target": false}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.XuedaoDafa.Chi do
  @moduledoc """
  perform「赤炼神刀」（source xuedao-dafa/chi.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "xuedao-dafa"}], "level_gates": [{"force", "220"}, {"xuedao-dafa", "160"}], "map_gates": [{"blade", "xuedao-dafa"}, {"force", "xuedao-dafa"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的血刀大法还不到家，难以施展", "你没有激发血刀大法为内功，难以施展", "你没有激发血刀大法为刀法，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIY "霎时间$n" HIY "只觉周围四处杀气弥漫，心底微微一"
      #                          "惊，连忙奋力招架。\n" NOR"], "success": ["HIW "$N" HIW "嗔目大喝，手中" + weapon->name() + HIW "一势「"
      #                 HIR "赤炼神刀" HIW "」迸出漫天血光，铺天盖地洒向$n" HIW "。\n" NOR", "= HIR "霎时间$n" HIR "只觉周围四处杀气弥漫，全身气血翻"
      #                          "滚，甚难招架。\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "blade"}
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

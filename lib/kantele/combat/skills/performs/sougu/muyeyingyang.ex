defmodule Kantele.Combat.Skills.Performs.Sougu.Muyeyingyang do
  @moduledoc """
  perform「muyeyingyang」（source sougu/muyeyingyang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"sougu", "150"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "800"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["牧野鹰扬只能对战斗中的对手使用。\n", "你臂力不够,不能使用牧野鹰扬！\n", "你的搜骨鹰爪功修为不够,目前还不能使用牧野鹰扬！\n", "你内力现在不够, 不能使用牧野鹰扬！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "使出搜骨鹰爪功绝技「牧野鹰扬」，双爪蓦地抓向$n"
      #                 HIY "的全身要穴。\n" NOR", "= HIG "可是$p" HIG "看破了$P" HIG "的企图，并没有上当。\n" NOR"], "success": ["= HIR "结果$p" HIR "被$P" HIR "点中要穴，立时动弹不得！\n" NOR"]}, "resource_adds": [{"neili", "-150"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy( (int)me->query_skill("sougu",1) / 22 + 1);", "me->start_busy(4);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy( (int)me->query_skill("sougu",1) / 22 + 1);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

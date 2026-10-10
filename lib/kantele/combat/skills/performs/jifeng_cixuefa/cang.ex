defmodule Kantele.Combat.Skills.Performs.JifengCixuefa.Cang do
  @moduledoc """
  perform「天蝎藏针」（source jifeng-cixuefa/cang.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"skill", "jifeng-cixuefa"}], "level_gates": [{"dodge", "120"}, {"force", "120"}], "map_gates": [{"dagger", "jifeng-cixuefa"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "5"}, {"skill", "100"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你所使用的武器不对，难以施展", "你的内功修为不够，难以施展", "你的轻功修为不够，难以施展", "你的疾风刺穴法修为有限，难以施展", "你现在的真气不足，难以施展", "你没有激发疾风刺穴法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "一声叱喝，手中" + weapon->name() + HIY "连环五刺，招数"
      #                 "层出不穷，闪电般朝$n" HIY "射去！\n" NOR"], "success": []}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "dagger"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1 + random(4));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

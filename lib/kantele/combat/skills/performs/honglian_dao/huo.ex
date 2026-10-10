defmodule Kantele.Combat.Skills.Performs.HonglianDao.Huo do
  @moduledoc """
  perform「流星火雨」（source honglian-dao/huo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [], "level_gates": [{"force", "120"}, {"honglian-dao", "80"}], "map_gates": [{"blade", "honglian-dao"}], "prepared_gates": [], "resource_gates": [{"max_neili", "800"}, {"neili", "100"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你红莲刀法不够娴熟，难以施展", "你的内力修为不够，难以施展", "你现在真气不够，难以施展", "你没有激发红莲刀法，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIR", "NOR"], "combat_messages": %{"fail": [], "other": [], "success": ["HIR "$N" HIR "施出红莲刀法绝技，手中" + weapon->name() +
      #                 HIR "运转如飞，激起层层热浪席卷$n" HIR "周身！\n" NOR"]}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
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

defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Xuan do
  @moduledoc """
  perform「xuan」（source bluesea-force/xuan.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "bluesea-force"}, {"lvl", "bluesea-force"}], "level_gates": [{"bluesea-force", "150"}], "map_gates": [{"strike", "bluesea-force"}], "prepared_gates": [{"strike", "bluesea-force"}], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["玄黄连环掌只能对战斗中的对手使用。\n", "你的真气不够，无法施展玄黄连环掌！\n", "你的南海玄功火候不够，无法施展玄黄连环掌！\n", "你没有激发南海玄功为掌法，无法施展玄黄连环掌！\n", "你没有准备好使用南海玄功，无法施展玄黄连环掌！\n", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "轻轻划了个圈子，身形忽然变快，合数招为一击攻向$n"
      #                 HIC "！\n" NOR", "= HIY "内力激荡之下，$n" HIY "登时觉得呼吸"
      #                          "不畅，浑身有如重压，万分难受，只见$N"
      #                          HIY "一掌接一掌的攻到，有如海浪。\n" NOR", "= CYN "$n" CYN "见来掌奇快，只好振作精神勉力抵挡。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-i * 20"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (i > 4 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(7));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (i > 4 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(7));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

defmodule Kantele.Combat.Skills.Performs.ZileiJian.Feng do
  @moduledoc """
  perform「狂风式」（source zilei-jian/feng.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "sword"}], "level_gates": [{"dodge", "150"}, {"zilei-jian", "100"}], "map_gates": [{"sword", "zilei-jian"}], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你紫雷剑法不够娴熟，难以施展", "你没有激发紫雷剑法，难以施展", "你的轻功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "将" + wn + HIC "横于胸前，内力贯于剑身，"
      #                 "猛然间" + wn + HIC "如一条长龙般挥出，霎时狂沙满天，令"
      #                 "人匪夷所思。" NOR", "HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
      #                         "护住自己全身，一时竟无以应对！\n" NOR", "CYN "可是$N" CYN "镇定自若，小心拆招，没有被"
      #                         "$n" NOR + CYN "招式所困。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "sword"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(2 + random(level / 24));", "me->start_busy(random(2));", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(2 + random(level / 24));
      #   - me->start_busy(random(2));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

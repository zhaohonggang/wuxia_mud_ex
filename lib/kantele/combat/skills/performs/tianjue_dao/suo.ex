defmodule Kantele.Combat.Skills.Performs.TianjueDao.Suo do
  @moduledoc """
  perform「天绝锁」（source tianjue-dao/suo.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"level", "tianjue-dao"}], "level_gates": [{"tianjue-dao", "50"}], "map_gates": [{"blade", "tianjue-dao"}], "prepared_gates": [], "resource_gates": [{"neili", "120"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你天绝刀法不够娴熟，难以施展", "你没有天绝刀法，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIC", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "怒啸一声，施展出绝招「" HIW "天绝锁" HIC "」"
      #                 "将手中" + wn + HIC "挥舞得密不透风，猛然间风声大作，竟将$n" HIC
      #                 "笼罩在刀风之下。"NOR", "HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
      #                         "护住自己全身，一时竟无以应对！\n" NOR", "CYN "可是$N" CYN "镇定自若，小心拆招，没有被"
      #                         "$n" NOR + CYN "招式所困。\n" NOR"], "success": []}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "blade"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(2 + random(level / 26));", "me->start_busy(random(2));", "me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(2 + random(level / 26));
      #   - me->start_busy(random(2));
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

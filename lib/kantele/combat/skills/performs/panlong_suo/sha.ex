defmodule Kantele.Combat.Skills.Performs.PanlongSuo.Sha do
  @moduledoc """
  perform「绝命七杀」（source panlong-suo/sha.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"count", "whip"}], "level_gates": [{"force", "220"}, {"panlong-suo", "180"}], "map_gates": [{"whip", "panlong-suo"}], "prepared_gates": [], "resource_gates": [{"neili", "300"}], "var_gates": [{"i", "6"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你使用的武器不对，难以施展", "你的内功火候不够，难以施展", "你的霹雳盘龙索还不到家，难以施展", "你没有激发霹雳盘龙索，难以施展", "你的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIC "$n" HIC "心底一惊，连忙全神应对，不敢有"
      #                          "丝毫大意。\n" NOR"], "success": ["HIR "突然间$N" HIR "猛的猱身扑上，手中" + weapon->name() +
      #                 HIR "急转，便似不要命般地向$n" HIR "猛攻过去。\n" NOR", "= HIR "$n" HIR "卒不及防，登时手忙脚乱，招架疏"
      #                          "散，慌忙中难以抵挡。\n" NOR"]}, "resource_adds": [{"neili", "-180"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-180"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(1 + random(6));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

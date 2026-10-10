defmodule Kantele.Combat.Skills.Performs.YinsuoJinling.Dian do
  @moduledoc """
  perform「隔空点穴」（source yinsuo-jinling/dian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"time", "yinsuo-jinling"}], "level_gates": [{"force", "100"}, {"yinsuo-jinling", "80"}], "map_gates": [{"whip", "yinsuo-jinling"}], "prepared_gates": [], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的武器不对，无法施展", "你的银索金铃级别不够，无法施展", "你的内功修为不够，无法施展", "你现在真气不够，无法施展", "你没有激发银索金铃，无法施展", "对方都已经这样了，用不着这么费力吧？\n"], "color_codes": ["CYN", "HIG", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "\n$N" HIY "单手一抖，手中" + weapon->name() +
      #                 HIY "疾颤三下，分点$n" HIY "脸上「迎香」、「承泣"
      #                 "」、「人中」三个穴道，这三下点穴出手之快、认位之"
      #                 "准，实是武林罕见！" NOR", "CYN "可是$p" CYN "看破了$P"
      #                         CYN "的企图，斜跳躲闪开来。\n" NOR"], "success": ["HIR "$n" HIR "只听$N" + weapon->name() +
      #                         HIR "发出玎玎声响，声虽不大，却是"
      #                         "十分怪异，入耳荡心摇魄，一不\n留神"
      #                         "，被这招点个正着，全身瘫软无力，动"
      #                         "弹不得！\n" NOR"]}, "resource_adds": [{"neili", "-120"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "whip"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-120"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "me->start_busy(1 + random(2));", "target->start_busy(time);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - me->start_busy(1 + random(2));
      #   - target->start_busy(time);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

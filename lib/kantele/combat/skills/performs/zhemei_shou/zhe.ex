defmodule Kantele.Combat.Skills.Performs.ZhemeiShou.Zhe do
  @moduledoc """
  perform「折梅式」（source zhemei-shou/zhe.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "hand"}, {"dp", "parry"}, {"skill", "zhemei-shou"}], "level_gates": [{"force", "120"}], "map_gates": [{"hand", "zhemei-shou"}], "prepared_gates": [{"hand", "zhemei-shou"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "80"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的逍遥折梅手等级不够，难以施展", "你内功火候不够，难以施展", "你没有激发逍遥折梅手，难以施展", "你没有准备使用逍遥折梅手，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("hand")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "合逍遥折梅手诸多变化为一式，随手轻轻挥出，虚虚"
      #                 "实实笼罩$n" HIC "全身诸处要穴。\n" NOR", "= CYN "可是$p" CYN "的看破了$P" CYN "的企图，丝"
      #                         "毫不为所动，让$P" CYN "的虚招没有起得任何作用。\n" NOR"], "success": ["= HIR "$n" HIR "心头一颤，想不出破解之法，急忙后"
      #                         "退数步，一时间无法反击。\n" NOR"]}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-30"}, {"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-30"}, {"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(1);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - if (target->is_busy())
      #   - target->start_busy(ap / 30 + 2);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

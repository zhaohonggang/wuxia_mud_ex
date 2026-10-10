defmodule Kantele.Combat.Skills.Performs.GuzhuoZhang.Zhen do
  @moduledoc """
  perform「反璞归真」（source guzhuo-zhang/zhen.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "force"}], "level_gates": [{"force", "300"}, {"guzhuo-zhang", "220"}], "map_gates": [{"strike", "guzhuo-zhang"}], "prepared_gates": [{"strike", "guzhuo-zhang"}], "resource_gates": [{"max_neili", "3600"}, {"neili", "500"}], "var_gates": [{"i", "4"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你内功修为不够，难以施展", "你内力修为不够，难以施展", "你古拙掌法火候不够，难以施展", "你没有激发古拙掌法，难以施展", "你没有准备古拙掌法，难以施展", "你现在真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query("str") * 8", "dp_formula": "target->query_skill("force") + target->query("int") * 8"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIW "陡然间$N" HIW "施出「" HIY "璞" HIW "」字诀，双掌向$n"
      #                 HIW "平平推去，招数朴实无华，毫无半点花巧可言。\n" NOR", "= CYN "$n" CYN "见$N" CYN "这掌来势非凡，不敢"
      #                          "轻易招架，当即飞身纵跃闪开。\n" NOR", "= HIW "\n紧接着$N" HIW "变招「" HIY "真" HIW "」字诀，霎"
      #                  "时只见$N" HIW "双掌纷飞，化出漫天掌影笼罩$n" HIW "四面"
      #                  "八方。\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              HIR "$n" HIR "勘破不透掌中虚实，$N" HIR
      #                                              "双掌正中$p" HIR "前胸，“喀嚓喀嚓”接"
      #                                              "连断了数根肋骨。\n" NOR)"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-400"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-400"}], "affect_by": [], "apply_adds": [], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(2 + random(4));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(2 + random(4));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

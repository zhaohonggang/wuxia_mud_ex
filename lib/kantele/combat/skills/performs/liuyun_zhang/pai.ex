defmodule Kantele.Combat.Skills.Performs.LiuyunZhang.Pai do
  @moduledoc """
  perform「排山倒海」（source liuyun-zhang/pai.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"damage", "liuyun-zhang"}, {"dp", "parry"}], "level_gates": [{"force", "180"}, {"liuyun-zhang", "140"}], "map_gates": [{"strike", "liuyun-zhang"}], "prepared_gates": [{"strike", "liuyun-zhang"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你流云掌不够娴熟，难以施展", "你没有激发流云掌，难以施展", "你没有准备流云掌，难以施展", "你的内功修为不够，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIC", "HIM", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "\n$N" HIC "运转真气，将内力注于掌风之中，双掌猛"
      #                 "然拍向$n" HIC "，雄浑有力，气势磅礴，毫无滞带，正是"
      #                 "衡山派绝学「" HIM "排山倒海" HIC "」。" NOR", "CYN "$n" CYN "见$N" CYN "这掌拍来，内力"
      #                         "充盈，只得向后一纵，才躲过这一掌。\n" NOR"], "success": ["COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "但见$N" HIR "双掌拍来，掌风作响，"
      #                                              "当真迅捷无比。$n" HIR "顿觉心惊胆战，"
      #                                              "毫无招架之力，微作迟疑间$N" HIR "这掌"
      #                                              "已正中$n" HIR "胸口，顿将$p震退数步。"
      #                                              " \n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("liuyun-zhang", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-100"}, {"neili", "-200"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

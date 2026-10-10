defmodule Kantele.Combat.Skills.Performs.WushengZhao.Lian do
  @moduledoc """
  perform「夺命连环」（source wusheng-zhao/lian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "claw"}, {"dp", "parry"}, {"skill", "wusheng-zhao"}], "level_gates": [], "map_gates": [{"claw", "wusheng-zhao"}], "prepared_gates": [{"claw", "wusheng-zhao"}], "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "120"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你必须空手才能使用", "你的五圣毒爪等级不够，难以施展", "你的真气不够，难以施展", "你没有激发五圣毒爪，难以施展", "你没有准备使用五圣毒爪，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("claw")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "身形一展，扑至$n" HIY "跟前，猛然施展「夺"
      #                 "命连环」，双爪幻作数道金光，直琐$n" HIY "各处要脉！\n" NOR", "= CYN "可是$p" CYN "的看破了$P" CYN
      #                          "的招式，巧妙的一一拆解，没露半点破绽！\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
      #                                              HIR "$p" HIR "奋力抵抗，结果还是连中$P"
      #                                              HIR "数抓，登时鲜血飞溅，无法反击！\n" NOR)"]}, "damage_formula": %{"formula": "60 + ap / 5 + random(ap / 5)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(1);", "if (ap / 3 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 25 + 2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(1);
      #   - if (ap / 3 + random(ap) > dp && ! target->is_busy())
      #   - target->start_busy(ap / 25 + 2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

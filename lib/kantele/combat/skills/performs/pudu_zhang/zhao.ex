defmodule Kantele.Combat.Skills.Performs.PuduZhang.Zhao do
  @moduledoc """
  perform「zhao」（source pudu-zhang/zhao.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "staff"}, {"damage", "staff"}, {"dp", "force"}], "level_gates": [{"force", "200"}, {"pudu-zhang", "135"}], "map_gates": [{"staff", "pudu-zhang"}], "prepared_gates": [], "resource_gates": [{"neili", "1000"}], "var_gates": [{"damage", "0"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["「佛光普照」只能在战斗中对对手使用。\n", "你使用的武器不对。\n", "你的内功的修为不够，不能使用这一绝技！\n", "你的普渡杖法修为不够，目前不能使用佛光普照！\n", "你的真气不够，不能使用佛光普照！\n", "你没有激发普渡杖法，不能使用佛光普照！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("staff") + me->query("max_neili") / 10", "dp_formula": "target->query_skill("force") + target->query("max_neili") / 10"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "纵声长笑，挥动手中的" + weapon->name() +
      #                 HIY "，如泰山一般压向$n" + HIY "，令人叹为观止！\n" NOR", "= CYN "可是$p" CYN "运足内力，奋力挡住了"
      #                          CYN "$P" CYN "这惊天动地的一击！\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #                                              HIR "只见$p" HIR "闷哼一声，连叫都叫"
      #                                              "不出来，身子飞跌出去，重重的摔倒在地上！\n" NOR)"]}, "damage_formula": %{"formula": "me->query("max_neili") - target->query("max_neili")"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-250"}, {"neili", "-60"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "staff"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-250"}, {"neili", "-60"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(3);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

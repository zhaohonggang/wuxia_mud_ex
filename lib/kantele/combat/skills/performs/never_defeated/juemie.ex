defmodule Kantele.Combat.Skills.Performs.NeverDefeated.Juemie do
  @moduledoc """
  perform「juemie」（source never-defeated/juemie.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "never-defeated"}, {"dp", "dodge"}], "level_gates": [{"never-defeated", "120"}], "map_gates": [], "prepared_gates": [], "resource_gates": [{"neili", "200"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["天地绝灭只能对战斗中的对手使用。\n", "你的不败神功还不够娴熟，不能使用天地绝灭！\n", "你必须手持兵刃才能施展天地绝灭！\n", "你的内力不够，不能使用天地绝灭！\n", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("never-defeated", 1) * 3 / 2 + me->query("int") * 20 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 20 +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["HIC", "HIG", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["HIC "$N" HIC "随便走了几步，忽然一荡手中的" + weapon->name() +
      #                 HIC "，迅捷无比的扫向$n" HIC "，变化复杂之极，不可思议！\n" NOR", "= HIG "只见$n" HIG "并不慌张，只是轻轻一闪，就躲过了$N"
      #                      HIG "这一击！\n"NOR"], "success": ["= COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                                              HIR "$n" HIR "连忙格挡，可是这一招实在是鬼神莫"
      #                                              "测，哪里琢磨得透？登时中了$P" HIR "的重创！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-50"}, {"neili", "-70"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-50"}, {"neili", "-70"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

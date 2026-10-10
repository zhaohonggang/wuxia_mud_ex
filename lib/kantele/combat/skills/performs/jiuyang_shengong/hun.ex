defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Hun do
  @moduledoc """
  perform「混沌一阳」（source jiuyang-shengong/hun.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "jiuyang-shengong"}, {"dp", "force"}], "level_gates": [{"jiuyang-shengong", "180"}], "map_gates": [{"force", "jiuyang-shengong"}, {"unarmed", "jiuyang-shengong"}], "prepared_gates": [{"unarmed", "jiuyang-shengong"}], "resource_gates": [{"neili", "300"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的九阳神功还不够娴熟，难以施展", "你现在没有激发九阳神功为拳脚，难以施展", "你现在没有激发九阳神功为内功，难以施展", "你现在没有准备使用九阳神功，难以施展", "你的内力不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("jiuyang-shengong", 1) * 2 + me->query("con") * 10 +
      #                me->query_skill("martial-cognize", 1)", "dp_formula": "target->query_skill("force") + target->query("con") * 10 +
      #                target->query_skill("martial-cognize", 1)"}, "color_codes": ["HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= HIY "然而$n" HIY "全力抵挡，终于将$N" HIY
      #                          "发出的气团拨开。\n" NOR"], "success": ["HIR "$N" HIR "跨前一步，双手回圈，颇得太极之意。掌心顿时闪"
      #                 "出一个气团，向$n" HIR "电射而去。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50,
      #                                              HIR "$n" HIR "急忙抽身后退，可是气团射"
      #                                              "得更快，只听$p" HIR "一声惨叫，鲜血飞"
      #                                              "溅！\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": "<", "right_side": "dp"}, "resource_adds": [{"neili", "-200"}, {"neili", "-50"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": false}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(1);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(1);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

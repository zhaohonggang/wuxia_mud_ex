defmodule Kantele.Combat.Skills.Performs.WudoumiShengong.Gui do
  @moduledoc """
  perform「归去来兮」（source wudoumi-shengong/gui.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"damage", "wudoumi-shengong"}, {"dp", "dodge"}], "level_gates": [{"force", "200"}, {"wudoumi-shengong", "140"}], "map_gates": [{"force", "wudoumi-shengong"}, {"unarmed", "wudoumi-shengong"}], "prepared_gates": [{"unarmed", "wudoumi-shengong"}], "resource_gates": [{"neili", "800"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "只有空手才能施展", "你的内功修为不够，难以施展", "你的五斗米神功不够娴熟，难以施展", "你现在真气不够，难以施展", "你没有激发五斗米神功为内功，难以施展", "你没有激发五斗米神功为拳脚，难以施展", "你现在没有准备使用五斗米神功，难以施展", "你未将全身功力尽数提起，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") + me->query("con") * 10", "dp_formula": "target->query_skill("dodge") + target->query("dex") * 10"}, "color_codes": ["CYN", "HIR", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$p" CYN "见$P" CYN "来势汹涌，不敢硬接"
      #                          "，只得小巧腾挪，躲闪开来。\n" NOR", "= CYN "$p" CYN "大惊之下急忙飞身跃起，终于躲开"
      #                          "了这神鬼莫测的一击。\n" NOR"], "success": ["HIR "$N" HIR "一声断喝，双掌施出五斗米神功「归去来兮」绝技，顿时掌"
      #                 "劲澎湃，涌向$n" HIR "。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
      #                                              HIR "$p" HIR "急忙奋力格挡，可只一瞬间"
      #                                              "，$P" HIR "的掌劲已透体而入，接连震断"
      #                                              "数根肋骨！\n" NOR)", "= "\n" HIR "紧接着只见$N" HIR "双手陡然回圈，竟使已袭出的掌劲倒回"
      #                  "，从$n" HIR "身后再度席卷而归。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70,
      #                                              HIR "$p" HIR "大惊之下，竟然僵直而立，$P"
      #                                              HIR "澎湃的掌劲顿时穿透胸膛，尽伤五脏六"
      #                                              "腑！\n" NOR)"]}, "damage_formula": %{"formula": "(int)me->query_skill("wudoumi-shengong", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-500"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-500"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

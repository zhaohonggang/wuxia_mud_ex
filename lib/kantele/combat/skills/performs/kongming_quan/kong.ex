defmodule Kantele.Combat.Skills.Performs.KongmingQuan.Kong do
  @moduledoc """
  perform「空空如也」（source kongming-quan/kong.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "unarmed"}, {"damage", "force"}, {"dp", "parry"}], "level_gates": [{"kongming-quan", "150"}], "map_gates": [{"unarmed", "kongming-quan"}], "prepared_gates": [{"unarmed", "kongming-quan"}], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的空明拳不够娴熟，难以施展", "你没有激发空明拳，难以施展", "你没有准备空明拳，难以施展", "你现在的真气太弱，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("unarmed")", "dp_formula": "target->query_skill("parry")"}, "color_codes": ["CYN", "HIG", "HIR", "NOR", "WHT"], "combat_messages": %{"fail": [], "other": ["WHT "$N" WHT "使出空明拳「" HIG "空空如也" NOR + WHT "」，拳劲"
      #                 "虚虚实实，变化莫测，让$n" WHT "一时难以捕捉。\n" NOR", "= CYN "可是$p" CYN "识破了$P"
      #                          CYN "的拳招中的变化，精心应对，并没有吃亏。\n" NOR"], "success": ["= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80,
      #                          HIR "$n" HIR "无法窥测$N" HIR "拳中奥"
      #                                              "秘，被这一拳击中要害，登时呕出一大口"
      #                                              "鲜血！\n:内伤@?")"]}, "damage_formula": %{"formula": "(int)me->query_skill("force", 1)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-80"}], "resource_queries": ["neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-80"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(3);", "me->start_busy(2);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(3);
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

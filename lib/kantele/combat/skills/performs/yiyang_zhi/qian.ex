defmodule Kantele.Combat.Skills.Performs.YiyangZhi.Qian do
  @moduledoc """
  perform「一指乾坤」（source yiyang-zhi/qian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "finger"}, {"dp", "parry"}], "level_gates": [{"force", "220"}, {"jingluo-xue", "160"}, {"yiyang-zhi", "160"}], "map_gates": [{"finger", "yiyang-zhi"}], "prepared_gates": [{"finger", "yiyang-zhi"}], "resource_gates": [{"max_neili", "2400"}, {"neili", "500"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你一阳指诀不够娴熟，难以施展", "你对经络学了解不够，难以施展", "你没有激发一阳指诀，难以施展", "你没有准备一阳指诀，难以施展", "你的内功火候不够，难以施展", "你的内力修为不足，难以施展", "你现在的真气不够，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("finger") + me->query_skill("force")", "dp_formula": "target->query_skill("parry") + target->query_skill("force")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "可是$n" CYN "看破了$N" CYN "的招"
      #                          "数，连消带打挡开了这一指。\n" NOR"], "success": ["HIY "$N" HIY "陡然使出「" HIR "一指乾坤" HIY "」绝技，单指劲"
      #                 "点$n" HIY "檀中要穴，招式变化精奇之极！\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 75,
      #                                              HIR "$n" HIR "只觉胸口一麻，已被$N" HIR
      #                                              "一指点中，顿时气血上涌，喷出数口鲜血"
      #                                              "。\n" NOR)"]}, "damage_formula": %{"formula": "ap / 2 + random(ap / 3)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-150"}, {"neili", "-200"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-150"}, {"neili", "-200"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
      #   - me->start_busy(4);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

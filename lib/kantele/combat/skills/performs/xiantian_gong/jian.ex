defmodule Kantele.Combat.Skills.Performs.XiantianGong.Jian do
  @moduledoc """
  perform「先天功」（source xiantian-gong/jian.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "force"}, {"dp", "force"}], "level_gates": [{"jingluo-xue", "200"}, {"xiantian-gong", "280"}, {"yiyang-zhi", "280"}], "map_gates": [{"finger", "yiyang-zhi"}, {"force", "xiantian-gong"}, {"unarmed", "xiantian-gong"}], "prepared_gates": [{"finger", "yiyang-zhi"}, {"unarmed", "xiantian-gong"}], "resource_gates": [{"max_neili", "5000"}, {"neili", "1000"}], "var_gates": [{"i", "5"}]}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你的先天功修为不够，难以施展", "你一阳指诀不够娴熟，难以施展", "你对经络学了解不够，难以施展", "你的内力修为不足，难以施展", "你没有激发先天功为拳脚，难以施展", "你没有激发先天功为内功，难以施展", "你没有激发一阳指为指法，难以施展", "你没有准备先天功或一阳指，难以施展", "你现在的真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("force") +
      #              me->query_skill("finger") +
      #              me->query_skill("unarmed")", "dp_formula": "target->query_skill("force") +
      #              target->query_skill("parry") +
      #              target->query_skill("dodge")"}, "color_codes": ["CYN", "HIR", "HIW", "HIY", "NOR"], "combat_messages": %{"fail": [], "other": ["= CYN "$n" CYN "见$N" CYN "这指来势汹涌，不敢"
      #                          "轻易招架，当即飞身纵跃闪开。\n" NOR"], "success": ["HIY "霎时只见$N" HIY "逆运" HIW "先天真气" HIY "，化为" HIR
      #                 "纯阳内劲" HIY "聚于指尖，以一阳指诀手法疾点$n" HIY "全身诸"
      #                 "多要穴。\n" NOR", "= COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
      #                                              HIR "$n" HIR "只觉全身一热，$P" HIR "「"
      #                                              HIW "先天功" HIR "乾阳" HIY "剑气" HIR
      #                                              "」顿时破体而入，便似身置洪炉，喷出一口"
      #                                              "鲜血。\n" NOR)", "HIR "紧接着$N" HIR "十指纷飞，接连弹出数道无形剑气，$n" HIR "四面八"
      #                 "方皆被剑气所笼罩。\n"NOR"]}, "damage_formula": %{"formula": "ap + random(ap / 2)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "resource_adds": [{"neili", "-600"}], "resource_queries": ["max_neili", "neili"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-600"}], "affect_by": [], "apply_adds": ["attack"], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(3 + random(3));"], "remote_damage": true, "set_flags": [], "temp_set": []}
      #   - if (random(3) == 1 && ! target->is_busy())
      #   - target->start_busy(1);
      #   - me->start_busy(3 + random(3));
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end

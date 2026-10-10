defmodule Kantele.Combat.Skills.Performs.BaguaZhang.Jia do
  @moduledoc """
  perform「掌中夹镖」（source bagua-zhang/jia.c，由 translate_perform.py 骨架生成，inherit F_SSERVER）

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
      #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "level_gates": [{"bagua-biao", "120"}, {"bagua-zhang", "120"}, {"force", "150"}], "map_gates": [{"strike", "bagua-zhang"}, {"throwing", "bagua-biao"}], "prepared_gates": [{"strike", "bagua-zhang"}], "resource_gates": [{"neili", "150"}], "var_gates": []}
  # TODO(migrate) 增强提取逻辑：
      #   %{"all_fail_messages": ["你所使用的外功中没有这种功能。\n", "你现在手中并没有拿着暗器。\n", "你没有激发八卦掌，难以施展", "你没有准备八卦掌，难以施展", "你没有激发八卦镖诀，难以施展", "你的八卦掌不够娴熟，难以施展", "你的八卦镖诀不够娴熟，难以施展", "你的内功火候不够，难以施展", "你现在真气不足，难以施展", "对方都已经这样了，用不着这么费力吧？\n"], "ap_dp_formulas": %{"ap_formula": "me->query_skill("strike") + me->query_skill("throwing")", "dp_formula": "target->query_skill("dodge") + target->query_skill("parry")"}, "color_codes": ["CYN", "HIR", "HIY", "NOR"], "combat_d_ahinfo": %{"clear": true, "query": true}, "combat_messages": %{"fail": [], "other": ["HIY "$N" HIY "一声暴喝，一掌重重击向$n" HIY "，$p" HIY
      #                 "正欲格挡，忽然只见眼前金光一闪，一股劲风已由$N" HIY
      #                 "掌中激射而出！\n" NOR", "COMBAT_D->query_ahinfo()))
      #                           msg += pmsg", "= "( $n" + eff_status_msg(p) + " )\n"", "= CYN "可是$p" CYN "早料得$P"
      #                          CYN "有此一着，哈哈一笑，斜跳闪开。\n" NOR"], "success": ["= HIR "$n" HIR "果真始料不及，$N" HIR "那" +
      #                          weapon->query("base_unit") + weapon->name() +
      #                          HIR "正好打在$p" HIR "要穴上，顿时血气上涌，"
      #                          "连退数步！\n" NOR"]}, "damage_formula": %{"formula": "ap / 4 + random(ap / 4)"}, "hit_formula": %{"left_side": "ap / 2 + random(ap)", "operator": ">", "right_side": "dp"}, "hit_ob_calls": [{"me", "target", "me->query("jiali") + 100"}], "receive_damage_calls": [%{"formula": "damage * 3 / 2", "kind": "damage", "part": "qi", "source": "me"}, %{"formula": "damage", "kind": "wound", "part": "qi", "source": "me"}], "reset_action": true, "resource_adds": [{"neili", "-100"}], "resource_queries": ["max_qi", "neili", "qi"], "target_logic": %{"requires_fighting": true, "requires_living": true, "uses_offensive_target": true}, "weapon_type": "throwing"}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
      #   %{"add_costs": [{"neili", "-100"}], "affect_by": [], "apply_adds": [], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "set_flags": [], "temp_set": []}
      #   - me->start_busy(2);
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
